using Echonova.Api.DTOs;
using Echonova.Api.Models;
using MongoDB.Driver;

namespace Echonova.Api.Services;

public interface IUserService
{
    Task<UserMeResponse?> GetMeAsync(Guid userId, CancellationToken ct = default);
    Task<UserMeResponse?> UpdateMeAsync(Guid userId, UpdateMeRequest request, CancellationToken ct = default);
    Task<UserMeResponse?> UpdateProfileImageAsync(Guid userId, string profileImageUrl, CancellationToken ct = default);
}

public class UserService : IUserService
{
    private readonly IMongoCollection<User> _users;

    public UserService(IMongoCollection<User> users)
    {
        _users = users;
    }

    public async Task<UserMeResponse?> GetMeAsync(Guid userId, CancellationToken ct = default)
    {
        var user = await _users.Find(u => u.Id == userId).FirstOrDefaultAsync(ct);
        return user == null ? null : ToResponse(user);
    }

    public async Task<UserMeResponse?> UpdateMeAsync(Guid userId, UpdateMeRequest request, CancellationToken ct = default)
    {
        var updates = new List<UpdateDefinition<User>>();
        if (request.Username != null)
            updates.Add(Builders<User>.Update.Set(u => u.Username, request.Username));
        if (request.Preference != null)
            updates.Add(Builders<User>.Update.Set(u => u.Preference, request.Preference));
        if (request.ReceiveRecommendationEmails.HasValue)
            updates.Add(Builders<User>.Update.Set(u => u.ReceiveRecommendationEmails, request.ReceiveRecommendationEmails.Value));

        if (updates.Count == 0)
            return await GetMeAsync(userId, ct);

        await _users.UpdateOneAsync(u => u.Id == userId, Builders<User>.Update.Combine(updates), cancellationToken: ct);
        return await GetMeAsync(userId, ct);
    }

    public async Task<UserMeResponse?> UpdateProfileImageAsync(Guid userId, string profileImageUrl, CancellationToken ct = default)
    {
        await _users.UpdateOneAsync(
            u => u.Id == userId,
            Builders<User>.Update.Set(u => u.ProfileImageUrl, profileImageUrl),
            cancellationToken: ct);
        return await GetMeAsync(userId, ct);
    }

    private static UserMeResponse ToResponse(User u) =>
        new(u.Id, u.Username, u.Email, u.Preference, u.ReceiveRecommendationEmails, u.ProfileImageUrl);
}
