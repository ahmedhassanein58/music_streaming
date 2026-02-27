using Echonova.Api.DTOs;
using Echonova.Api.Models;
using MongoDB.Driver;

namespace Echonova.Api.Services;

public interface IHistoryService
{
    Task<List<HistoryResponse>> ListByUserAsync(Guid userId, CancellationToken ct = default);
    Task<List<string>> GetTopPlayedTrackIdsAsync(Guid userId, int limit, CancellationToken ct = default);
    Task<HistoryResponse?> RecordPlayAsync(Guid userId, string trackId, CancellationToken ct = default);
}

public class HistoryService : IHistoryService
{
    private readonly IMongoCollection<History> _history;
    private readonly ISongService _songs;

    public HistoryService(IMongoCollection<History> history, ISongService songs)
    {
        _history = history;
        _songs = songs;
    }

    public async Task<List<string>> GetTopPlayedTrackIdsAsync(Guid userId, int limit, CancellationToken ct = default)
    {
        var list = await _history.Find(h => h.UserId == userId)
            .SortByDescending(h => h.PlayCount)
            .ThenByDescending(h => h.LastPlayed)
            .Limit(limit)
            .ToListAsync(ct);
        return list.Select(h => h.TrackId).Where(id => !string.IsNullOrWhiteSpace(id)).ToList();
    }

    public async Task<List<HistoryResponse>> ListByUserAsync(Guid userId, CancellationToken ct = default)
    {
        var list = await _history.Find(h => h.UserId == userId)
            .SortByDescending(h => h.LastPlayed)
            .ToListAsync(ct);
        var result = new List<HistoryResponse>();
        foreach (var h in list)
        {
            var title = h.Title;
            var artist = h.Artist;
            if (string.IsNullOrEmpty(title) || string.IsNullOrEmpty(artist))
            {
                var song = await _songs.GetByTrackIdAsync(h.TrackId, ct);
                title ??= song?.Title;
                artist ??= song?.Artist;
            }
            result.Add(new HistoryResponse(h.Id, h.UserId, h.TrackId, h.PlayCount, h.LastPlayed, title, artist));
        }
        return result;
    }

    public async Task<HistoryResponse?> RecordPlayAsync(Guid userId, string trackId, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(trackId)) return null;
        var song = await _songs.GetByTrackIdAsync(trackId, ct);
        var title = song?.Title;
        var artist = song?.Artist;

        var existing = await _history.Find(h => h.UserId == userId && h.TrackId == trackId).FirstOrDefaultAsync(ct);
        var now = DateTime.UtcNow;
        if (existing != null)
        {
            var update = Builders<History>.Update
                .Inc(h => h.PlayCount, 1)
                .Set(h => h.LastPlayed, now);
            if (title != null) update = update.Set(h => h.Title, title);
            if (artist != null) update = update.Set(h => h.Artist, artist);
            await _history.UpdateOneAsync(h => h.Id == existing.Id, update, cancellationToken: ct);
            return new HistoryResponse(existing.Id, existing.UserId, existing.TrackId, existing.PlayCount + 1, now, title ?? existing.Title, artist ?? existing.Artist);
        }
        var entry = new History
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            TrackId = trackId,
            PlayCount = 1,
            LastPlayed = now,
            Title = title,
            Artist = artist
        };
        await _history.InsertOneAsync(entry, cancellationToken: ct);
        return ToResponse(entry);
    }

    private static HistoryResponse ToResponse(History h) =>
        new(h.Id, h.UserId, h.TrackId, h.PlayCount, h.LastPlayed, h.Title, h.Artist);
}
