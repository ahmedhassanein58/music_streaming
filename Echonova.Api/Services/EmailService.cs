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
    Task SendWelcomeAsync(string email, string username, CancellationToken ct = default);
    Task SendRecommendationsAsync(string email, string username, IReadOnlyList<Song> songs, CancellationToken ct = default);
}

public class EmailService : IEmailService
{
    private readonly SmtpOptions _options;

    public EmailService(IOptions<SmtpOptions> options)
    {
        _options = options.Value;
    }

    private async Task SendAsync(string to, string subject, string body, CancellationToken ct)
    {
        var message = new MimeMessage();
        message.From.Add(new MailboxAddress(_options.FromName, _options.FromAddress));
        message.To.Add(MailboxAddress.Parse(to));
        message.Subject = subject;
        message.Body = new TextPart("html") { Text = body };

        using var client = new SmtpClient();
        var secure = _options.UseSsl ? SecureSocketOptions.SslOnConnect : SecureSocketOptions.StartTlsWhenAvailable;
        await client.ConnectAsync(_options.Host, _options.Port, secure, ct);
        if (!string.IsNullOrEmpty(_options.Username))
            await client.AuthenticateAsync(_options.Username, _options.Password, ct);
        await client.SendAsync(message, ct);
        await client.DisconnectAsync(true, ct);
    }

    public Task SendOtpAsync(string email, string otp, CancellationToken ct = default)
    {
        var body = $@"
<html><body>
<p>Your Echonova verification code is: <strong>{otp}</strong></p>
<p>It expires in 10 minutes.</p>
</body></html>";
        return SendAsync(email, "Your verification code", body, ct);
    }

    public Task SendWelcomeAsync(string email, string username, CancellationToken ct = default)
    {
        var body = $@"
<html><body>
<p>Hi {username},</p>
<p>Welcome to Echonova! Your account has been created.</p>
</body></html>";
        return SendAsync(email, "Welcome to Echonova", body, ct);
    }

    public Task SendRecommendationsAsync(string email, string username, IReadOnlyList<Song> songs, CancellationToken ct = default)
    {
        var list = string.Join("", songs.Take(3).Select(s => $"<li><strong>{s.Title}</strong> by {s.Artist} - <a href=\"{s.S3Url}\">Listen</a></li>"));
        var body = $@"
<html><body>
<p>Hi {username},</p>
<p>Here are some songs we think you'll like:</p>
<ul>{list}</ul>
</body></html>";
        return SendAsync(email, "Your music recommendations", body, ct);
    }
}
