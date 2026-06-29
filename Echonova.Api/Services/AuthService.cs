using Echonova.Api.DTOs;
using Echonova.Api.Models;
using MongoDB.Driver;

namespace Echonova.Api.Services;

public interface IAuthService
{
    Task<SignupResponse?> SignupAsync(SignupRequest request, CancellationToken ct = default);
    Task<LoginResult> LoginAsync(LoginRequest request, CancellationToken ct = default);
    Task<bool> SendOtpAsync(string email, CancellationToken ct = default);
    Task<AuthResponse?> VerifyOtpAsync(string email, string otp, CancellationToken ct = default);
}

public class AuthService : IAuthService
{
    private readonly IMongoCollection<User> _users;
    private readonly IMongoCollection<Admin> _admins;
    private readonly IMongoCollection<Song> _songs;
    private readonly IPasswordHasher _hasher;
    private readonly IJwtService _jwt;
    private readonly IEmailService _email;

    public AuthService(
        IMongoCollection<User> users,
        IMongoCollection<Admin> admins,
        IMongoCollection<Song> songs,
        IPasswordHasher hasher,
        IJwtService jwt,
        IEmailService email)
    {
        _users = users;
        _admins = admins;
        _songs = songs;
        _hasher = hasher;
        _jwt = jwt;
        _email = email;
    }

    public async Task<SignupResponse?> SignupAsync(SignupRequest request, CancellationToken ct = default)
    {
        var existing = await _users.Find(u => u.Email == request.Email).FirstOrDefaultAsync(ct);
        if (existing != null) return null;

        var otp = GenerateOtp();
        var expire = DateTime.UtcNow.AddMinutes(10);

        var user = new User
        {
            Id = Guid.NewGuid(),
            Username = request.Username,
            Email = request.Email,
            PasswordHash = _hasher.Hash(request.Password),
            Preference = new List<string>(),
            EmailVerified = false,
            EmailOtp = otp,
            OtpExpire = expire,
            ReceiveRecommendationEmails = false
        };
        await _users.InsertOneAsync(user, cancellationToken: ct);

        await _email.SendOtpAsync(user.Email, otp, ct);

        return new SignupResponse(user.Id, user.Email, user.Username, true);
    }

    public async Task<LoginResult> LoginAsync(LoginRequest request, CancellationToken ct = default)
    {
        var admin = await _admins.Find(a => a.Email == request.Email).FirstOrDefaultAsync(ct);
        if (admin != null)
        {
            if (!_hasher.Verify(request.Password, admin.PasswordHash))
                return new LoginResult(null, false);
            var token = _jwt.GenerateToken(admin.Id, admin.Email, true);
            return new LoginResult(new AuthResponse(admin.Id, admin.Email, admin.Email, token, true), false);
        }

        var user = await _users.Find(u => u.Email == request.Email).FirstOrDefaultAsync(ct);
        if (user == null || !_hasher.Verify(request.Password, user.PasswordHash))
            return new LoginResult(null, false);

        if (!user.EmailVerified)
            return new LoginResult(null, true);

        var userToken = _jwt.GenerateToken(user.Id, user.Email, false);
        return new LoginResult(new AuthResponse(user.Id, user.Email, user.Username, userToken, false), false);
    }

    public async Task<bool> SendOtpAsync(string email, CancellationToken ct = default)
    {
        var user = await _users.Find(u => u.Email == email).FirstOrDefaultAsync(ct);
        if (user == null) return false;

        var otp = GenerateOtp();
        var expire = DateTime.UtcNow.AddMinutes(10);
        await _users.UpdateOneAsync(
            u => u.Id == user.Id,
            Builders<User>.Update.Set(u => u.EmailOtp, otp).Set(u => u.OtpExpire, expire),
            cancellationToken: ct);

        await _email.SendOtpAsync(email, otp, ct);
        return true;
    }

    public async Task<AuthResponse?> VerifyOtpAsync(string email, string otp, CancellationToken ct = default)
    {
        var user = await _users.Find(u => u.Email == email).FirstOrDefaultAsync(ct);
        if (user == null || user.EmailOtp != otp) return null;
        if (user.OtpExpire == null || user.OtpExpire.Value <= DateTime.UtcNow) return null;

        await _users.UpdateOneAsync(
            u => u.Id == user.Id,
            Builders<User>.Update
                .Set(u => u.EmailVerified, true)
                .Set(u => u.EmailOtp, (string?)null)
                .Set(u => u.OtpExpire, (DateTime?)null),
            cancellationToken: ct);

        var welcomeSongs = await GetWelcomeSongSampleAsync(ct);
        _ = Task.Run(async () =>
        {
            try
            {
                await _email.SendWelcomeAsync(user.Email, user.Username, welcomeSongs, ct);
            }
            catch
            {
                // SMTP may be unconfigured during dev
            }
        }, ct);

        var isAdmin = await _admins.Find(a => a.Email == user.Email).AnyAsync(ct);
        var token = _jwt.GenerateToken(user.Id, user.Email, isAdmin);
        return new AuthResponse(user.Id, user.Email, user.Username, token, isAdmin);
    }

    private static string GenerateOtp() => Random.Shared.Next(100000, 999999).ToString();

    private async Task<IReadOnlyList<Song>> GetWelcomeSongSampleAsync(CancellationToken ct)
    {
        var total = await _songs.CountDocumentsAsync(FilterDefinition<Song>.Empty, cancellationToken: ct);
        if (total == 0) return Array.Empty<Song>();

        if (total <= 5)
            return await _songs.Find(FilterDefinition<Song>.Empty).Limit(5).ToListAsync(ct);

        return await _songs.Aggregate()
            .Sample(5)
            .ToListAsync(ct);
    }
}
