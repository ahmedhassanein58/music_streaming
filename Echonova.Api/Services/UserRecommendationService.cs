using Echonova.Api.Models;
using MongoDB.Driver;

namespace Echonova.Api.Services;

public interface IUserRecommendationService
{
    Task<IReadOnlyList<Song>> GetRecommendedSongsForUserAsync(User user, int count = 3, CancellationToken ct = default);
}

public class UserRecommendationService : IUserRecommendationService
{
    private readonly IMongoCollection<Song> _songs;
    private readonly IRecommendationService _recommendations;
    private readonly IHistoryService _history;
    private readonly IEmotionRecommendationService _emotionRecommendations;

    public UserRecommendationService(
        IMongoCollection<Song> songs,
        IRecommendationService recommendations,
        IHistoryService history,
        IEmotionRecommendationService emotionRecommendations)
    {
        _songs = songs;
        _recommendations = recommendations;
        _history = history;
        _emotionRecommendations = emotionRecommendations;
    }

    public async Task<IReadOnlyList<Song>> GetRecommendedSongsForUserAsync(User user, int count = 3, CancellationToken ct = default)
    {
        var results = new List<Song>();
        var seen = new HashSet<string>();

        // Primary: ML recommendations from play history
        var trackIds = await _history.GetTopPlayedTrackIdsAsync(user.Id, 3, ct);
        if (trackIds.Count > 0)
        {
            var mlRecs = trackIds.Count == 1
                ? await _recommendations.RecommendByTrackIdAsync(trackIds[0], count, ct)
                : await _recommendations.RecommendFromMultipleAsync(trackIds, count, ct);

            foreach (var song in mlRecs)
            {
                var entity = await _songs.Find(s => s.TrackId == song.TrackId).FirstOrDefaultAsync(ct);
                if (entity != null && seen.Add(entity.TrackId))
                    results.Add(entity);
            }
        }

        // Fallback: emotion-mapped genres
        if (results.Count < count && !string.IsNullOrWhiteSpace(user.LastDetectedEmotion))
        {
            var emotionRecs = await _emotionRecommendations.RecommendByEmotionAsync(
                user.Id, user.LastDetectedEmotion, count, ct);
            foreach (var song in emotionRecs)
            {
                var entity = await _songs.Find(s => s.TrackId == song.TrackId).FirstOrDefaultAsync(ct);
                if (entity != null && seen.Add(entity.TrackId))
                    results.Add(entity);
            }
        }

        // Fallback: user preference genres
        if (results.Count < count && user.Preference.Count > 0)
        {
            var allSongs = await _songs.Find(FilterDefinition<Song>.Empty).ToListAsync(ct);
            var byGenre = allSongs
                .Where(s => s.Genre.Any(g => user.Preference.Contains(g, StringComparer.OrdinalIgnoreCase)))
                .Where(s => seen.Add(s.TrackId))
                .Take(count - results.Count);
            results.AddRange(byGenre);
        }

        // Last resort: random from catalog
        if (results.Count < count)
        {
            var allSongs = await _songs.Find(FilterDefinition<Song>.Empty).Limit(50).ToListAsync(ct);
            foreach (var song in allSongs.OrderBy(_ => Random.Shared.Next()))
            {
                if (seen.Add(song.TrackId))
                    results.Add(song);
                if (results.Count >= count) break;
            }
        }

        return results.Take(count).ToList();
    }
}
