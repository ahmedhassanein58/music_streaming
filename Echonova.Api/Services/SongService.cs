using Echonova.Api.DTOs;
using Echonova.Api.Models;
using MongoDB.Driver;

namespace Echonova.Api.Services;

public interface ISongService
{
    Task<SongListResponse> ListAsync(string? genre, string? search, int page, int pageSize, CancellationToken ct = default);
    Task<SongResponse?> GetByTrackIdAsync(string trackId, CancellationToken ct = default);
    Task<IReadOnlyList<SongResponse>> GetByTrackIdsAsync(IEnumerable<string> trackIds, CancellationToken ct = default);
    Task<SongResponse?> GetByTitleAndArtistAsync(string title, string artist, CancellationToken ct = default);
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

    public async Task<SongResponse?> GetByTrackIdAsync(string trackId, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(trackId)) return null;
        var song = await _songs.Find(s => s.TrackId == trackId).FirstOrDefaultAsync(ct);
        return song == null ? null : ToResponse(song);
    }

    public async Task<IReadOnlyList<SongResponse>> GetByTrackIdsAsync(IEnumerable<string> trackIds, CancellationToken ct = default)
    {
        var ids = trackIds.Where(id => !string.IsNullOrWhiteSpace(id)).Distinct().ToList();
        if (ids.Count == 0) return Array.Empty<SongResponse>();
        var filter = Builders<Song>.Filter.In(s => s.TrackId, ids);
        var songs = await _songs.Find(filter).ToListAsync(ct);
        return songs.Select(ToResponse).ToList();
    }

    public async Task<SongResponse?> GetByTitleAndArtistAsync(string title, string artist, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(title)) return null;
        var titleLower = title.ToLowerInvariant();
        var filter = Builders<Song>.Filter.Where(s =>
            s.Title.ToLower() == titleLower &&
            (string.IsNullOrEmpty(artist) || s.Artist.ToLower() == artist.ToLower()));
        var song = await _songs.Find(filter).FirstOrDefaultAsync(ct);
        return song == null ? null : ToResponse(song);
    }

    private static SongResponse ToResponse(Song s)
    {
        var af = s.AudioFeature;
        var audioFeature = new AudioFeature
        {
            Acousticness = af?.Acousticness ?? 0,
            Danceability = af?.Danceability ?? 0,
            Energy = af?.Energy ?? 0,
            Instrumentalness = af?.Instrumentalness ?? 0,
            Liveness = af?.Liveness ?? 0,
            Speechiness = af?.Speechiness ?? 0,
            Tempo = af?.Tempo ?? 0,
            Valence = af?.Valence ?? 0
        };
        return new SongResponse(s.Id, s.TrackId, s.Title, s.Artist, s.Genre ?? new List<string>(), audioFeature, s.S3Url ?? string.Empty, s.CoverUrl);
    }
}
