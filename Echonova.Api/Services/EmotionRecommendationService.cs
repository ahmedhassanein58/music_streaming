using Echonova.Api.DTOs;
using Echonova.Api.Models;
using MongoDB.Driver;

namespace Echonova.Api.Services;

public interface IEmotionRecommendationService
{
    Task<EmotionScanResponse> ScanAndRecommendAsync(
        Guid userId,
        Stream imageStream,
        string fileName,
        CancellationToken ct = default);

    Task<IReadOnlyList<SongResponse>> RecommendByEmotionAsync(
        Guid? userId,
        string emotion,
        int count = 10,
        CancellationToken ct = default);
}

public class EmotionRecommendationService : IEmotionRecommendationService
{
    private readonly IEmotionService _emotion;
    private readonly ISongService _songs;
    private readonly IRecommendationService _recommendations;
    private readonly IHistoryService _history;
    private readonly IMongoCollection<User> _users;

    public EmotionRecommendationService(
        IEmotionService emotion,
        ISongService songs,
        IRecommendationService recommendations,
        IHistoryService history,
        IMongoCollection<User> users)
    {
        _emotion = emotion;
        _songs = songs;
        _recommendations = recommendations;
        _history = history;
        _users = users;
    }

    public async Task<EmotionScanResponse> ScanAndRecommendAsync(
        Guid userId,
        Stream imageStream,
        string fileName,
        CancellationToken ct = default)
    {
        var emotionResult = await _emotion.PredictEmotionAsync(imageStream, fileName, ct);
        var moodMix = EmotionGenreMapper.GetMoodMix(emotionResult.Probabilities);
        var primary = moodMix.Count > 0 ? moodMix[0].Emotion : emotionResult.PredictedLabel;
        var genres = EmotionGenreMapper.GetBlendedGenres(emotionResult.Probabilities);

        var moodSummary = string.Join(", ", moodMix.Select(m => m.Emotion));
        await _users.UpdateOneAsync(
            u => u.Id == userId,
            Builders<User>.Update.Set(u => u.LastDetectedEmotion, moodSummary),
            cancellationToken: ct);

        var recommendations = await RecommendFromMoodMixAsync(
            userId,
            emotionResult.Probabilities,
            10,
            ct);

        return new EmotionScanResponse(
            primary,
            emotionResult.Confidence,
            moodMix.Select(m => new EmotionMoodWeight(m.Emotion, Math.Round(m.Weight, 4))).ToList(),
            genres,
            emotionResult.Probabilities,
            recommendations);
    }

    public async Task<IReadOnlyList<SongResponse>> RecommendByEmotionAsync(
        Guid? userId,
        string emotion,
        int count = 10,
        CancellationToken ct = default)
    {
        var genres = EmotionGenreMapper.GetGenresForEmotion(emotion);
        var emotionSongs = await GetSongsByGenresAsync(genres, count / 2 + 1, ct);

        var results = new List<SongResponse>(emotionSongs);
        var seen = new HashSet<string>(results.Select(s => s.TrackId));

        if (userId.HasValue)
        {
            var trackIds = await _history.GetTopPlayedTrackIdsAsync(userId.Value, 3, ct);
            if (trackIds.Count > 0)
            {
                var mlRecs = trackIds.Count == 1
                    ? await _recommendations.RecommendByTrackIdAsync(trackIds[0], count, ct)
                    : await _recommendations.RecommendFromMultipleAsync(trackIds, count, ct);

                foreach (var song in mlRecs)
                {
                    if (seen.Add(song.TrackId))
                        results.Add(song);
                }
            }
        }

        if (results.Count < count)
        {
            foreach (var song in emotionSongs)
            {
                if (seen.Add(song.TrackId))
                    results.Add(song);
                if (results.Count >= count) break;
            }
        }

        return results.Take(count).ToList();
    }

    private async Task<IReadOnlyList<SongResponse>> RecommendFromMoodMixAsync(
        Guid userId,
        IReadOnlyDictionary<string, double> probabilities,
        int count,
        CancellationToken ct)
    {
        var moodMix = EmotionGenreMapper.GetMoodMix(probabilities);
        if (moodMix.Count == 0)
            return await RecommendByEmotionAsync(userId, "neutral", count, ct);

        var perMood = Math.Max(2, count / moodMix.Count);
        var results = new List<SongResponse>();
        var seen = new HashSet<string>();

        foreach (var (emotion, _) in moodMix)
        {
            var genres = EmotionGenreMapper.GetGenresForEmotion(emotion);
            var batch = await GetSongsByGenresAsync(genres, perMood, ct);
            foreach (var song in batch)
            {
                if (seen.Add(song.TrackId))
                    results.Add(song);
            }
        }

        if (results.Count < count)
        {
            var blendedGenres = EmotionGenreMapper.GetBlendedGenres(probabilities);
            var extra = await GetSongsByGenresAsync(blendedGenres, count, ct);
            foreach (var song in extra)
            {
                if (seen.Add(song.TrackId))
                    results.Add(song);
                if (results.Count >= count) break;
            }
        }

        return results.Take(count).ToList();
    }

    private async Task<IReadOnlyList<SongResponse>> GetSongsByGenresAsync(
        IReadOnlyList<string> genres,
        int count,
        CancellationToken ct)
    {
        var collected = new List<SongResponse>();
        var seen = new HashSet<string>();

        foreach (var genre in genres)
        {
            var batch = await _songs.ListAsync(genre, null, 0, count, ct);
            foreach (var song in batch.Items)
            {
                if (seen.Add(song.TrackId))
                    collected.Add(song);
            }
            if (collected.Count >= count) break;
        }

        return collected.Take(count).ToList();
    }
}
