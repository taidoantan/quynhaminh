using System.Net.Http.Json;
using System.Text.Json;
using QuyNhaMinh.Api.Contracts;

namespace QuyNhaMinh.Api.Services;

public sealed class SupabaseStorage(IHttpClientFactory clients, IConfiguration configuration, IWebHostEnvironment environment) {
    public async Task<string> UploadReceipt(Guid fundId, string dataUrl, CancellationToken cancellationToken) {
        var (mime, bytes, extension) = Decode(dataUrl);
        var objectPath = $"{fundId:N}/{DateTime.UtcNow:yyyy/MM}/{Guid.NewGuid():N}.{extension}";
        var url = Environment.GetEnvironmentVariable("SUPABASE_URL") ?? configuration["Supabase:Url"];
        var key = Environment.GetEnvironmentVariable("SUPABASE_SERVICE_ROLE_KEY");
        if (!string.IsNullOrWhiteSpace(url) && !string.IsNullOrWhiteSpace(key)) {
            var request = new HttpRequestMessage(HttpMethod.Post, $"{url.TrimEnd('/')}/storage/v1/object/receipts/{objectPath}") { Content = new ByteArrayContent(bytes) };
            request.Headers.Add("apikey", key); request.Headers.Authorization = new("Bearer", key); request.Content.Headers.ContentType = new(mime);
            var response = await clients.CreateClient().SendAsync(request, cancellationToken);
            if (!response.IsSuccessStatusCode) throw new ExternalServiceException("Không thể lưu ảnh lên Supabase Storage", (int)response.StatusCode, await response.Content.ReadAsStringAsync(cancellationToken));
            return $"{url.TrimEnd('/')}/storage/v1/object/public/receipts/{objectPath}";
        }
        var root = Path.Combine(environment.ContentRootPath, "uploads", "receipts"); Directory.CreateDirectory(root);
        var localName = $"{Guid.NewGuid():N}.{extension}"; await File.WriteAllBytesAsync(Path.Combine(root, localName), bytes, cancellationToken); return $"/uploads/receipts/{localName}";
    }

    public static (string Mime, byte[] Bytes, string Extension) Decode(string dataUrl) {
        var comma = dataUrl.IndexOf(','); if (comma < 0 || !dataUrl.StartsWith("data:")) throw new ArgumentException("Ảnh không đúng định dạng data URL");
        var mime = dataUrl[5..comma].Split(';')[0]; var extension = mime switch { "image/png" => "png", "image/webp" => "webp", _ => "jpg" };
        var bytes = Convert.FromBase64String(dataUrl[(comma + 1)..]); if (bytes.Length is < 100 or > 8_000_000) throw new ArgumentException("Ảnh phải có dung lượng từ 100 byte đến 8 MB");
        return (mime, bytes, extension);
    }
}

public sealed class GeminiReceiptService(IHttpClientFactory clients, IConfiguration configuration) {
    public async Task<ReceiptSuggestion> Analyze(string dataUrl, string? imageUrl, CancellationToken cancellationToken) {
        var key = Environment.GetEnvironmentVariable("GEMINI_API_KEY") ?? throw new ExternalServiceException("Backend chưa có GEMINI_API_KEY", 503, "missing_key");
        var (mime, bytes, _) = SupabaseStorage.Decode(dataUrl);
        var prompt = "Đọc hóa đơn/chứng từ Việt Nam. Chỉ trả JSON đúng schema. type là income hoặc expense. amount là tổng tiền cuối cùng dạng số. date là yyyy-MM-dd hoặc null. category ngắn gọn. confidence từ 0 đến 1. warnings là mảng cảnh báo khi ảnh mờ, số tiền/ngày không chắc chắn hoặc có thể trùng.";
        var schema = new { type = "OBJECT", properties = new { type = new { type = "STRING", @enum = new[] { "income", "expense" } }, amount = new { type = "NUMBER" }, date = new { type = "STRING", nullable = true }, merchant = new { type = "STRING", nullable = true }, category = new { type = "STRING" }, note = new { type = "STRING" }, confidence = new { type = "NUMBER" }, warnings = new { type = "ARRAY", items = new { type = "STRING" } } }, required = new[] { "type", "amount", "category", "note", "confidence", "warnings" } };
        var body = new { contents = new[] { new { role = "user", parts = new object[] { new { text = prompt }, new { inline_data = new { mime_type = mime, data = Convert.ToBase64String(bytes) } } } } }, generationConfig = new { responseMimeType = "application/json", responseSchema = schema, temperature = 0.1 } };
        var model = configuration["Gemini:Model"] ?? "gemini-3.5-flash";
        var request = new HttpRequestMessage(HttpMethod.Post, $"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent") { Content = JsonContent.Create(body) }; request.Headers.Add("x-goog-api-key", key);
        HttpResponseMessage response;
        try { response = await clients.CreateClient().SendAsync(request, cancellationToken); }
        catch (TaskCanceledException) { throw new ExternalServiceException("Gemini phản hồi quá thời gian", 504, "timeout"); }
        var raw = await response.Content.ReadAsStringAsync(cancellationToken);
        if (!response.IsSuccessStatusCode) { var status = (int)response.StatusCode; var message = status == 429 ? "Gemini đã hết hạn mức hoặc đang giới hạn tốc độ" : "Gemini không xử lý được hóa đơn"; throw new ExternalServiceException(message, status, raw); }
        try {
            using var doc = JsonDocument.Parse(raw); var text = doc.RootElement.GetProperty("candidates")[0].GetProperty("content").GetProperty("parts")[0].GetProperty("text").GetString()!;
            var result = JsonSerializer.Deserialize<GeminiResult>(text, new JsonSerializerOptions { PropertyNameCaseInsensitive = true }) ?? throw new JsonException();
            var warnings = result.Warnings?.ToList() ?? []; if (result.Confidence < .7m) warnings.Add("Kết quả có độ tin cậy thấp, hãy kiểm tra kỹ trước khi lưu."); if (result.Amount <= 0) warnings.Add("Không xác định được tổng tiền.");
            return new ReceiptSuggestion(result.Type, result.Amount, result.Date, result.Merchant, result.Category, result.Note, Math.Clamp(result.Confidence, 0, 1), warnings, imageUrl);
        } catch (Exception e) when (e is JsonException or KeyNotFoundException or InvalidOperationException) { throw new ExternalServiceException("Gemini trả về dữ liệu không hợp lệ", 502, raw); }
    }

    private sealed record GeminiResult(string Type, decimal Amount, string? Date, string? Merchant, string Category, string Note, decimal Confidence, string[]? Warnings);
}

public sealed class ExternalServiceException(string message, int statusCode, string detail) : Exception(message) { public int StatusCode { get; } = statusCode; public string Detail { get; } = detail; }
