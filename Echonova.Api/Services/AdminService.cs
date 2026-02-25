using Echonova.Api.DTOs;
using Echonova.Api.Models;
using MongoDB.Driver;

namespace Echonova.Api.Services;

public interface IAdminService
{
    Task<SongListResponse> ListSongsAsync(int page, int pageSize, CancellationToken ct = default);
    Task<SongResponse?> GetSongByTrackIdAsync(Guid trackId, CancellationToken ct = default);
    Task<SongResponse?> CreateSongAsync(AdminCreateSongRequest request, string s3Url, Guid? trackId = null, CancellationToken ct = default);
    Task<SongResponse?> UpdateSongAsync(Guid trackId, AdminUpdateSongRequest request, CancellationToken ct = default);
    Task<bool> DeleteSongAsync(Guid trackId, CancellationToken ct = default);
    Task<UserMeResponse?> CreateUserAsync(AdminCreateUserRequest request, CancellationToken ct = default);
    Task<List<UserMeResponse>> ListUsersAsync(int page, int pageSize, CancellationToken ct = default);
    Task<int> SendRecommendationEmailsNowAsync(CancellationToken ct = default);
}

public class AdminService : IAdminService
{
    private readonly IMongoCollection<Song> _songs;
    private readonly IMongoCollection<User> _users;
    private readonly IMongoCollection<History> _history;
    private readonly IEmailService _email;
    private readonly IPasswordHasher _hasher;

    public AdminService(
        IMongoCollection<Song> songs,
        IMongoCollection<User> users,
        IMongoCollection<History> history,
        IEmailService email,
        IPasswordHasher hasher)
    {
        _songs = songs;
        _users = users;
        _history = history;
        _email = email;
        _hasher = hasher;
    }

    public async Task<SongListResponse> ListSongsAsync(int page, int pageSize, CancellationToken ct = default)
    {
        var total = await _songs.CountDocumentsAsync(FilterDefinition<Song>.Empty, cancellationToken: ct);
        var items = await _songs.Find(FilterDefinition<Song>.Empty)
            .Skip(page * pageSize)
            .Limit(pageSize)
            .ToListAsync(ct);
        return new SongListResponse(items.Select(ToSongResponse).ToList(), (int)total);
    }

    public async Task<SongResponse?> GetSongByTrackIdAsync(Guid trackId, CancellationToken ct = default)
    {
        var song = await _songs.Find(s => s.TrackId == trackId).FirstOrDefaultAsync(ct);
        return song == null ? null : ToSongResponse(song);
    }

    public async Task<SongResponse?> CreateSongAsync(AdminCreateSongRequest request, string s3Url, Guid? trackId = null, CancellationToken ct = default)
    {
        var song = new Song
        {
            Id = Guid.NewGuid(),
            TrackId = trackId ?? Guid.NewGuid(),
            Title = request.Title,
            Artist = request.Artist,
            Genre = request.Genre,
            AudioFeature = request.AudioFeature,
            S3Url = s3Url
        };
        await _songs.InsertOneAsync(song, cancellationToken: ct);
        return ToSongResponse(song);
    }

    public async Task<SongResponse?> UpdateSongAsync(Guid trackId, AdminUpdateSongRequest request, CancellationToken ct = default)
    {
        var updates = new List<UpdateDefinition<Song>>();
        if (request.Title != null) updates.Add(Builders<Song>.Update.Set(s => s.Title, request.Title));
        if (request.Artist != null) updates.Add(Builders<Song>.Update.Set(s => s.Artist, request.Artist));
        if (request.Genre != null) updates.Add(Builders<Song>.Update.Set(s => s.Genre, request.Genre));
        if (request.AudioFeature != null) updates.Add(Builders<Song>.Update.Set(s => s.AudioFeature, request.AudioFeature));
        if (request.S3Url != null) updates.Add(Builders<Song>.Update.Set(s => s.S3Url, request.S3Url));
        if (updates.Count == 0) return await GetSongByTrackIdAsync(trackId, ct);

        await _songs.UpdateOneAsync(s => s.TrackId == trackId, Builders<Song>.Update.Combine(updates), cancellationToken: ct);
        return await GetSongByTrackIdAsync(trackId, ct);
    }

    public async Task<bool> DeleteSongAsync(Guid trackId, CancellationToken ct = default)
    {
        var result = await _songs.DeleteOneAsync(s => s.TrackId == trackId, ct);
        return result.DeletedCount > 0;
    }

    public async Task<UserMeResponse?> CreateUserAsync(AdminCreateUserRequest request, CancellationToken ct = default)
    {
        var existing = await _users.Find(u => u.Email == request.Email).AnyAsync(ct);
        if (existing) return null;
        var user = new User
        {
            Id = Guid.NewGuid(),
            Username = request.Username,
            Email = request.Email,
            PasswordHash = _hasher.Hash(request.Password),
            Preference = new List<string>(),
            ReceiveRecommendationEmails = false
        };
        await _users.InsertOneAsync(user, cancellationToken: ct);
        return new UserMeResponse(user.Id, user.Username, user.Email, user.Preference, user.ReceiveRecommendationEmails);
    }

    public async Task<List<UserMeResponse>> ListUsersAsync(int page, int pageSize, CancellationToken ct = default)
    {
        var list = await _users.Find(FilterDefinition<User>.Empty)
            .Skip(page * pageSize)
            .Limit(pageSize)
            .ToListAsync(ct);
        return list.Select(u => new UserMeResponse(u.Id, u.Username, u.Email, u.Preference, u.ReceiveRecommendationEmails)).ToList();
    }

    public async Task<int> SendRecommendationEmailsNowAsync(CancellationToken ct = default)
    {
        var users = await _users.Find(u => u.ReceiveRecommendationEmails).ToListAsync(ct);
        var allSongs = await _songs.Find(FilterDefinition<Song>.Empty).ToListAsync(ct);
        var sent = 0;
        foreach (var user in users)
        {
            var recommended = GetRecommendedSongsForUser(user, allSongs);
            if (recommended.Count > 0)
            {
                await _email.SendRecommendationsAsync(user.Email, user.Username, recommended, ct);
                sent++;
            }
        }
        return sent;
    }

    private List<Song> GetRecommendedSongsForUser(User user, List<Song> allSongs)
    {
        if (allSongs.Count == 0) return new List<Song>();
        var byGenre = allSongs.Where(s => s.Genre.Any(g => user.Preference.Contains(g, StringComparer.OrdinalIgnoreCase))).ToList();
        var pool = byGenre.Count >= 2 ? byGenre : allSongs;
        var count = Math.Min(3, pool.Count);
        return pool.OrderBy(_ => Random.Shared.Next()).Take(count).ToList();
    }

    private static SongResponse ToSongResponse(Song s) =>
        new(s.Id, s.TrackId, s.Title, s.Artist, s.Genre, s.AudioFeature, s.S3Url);
}
