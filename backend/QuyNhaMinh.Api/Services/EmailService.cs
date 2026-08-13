using System.Net;
using System.Net.Mail;

namespace QuyNhaMinh.Api.Services;

public sealed class EmailService(IConfiguration configuration) {
    public bool IsConfigured => !string.IsNullOrWhiteSpace(configuration["SMTP_HOST"]) && !string.IsNullOrWhiteSpace(configuration["SMTP_FROM"]);
    public async Task SendPasswordResetAsync(string recipient, string code) {
        var host = configuration["SMTP_HOST"] ?? throw new ExternalServiceException("Chưa cấu hình gửi email", 503, "SMTP_HOST chưa được thiết lập.");
        var from = configuration["SMTP_FROM"] ?? throw new ExternalServiceException("Chưa cấu hình gửi email", 503, "SMTP_FROM chưa được thiết lập.");
        var port = int.TryParse(configuration["SMTP_PORT"], out var value) ? value : 587;
        using var client = new SmtpClient(host, port) { EnableSsl = true };
        var username = configuration["SMTP_USERNAME"];
        var password = configuration["SMTP_PASSWORD"];
        if (!string.IsNullOrWhiteSpace(username) && !string.IsNullOrWhiteSpace(password)) client.Credentials = new NetworkCredential(username, password);
        using var message = new MailMessage(new MailAddress(from), new MailAddress(recipient)) { Subject = "Mã đặt lại mật khẩu Quỹ Nhà Mình", Body = $"<p>Mã đặt lại mật khẩu của bạn là:</p><h1 style='letter-spacing:6px'>{code}</h1><p>Mã có hiệu lực trong 15 phút. Không chia sẻ mã này cho bất kỳ ai.</p>", IsBodyHtml = true };
        await client.SendMailAsync(message);
    }
}