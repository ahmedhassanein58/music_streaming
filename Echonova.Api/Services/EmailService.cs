using Echonova.Api.Models;
using Echonova.Api.Options;
using MailKit.Net.Smtp;
using MailKit.Security;
using Microsoft.Extensions.Options;
using MimeKit;

namespace Echonova.Api.Services;

public interface IEmailService
{
    Task SendOtpAsync(string email, string otp, CancellationToken ct = default);
    Task SendWelcomeAsync(string email, string username, IReadOnlyList<Song> songs, CancellationToken ct = default);
    Task SendRecommendationsAsync(
        string email,
        string username,
        IReadOnlyList<Song> songs,
        string? lastEmotion = null,
        CancellationToken ct = default);
}

public class EmailService : IEmailService
{
    private readonly SmtpOptions _smtp;
    private readonly AppOptions _app;

    public EmailService(IOptions<SmtpOptions> smtp, IOptions<AppOptions> app)
    {
        _smtp = smtp.Value;
        _app = app.Value;
    }

    private async Task SendAsync(string to, string subject, string body, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(_smtp.Host) || _smtp.Host == "smtp.example.com")
        {
            throw new InvalidOperationException(
                "SMTP is not configured. Set Smtp:Host, Username, and Password in appsettings or user secrets.");
        }

        var message = new MimeMessage();
        message.From.Add(new MailboxAddress(_smtp.FromName, _smtp.FromAddress));
        message.To.Add(MailboxAddress.Parse(to));
        message.Subject = subject;
        message.Body = new TextPart("html") { Text = body };

        using var client = new SmtpClient();
        var secure = _smtp.UseSsl ? SecureSocketOptions.SslOnConnect : SecureSocketOptions.StartTlsWhenAvailable;
        await client.ConnectAsync(_smtp.Host, _smtp.Port, secure, ct);
        if (!string.IsNullOrEmpty(_smtp.Username))
            await client.AuthenticateAsync(_smtp.Username, _smtp.Password, ct);
        await client.SendAsync(message, ct);
        await client.DisconnectAsync(true, ct);
    }

    public Task SendOtpAsync(string email, string otp, CancellationToken ct = default) =>
        SendAsync(email, "Your Echonova verification code", EmailTemplates.Otp(otp), ct);

    public Task SendWelcomeAsync(string email, string username, IReadOnlyList<Song> songs, CancellationToken ct = default) =>
        SendAsync(
            email,
            "Welcome to Echonova — your music journey starts here",
            EmailTemplates.Welcome(username, songs, _app.PublicBaseUrl),
            ct);

    public Task SendRecommendationsAsync(
        string email,
        string username,
        IReadOnlyList<Song> songs,
        string? lastEmotion = null,
        CancellationToken ct = default)
    {
        var subject = !string.IsNullOrWhiteSpace(lastEmotion)
            ? $"Your {lastEmotion} mood playlist from Echonova"
            : "Fresh picks from Echonova";

        return SendAsync(
            email,
            subject,
            EmailTemplates.Recommendations(username, songs, lastEmotion, _app.PublicBaseUrl),
            ct);
    }
}
