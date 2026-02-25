using Echonova.Api.DTOs;
using Echonova.Api.Models;
using MongoDB.Driver;

namespace Echonova.Api.Services;

public interface ISongService
{
    Task<SongListResponse> ListAsync(string? genre, string? search, int page, int pageSize, CancellationToken ct = default);
    Task<SongResponse?> GetByTrackIdAsync(Guid trackId, CancellationToken ct = default);
}

public class SongService : ISongService
{
    private readonly IMongoCollection<Song> _songs;

    public SongService(IMongoCollection<Song> songs)
    {
        _songs = songs;
    }

    public async Task<SongListResponse> ListAsync(string? genre, string? search, int page, int pageSize, CancellationToken ct = default)
    {
        var filter = Builders<Song>.Filter.Empty;
        if (!string.IsNullOrWhiteSpace(genre))
            filter &= Builders<Song>.Filter.AnyIn(s => s.Genre, new[] { genre });
        if (!string.IsNullOrWhiteSpace(search))
        {
            var searchLower = search.ToLowerInvariant();
            filter &= Builders<Song>.Filter.Or(
                Builders<Song>.Filter.Regex(s => s.Title, new MongoDB.Bson.BsonRegularExpression(searchLower, "i")),
                Builders<Song>.Filter.Regex(s => s.Artist, new MongoDB.Bson.BsonRegularExpression(searchLower, "i")));
        }

        var total = await _songs.CountDocumentsAsync(filter, cancellationToken: ct);
        var items = await _songs.Find(filter)
            .Skip(page * pageSize)
            .Limit(pageSize)
            .ToListAsync(ct);
        return new SongListResponse(items.Select(ToResponse).ToList(), (int)total);
    }

    public async Task<SongResponse?> GetByTrackIdAsync(Guid trackId, CancellationToken ct = default)
    {
        var song = await _songs.Find(s => s.TrackId == trackId).FirstOrDefaultAsync(ct);
        return song == null ? null : ToResponse(song);
    }

    private static SongResponse ToResponse(Song s) =>
        new(s.Id, s.TrackId, s.Title, s.Artist, s.Genre, s.AudioFeature, s.S3Url);
}
