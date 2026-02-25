using Echonova.Api.DTOs;
using Echonova.Api.Models;
using MongoDB.Driver;

namespace Echonova.Api.Services;

public interface IPlaylistService
{
    Task<List<PlaylistResponse>> ListByUserAsync(Guid userId, CancellationToken ct = default);
    Task<PlaylistResponse?> GetAsync(Guid playlistId, Guid userId, CancellationToken ct = default);
    Task<PlaylistResponse?> CreateAsync(Guid userId, CreatePlaylistRequest request, CancellationToken ct = default);
    Task<PlaylistResponse?> UpdateAsync(Guid playlistId, Guid userId, UpdatePlaylistRequest request, CancellationToken ct = default);
    Task<bool> DeleteAsync(Guid playlistId, Guid userId, CancellationToken ct = default);
    Task<PlaylistResponse?> AddTracksAsync(Guid playlistId, Guid userId, List<string> trackIds, CancellationToken ct = default);
    Task<PlaylistResponse?> RemoveTrackAsync(Guid playlistId, Guid userId, string trackId, CancellationToken ct = default);
}

public class PlaylistService : IPlaylistService
{
    private readonly IMongoCollection<Playlist> _playlists;

    public PlaylistService(IMongoCollection<Playlist> playlists)
    {
        _playlists = playlists;
    }

    public async Task<List<PlaylistResponse>> ListByUserAsync(Guid userId, CancellationToken ct = default)
    {
        var list = await _playlists.Find(p => p.UserId == userId).ToListAsync(ct);
        return list.Select(ToResponse).ToList();
    }

    public async Task<PlaylistResponse?> GetAsync(Guid playlistId, Guid userId, CancellationToken ct = default)
    {
        var p = await _playlists.Find(x => x.Id == playlistId && x.UserId == userId).FirstOrDefaultAsync(ct);
        return p == null ? null : ToResponse(p);
    }

    public async Task<PlaylistResponse?> CreateAsync(Guid userId, CreatePlaylistRequest request, CancellationToken ct = default)
    {
        var playlist = new Playlist
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Name = request.Name,
            TracksId = request.TracksId ?? new List<string>()
        };
        await _playlists.InsertOneAsync(playlist, cancellationToken: ct);
        return ToResponse(playlist);
    }

    public async Task<PlaylistResponse?> UpdateAsync(Guid playlistId, Guid userId, UpdatePlaylistRequest request, CancellationToken ct = default)
    {
        var updates = new List<UpdateDefinition<Playlist>>();
        if (request.Name != null) updates.Add(Builders<Playlist>.Update.Set(p => p.Name, request.Name));
        if (request.TracksId != null) updates.Add(Builders<Playlist>.Update.Set(p => p.TracksId, request.TracksId));
        if (updates.Count == 0) return await GetAsync(playlistId, userId, ct);

        await _playlists.UpdateOneAsync(
            p => p.Id == playlistId && p.UserId == userId,
            Builders<Playlist>.Update.Combine(updates),
            cancellationToken: ct);
        return await GetAsync(playlistId, userId, ct);
    }

    public async Task<bool> DeleteAsync(Guid playlistId, Guid userId, CancellationToken ct = default)
    {
        var result = await _playlists.DeleteOneAsync(p => p.Id == playlistId && p.UserId == userId, ct);
        return result.DeletedCount > 0;
    }

    public async Task<PlaylistResponse?> AddTracksAsync(Guid playlistId, Guid userId, List<string> trackIds, CancellationToken ct = default)
    {
        if (trackIds.Count == 0) return await GetAsync(playlistId, userId, ct);
        await _playlists.UpdateOneAsync(
            p => p.Id == playlistId && p.UserId == userId,
            Builders<Playlist>.Update.AddToSetEach(p => p.TracksId, trackIds),
            cancellationToken: ct);
        return await GetAsync(playlistId, userId, ct);
    }

    public async Task<PlaylistResponse?> RemoveTrackAsync(Guid playlistId, Guid userId, string trackId, CancellationToken ct = default)
    {
        await _playlists.UpdateOneAsync(
            p => p.Id == playlistId && p.UserId == userId,
            Builders<Playlist>.Update.Pull(p => p.TracksId, trackId),
            cancellationToken: ct);
        return await GetAsync(playlistId, userId, ct);
    }

    private static PlaylistResponse ToResponse(Playlist p) =>
        new(p.Id, p.UserId, p.Name, p.TracksId);
}
