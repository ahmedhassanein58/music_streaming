using System.Net;
using Echonova.Api.Models;

namespace Echonova.Api.Services;

public static class EmailTemplates
{
    private const string Brand = "#7C3AED";
    private const string BrandDark = "#5B21B6";
    private const string Bg = "#0F172A";
    private const string Card = "#1E293B";
    private const string Text = "#F8FAFC";
    private const string Muted = "#94A3B8";

    public static string Welcome(string username, IReadOnlyList<Song> songs, string appUrl) =>
        Layout(
            "Welcome to Echonova",
            $"Hi {username}, your account is ready. Here are songs picked for you.",
            $@"
            <h1 style=""margin:0 0 12px;font-size:28px;font-weight:700;color:{Text};"">Welcome, {Escape(username)} 🎵</h1>
            <p style=""margin:0 0 24px;color:{Muted};font-size:16px;line-height:1.6;"">
              Your email is verified and your account is ready. Explore the catalog, scan your mood,
              and get personalized recommendations.
            </p>
            <table role=""presentation"" cellpadding=""0"" cellspacing=""0"" style=""margin:0 0 28px;"">
              <tr>
                <td style=""border-radius:10px;background:linear-gradient(135deg,{Brand},{BrandDark});"">
                  <a href=""{Escape(appUrl)}"" style=""display:inline-block;padding:14px 28px;color:#fff;font-weight:600;text-decoration:none;font-size:15px;"">Open Echonova</a>
                </td>
              </tr>
            </table>
            <h2 style=""margin:0 0 16px;font-size:18px;color:{Text};"">Starter picks for you</h2>
            {SongCards(songs, appUrl)}
            <p style=""margin:24px 0 0;color:{Muted};font-size:14px;line-height:1.6;"">
              Tip: try <strong style=""color:{Text};"">Mood Scan</strong> in the app — we detect your expression and recommend genres that match how you feel.
            </p>",
            appUrl);

    public static string Recommendations(string username, IReadOnlyList<Song> songs, string? emotion, string appUrl)
    {
        var intro = !string.IsNullOrWhiteSpace(emotion)
            ? $"Based on your recent <strong style=\"color:{Text};\">{Escape(emotion)}</strong> mood, here are fresh picks:"
            : "Here are new songs we think you'll love this week:";

        return Layout(
            string.IsNullOrWhiteSpace(emotion) ? "Your Echonova picks" : $"Your {emotion} playlist",
            "New music recommendations from Echonova",
            $@"
            <h1 style=""margin:0 0 12px;font-size:24px;font-weight:700;color:{Text};"">Hey {Escape(username)} 👋</h1>
            <p style=""margin:0 0 24px;color:{Muted};font-size:16px;line-height:1.6;"">{intro}</p>
            {SongCards(songs, appUrl)}
            <p style=""margin:24px 0 0;color:{Muted};font-size:13px;line-height:1.6;"">
              Change email frequency anytime in <strong style=""color:{Text};"">Profile → Recommendation Email Frequency</strong>.
            </p>",
            appUrl);
    }

    public static string Otp(string otp) =>
        Layout(
            "Your verification code",
            "Echonova verification code",
            $@"
            <h1 style=""margin:0 0 12px;font-size:24px;color:{Text};"">Verify your email</h1>
            <p style=""margin:0 0 20px;color:{Muted};font-size:15px;line-height:1.6;"">
              Enter this code in Echonova to finish creating your account. You cannot use the app until verification is complete.
            </p>
            <div style=""display:inline-block;padding:16px 28px;background:{Card};border:2px dashed {Brand};border-radius:12px;font-size:32px;font-weight:700;letter-spacing:8px;color:{Text};"">{Escape(otp)}</div>
            <p style=""margin:20px 0 0;color:{Muted};font-size:13px;"">Expires in 10 minutes.</p>",
            "http://localhost:8080");

    private static string SongCards(IReadOnlyList<Song> songs, string appUrl)
    {
        if (songs.Count == 0)
        {
            return $@"<p style=""color:{Muted};"">Browse the app to discover thousands of tracks.</p>";
        }

        return string.Join("", songs.Take(5).Select(s =>
        {
            var genres = s.Genre.Count > 0 ? string.Join(" · ", s.Genre.Take(2)) : "Music";
            var trackUrl = $"{appUrl.TrimEnd('/')}/?trackId={Uri.EscapeDataString(s.TrackId)}";
            return $@"
            <div style=""background:{Card};border-radius:12px;padding:16px 18px;margin-bottom:12px;border-left:4px solid {Brand};"">
              <div style=""font-size:16px;font-weight:600;color:{Text};margin-bottom:4px;"">{Escape(s.Title)}</div>
              <div style=""font-size:14px;color:{Muted};margin-bottom:10px;"">{Escape(s.Artist)} · {Escape(genres)}</div>
              <a href=""{Escape(trackUrl)}"" style=""color:{Brand};font-size:13px;font-weight:600;text-decoration:none;"">▶ Play in Echonova</a>
            </div>";
        }));
    }

    private static string Layout(string title, string preheader, string body, string appUrl) => $@"
<!DOCTYPE html>
<html lang=""en"">
<head>
  <meta charset=""utf-8""/>
  <meta name=""viewport"" content=""width=device-width,initial-scale=1""/>
  <title>{Escape(title)}</title>
</head>
<body style=""margin:0;padding:0;background:{Bg};font-family:'Segoe UI',Roboto,Helvetica,Arial,sans-serif;"">
  <span style=""display:none;max-height:0;overflow:hidden;"">{Escape(preheader)}</span>
  <table role=""presentation"" width=""100%"" cellpadding=""0"" cellspacing=""0"" style=""background:{Bg};padding:32px 16px;"">
    <tr>
      <td align=""center"">
        <table role=""presentation"" width=""100%"" cellpadding=""0"" cellspacing=""0"" style=""max-width:560px;background:linear-gradient(180deg,#1a1f35 0%,{Bg} 100%);border-radius:16px;border:1px solid #334155;overflow:hidden;"">
          <tr>
            <td style=""padding:28px 32px 12px;text-align:center;background:linear-gradient(135deg,{Brand},{BrandDark});"">
              <div style=""font-size:22px;font-weight:800;color:#fff;letter-spacing:-0.5px;"">Echo Nova</div>
              <div style=""font-size:12px;color:rgba(255,255,255,0.85);margin-top:4px;"">Mood-aware music streaming</div>
            </td>
          </tr>
          <tr>
            <td style=""padding:32px;"">{body}</td>
          </tr>
          <tr>
            <td style=""padding:20px 32px 28px;border-top:1px solid #334155;text-align:center;"">
              <p style=""margin:0 0 8px;font-size:12px;color:{Muted};"">© {DateTime.UtcNow.Year} Echonova · <a href=""{Escape(appUrl)}"" style=""color:{Brand};text-decoration:none;"">Open app</a></p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>";

    private static string Escape(string? value) => WebUtility.HtmlEncode(value ?? string.Empty);
}
