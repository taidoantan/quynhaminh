using System.Text.Json;
using ClosedXML.Excel;
using Microsoft.EntityFrameworkCore;
using PdfSharp.Drawing;
using PdfSharp.Pdf;
using QuyNhaMinh.Api.Contracts;
using QuyNhaMinh.Api.Data;
using QuyNhaMinh.Api.Domain;
using QuyNhaMinh.Api.Services;

namespace QuyNhaMinh.Api.Endpoints;

public static class DataEndpoints {
    public static IEndpointRouteBuilder MapDataFeatures(this IEndpointRouteBuilder app) {
        var api = app.MapGroup("/api/funds/{fundId:guid}").RequireAuthorization().RequireRateLimiting("api");
        api.MapPost("/receipts/analyze", AnalyzeReceipt).WithTags("Gemini OCR").DisableAntiforgery();
        api.MapGet("/backup", Backup).WithTags("Backup and trash");
        api.MapGet("/export/excel", Excel).WithTags("Dashboard and reports");
        api.MapGet("/export/pdf", Pdf).WithTags("Dashboard and reports");
        return app;
    }

    static async Task<IResult> AnalyzeReceipt(Guid fundId, ReceiptAnalyzeRequest x, FundAccess access, CurrentUser user, SupabaseStorage storage, GeminiReceiptService gemini, AppDb db, CancellationToken ct) {
        await access.Require(fundId, Roles.Owner, Roles.Admin, Roles.Member);
        if (x.FundId != Guid.Empty && x.FundId != fundId) return Results.BadRequest(new { message = "Quỹ không khớp." });
        string? imageUrl = null; try { imageUrl = await storage.UploadReceipt(fundId, x.DataUrl, ct); } catch (ExternalServiceException) { throw; } catch { }
        var suggestion = await gemini.Analyze(x.DataUrl, imageUrl, ct);
        db.Receipts.Add(new Receipt { FundId = fundId, UploadedBy = user.Id, ImageUrl = imageUrl ?? "", RawResult = JsonSerializer.Serialize(suggestion), Confidence = suggestion.Confidence }); await db.SaveChangesAsync(ct);
        return Results.Ok(suggestion);
    }

    static async Task<IResult> Backup(Guid fundId, FundAccess access, AppDb db) {
        await access.Require(fundId, Roles.Owner, Roles.Admin);
        var payload = new { version = 1, exportedAt = DateTimeOffset.UtcNow, fund = await db.Funds.IgnoreQueryFilters().Where(f => f.Id == fundId).Select(f => new { f.Id, f.Name, f.InviteCode, f.CreatedAt }).SingleAsync(), members = await db.FundMembers.Where(x => x.FundId == fundId).Select(x => new { x.UserId, x.Role, x.JoinedAt, x.User.DisplayName, x.User.Email }).ToListAsync(), categories = await db.Categories.IgnoreQueryFilters().Where(x => x.FundId == fundId).ToListAsync(), accounts = await db.MoneyAccounts.IgnoreQueryFilters().Where(x => x.FundId == fundId).ToListAsync(), transactions = await db.Transactions.IgnoreQueryFilters().Where(x => x.FundId == fundId).ToListAsync(), budgets = await db.Budgets.Where(x => x.FundId == fundId).ToListAsync(), reminders = await db.Reminders.IgnoreQueryFilters().Where(x => x.FundId == fundId).ToListAsync() };
        return Results.File(JsonSerializer.SerializeToUtf8Bytes(payload, new JsonSerializerOptions { WriteIndented = true }), "application/json", $"quy-nha-minh-backup-{DateTime.UtcNow:yyyyMMdd-HHmm}.json");
    }

    static async Task<IResult> Excel(Guid fundId, DateTime from, DateTime to, Guid? memberId, Guid? categoryId, FundAccess access, AppDb db) {
        await access.Require(fundId); var rows = await ReportRows(fundId, from, to, memberId, categoryId, db);
        using var book = new XLWorkbook(); var sheet = book.Worksheets.Add("Giao dịch");
        var headers = new[] { "Ngày", "Loại", "Danh mục", "Tài khoản", "Số tiền", "Thành viên", "Nơi giao dịch", "Ghi chú" }; for (var i = 0; i < headers.Length; i++) sheet.Cell(1, i + 1).Value = headers[i];
        var row = 2; foreach (var x in rows) { sheet.Cell(row, 1).Value = x.Date; sheet.Cell(row, 2).Value = x.Type == TransactionTypes.Income ? "Thu" : "Chi"; sheet.Cell(row, 3).Value = x.Category; sheet.Cell(row, 4).Value = x.Account; sheet.Cell(row, 5).Value = x.Amount; sheet.Cell(row, 6).Value = x.Member; sheet.Cell(row, 7).Value = x.Merchant; sheet.Cell(row, 8).Value = x.Note; row++; }
        sheet.Row(1).Style.Font.Bold = true; sheet.Column(5).Style.NumberFormat.Format = "#,##0 [$₫-vi-VN]"; sheet.Columns().AdjustToContents(); using var stream = new MemoryStream(); book.SaveAs(stream); return Results.File(stream.ToArray(), "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", $"bao-cao-{from:yyyyMMdd}-{to:yyyyMMdd}.xlsx");
    }

    static async Task<IResult> Pdf(Guid fundId, DateTime from, DateTime to, Guid? memberId, Guid? categoryId, FundAccess access, AppDb db) {
        await access.Require(fundId); var rows = await ReportRows(fundId, from, to, memberId, categoryId, db); var income = rows.Where(x => x.Type == TransactionTypes.Income).Sum(x => x.Amount); var expense = rows.Where(x => x.Type == TransactionTypes.Expense).Sum(x => x.Amount);
        using var document = new PdfDocument(); var page = document.AddPage(); page.Size = PdfSharp.PageSize.A4; using var gfx = XGraphics.FromPdfPage(page); var title = new XFont("Noto Sans", 18, XFontStyleEx.Bold); var body = new XFont("Noto Sans", 10); gfx.DrawString("QUỸ NHÀ MÌNH - BÁO CÁO THU CHI", title, XBrushes.DarkBlue, 35, 55); gfx.DrawString($"Từ {from:dd/MM/yyyy} đến {to:dd/MM/yyyy}", body, XBrushes.Black, 35, 85); gfx.DrawString($"Tổng thu: {income:N0} đ    Tổng chi: {expense:N0} đ    Số dư: {income - expense:N0} đ", body, XBrushes.Black, 35, 105);
        var y = 135d; foreach (var x in rows.Take(35)) { gfx.DrawString($"{x.Date:dd/MM}  {(x.Type == TransactionTypes.Income ? "THU" : "CHI"),-4}  {x.Category,-18}  {x.Amount,14:N0}  {x.Member}", body, XBrushes.Black, 35, y); y += 15; }
        using var stream = new MemoryStream(); document.Save(stream, false); return Results.File(stream.ToArray(), "application/pdf", $"bao-cao-{from:yyyyMMdd}-{to:yyyyMMdd}.pdf");
    }

    static Task<List<ReportRow>> ReportRows(Guid fundId, DateTime from, DateTime to, Guid? memberId, Guid? categoryId, AppDb db) {
        var transactions = db.Transactions.Where(t => t.FundId == fundId && t.TransactionDate >= from && t.TransactionDate < to);
        if (memberId.HasValue) transactions = transactions.Where(t => t.CreatedBy == memberId.Value);
        if (categoryId.HasValue) transactions = transactions.Where(t => t.CategoryId == categoryId.Value);
        return transactions.OrderByDescending(t => t.TransactionDate)
            .Join(db.Categories, t => t.CategoryId, c => c.Id, (t, c) => new { t, c })
            .Join(db.MoneyAccounts, x => x.t.AccountId, a => a.Id, (x, a) => new { x.t, Category = x.c.Name, Account = a.Name })
            .Join(db.Users, x => x.t.CreatedBy, u => u.Id, (x, u) => new ReportRow(x.t.TransactionDate, x.t.Type, x.Category, x.Account, x.t.Amount, u.DisplayName, x.t.Merchant, x.t.Note))
            .ToListAsync();
    }
    sealed record ReportRow(DateTime Date, string Type, string Category, string Account, decimal Amount, string Member, string Merchant, string Note);
}
