using Echonova.Api.Models;
using MongoDB.Driver;

namespace Echonova.Api.Services;

public class RecommendationEmailBackgroundService : BackgroundService
{
    private static readonly TimeSpan CheckInterval = TimeSpan.FromHours(1);
    private static readonly TimeSpan StartupDelay = TimeSpan.FromMinutes(2);

    private readonly IServiceProvider _services;
    private readonly ILogger<RecommendationEmailBackgroundService> _logger;

    public RecommendationEmailBackgroundService(
        IServiceProvider services,
        ILogger<RecommendationEmailBackgroundService> logger)
    {
        _services = services;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        // Let the API and MongoDB connection pool settle before the first check.
        try
        {
            await Task.Delay(StartupDelay, stoppingToken);
        }
        catch (OperationCanceledException)
        {
            return;
        }

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await ProcessDueEmailsAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (TimeoutException ex)
            {
                _logger.LogWarning(
                    "MongoDB unreachable, skipping recommendation email check: {Message}",
                    ex.Message);
            }
            catch (MongoConnectionException ex)
            {
                _logger.LogWarning(
                    "MongoDB connection failed, skipping recommendation email check: {Message}",
                    ex.Message);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Recommendation email check failed");
            }

            try
            {
                await Task.Delay(CheckInterval, stoppingToken);
            }
            catch (OperationCanceledException)
            {
                break;
            }
        }
    }

    private async Task ProcessDueEmailsAsync(CancellationToken ct)
    {
        using var scope = _services.CreateScope();
        var users = scope.ServiceProvider.GetRequiredService<IMongoCollection<User>>();
        var email = scope.ServiceProvider.GetRequiredService<IEmailService>();
        var recs = scope.ServiceProvider.GetRequiredService<IUserRecommendationService>();

        using var timeoutCts = CancellationTokenSource.CreateLinkedTokenSource(ct);
        timeoutCts.CancelAfter(TimeSpan.FromSeconds(15));

        var candidates = await users
            .Find(u => u.ReceiveRecommendationEmails && u.EmailFrequency != EmailFrequency.Off)
            .ToListAsync(timeoutCts.Token);

        var now = DateTime.UtcNow;
        var sent = 0;

        foreach (var user in candidates)
        {
            if (!IsDue(user, now)) continue;

            try
            {
                var songs = await recs.GetRecommendedSongsForUserAsync(user, 3, ct);
                if (songs.Count == 0) continue;

                await email.SendRecommendationsAsync(
                    user.Email,
                    user.Username,
                    songs,
                    user.LastDetectedEmotion,
                    ct);

                await users.UpdateOneAsync(
                    u => u.Id == user.Id,
                    Builders<User>.Update.Set(u => u.LastRecommendationEmailSentAt, now),
                    cancellationToken: ct);

                sent++;
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Failed to send recommendation email to {Email}", user.Email);
            }
        }

        if (sent > 0)
            _logger.LogInformation("Sent {Count} recommendation emails", sent);
    }

    internal static bool IsDue(User user, DateTime now)
    {
        if (user.EmailFrequency == EmailFrequency.Off || !user.ReceiveRecommendationEmails)
            return false;

        if (user.LastRecommendationEmailSentAt == null)
            return true;

        var elapsed = now - user.LastRecommendationEmailSentAt.Value;
        return user.EmailFrequency switch
        {
            EmailFrequency.Daily => elapsed >= TimeSpan.FromDays(1),
            EmailFrequency.Weekly => elapsed >= TimeSpan.FromDays(7),
            EmailFrequency.Monthly => elapsed >= TimeSpan.FromDays(30),
            _ => false
        };
    }
}
