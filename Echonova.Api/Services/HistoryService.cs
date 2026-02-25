using Echonova.Api.DTOs;
using Echonova.Api.Models;
using MongoDB.Driver;

namespace Echonova.Api.Services;

public interface IHistoryService
{
    Task<List<HistoryResponse>> ListByUserAsync(Guid userId, CancellationToken ct = default);
    Task<HistoryResponse?> RecordPlayAsync(Guid userId, Guid trackId, CancellationToken ct = default);
}

public class HistoryService : IHistoryService
{
    private readonly IMongoCollection<History> _history;

    public HistoryService(IMongoCollection<History> history)
    {
        _history = history;
    }

    public async Task<List<HistoryResponse>> ListByUserAsync(Guid userId, CancellationToken ct = default)
    {
        var list = await _history.Find(h => h.UserId == userId)
            .SortByDescending(h => h.LastPlayed)
            .ToListAsync(ct);
        return list.Select(ToResponse).ToList();
    }

    public async Task<HistoryResponse?> RecordPlayAsync(Guid userId, Guid trackId, CancellationToken ct = default)
    {
        var existing = await _history.Find(h => h.UserId == userId && h.TrackId == trackId).FirstOrDefaultAsync(ct);
        var now = DateTime.UtcNow;
        if (existing != null)
        {
            await _history.UpdateOneAsync(
                h => h.Id == existing.Id,
                Builders<History>.Update
                    .Inc(h => h.PlayCount, 1)
                    .Set(h => h.LastPlayed, now),
                cancellationToken: ct);
            return new HistoryResponse(existing.Id, existing.UserId, existing.TrackId, existing.PlayCount + 1, now);
        }
        var entry = new History
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            TrackId = trackId,
            PlayCount = 1,
            LastPlayed = now
        };
        await _history.InsertOneAsync(entry, cancellationToken: ct);
        return ToResponse(entry);
    }

    private static HistoryResponse ToResponse(History h) =>
        new(h.Id, h.UserId, h.TrackId, h.PlayCount, h.LastPlayed);
}
