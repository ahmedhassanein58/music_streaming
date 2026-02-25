using Echonova.Api.DTOs;
using Echonova.Api.Models;
using MongoDB.Driver;

namespace Echonova.Api.Services;

public interface IAuthService
{
    Task<AuthResponse?> SignupAsync(SignupRequest request, CancellationToken ct = default);
    Task<AuthResponse?> LoginAsync(LoginRequest request, CancellationToken ct = default);
    Task<bool> SendOtpAsync(string email, CancellationToken ct = default);
    Task<bool> VerifyOtpAsync(string email, string otp, CancellationToken ct = default);
}

public class AuthService : IAuthService
{
    private readonly IMongoCollection<User> _users;
    private readonly IMongoCollection<Admin> _admins;
    private readonly IPasswordHasher _hasher;
    private readonly IJwtService _jwt;
    private readonly IEmailService _email;

    public AuthService(
        IMongoCollection<User> users,
        IMongoCollection<Admin> admins,
        IPasswordHasher hasher,
        IJwtService jwt,
        IEmailService email)
    {
        _users = users;
        _admins = admins;
        _hasher = hasher;
        _jwt = jwt;
        _email = email;
    }

    public async Task<AuthResponse?> SignupAsync(SignupRequest request, CancellationToken ct = default)
    {
        var existing = await _users.Find(u => u.Email == request.Email).FirstOrDefaultAsync(ct);
        if (existing != null) return null;

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

        _ = Task.Run(() => _email.SendWelcomeAsync(user.Email, user.Username, ct), ct);

        var isAdmin = await _admins.Find(a => a.Email == user.Email).AnyAsync(ct);
        var token = _jwt.GenerateToken(user.Id, user.Email, isAdmin);
        return new AuthResponse(user.Id, user.Email, user.Username, token, isAdmin);
    }

    public async Task<AuthResponse?> LoginAsync(LoginRequest request, CancellationToken ct = default)
    {
        var admin = await _admins.Find(a => a.Email == request.Email).FirstOrDefaultAsync(ct);
        if (admin != null)
        {
            if (!_hasher.Verify(request.Password, admin.PasswordHash)) return null;
            var token = _jwt.GenerateToken(admin.Id, admin.Email, true);
            return new AuthResponse(admin.Id, admin.Email, admin.Email, token, true);
        }

        var user = await _users.Find(u => u.Email == request.Email).FirstOrDefaultAsync(ct);
        if (user == null || !_hasher.Verify(request.Password, user.PasswordHash)) return null;

        var userToken = _jwt.GenerateToken(user.Id, user.Email, false);
        return new AuthResponse(user.Id, user.Email, user.Username, userToken, false);
    }

    public async Task<bool> SendOtpAsync(string email, CancellationToken ct = default)
    {
        var user = await _users.Find(u => u.Email == email).FirstOrDefaultAsync(ct);
        if (user == null) return false;

        var otp = Random.Shared.Next(100000, 999999).ToString();
        var expire = DateTime.UtcNow.AddMinutes(10);
        await _users.UpdateOneAsync(
            u => u.Id == user.Id,
            Builders<User>.Update.Set(u => u.EmailOtp, otp).Set(u => u.OtpExpire, expire),
            cancellationToken: ct);

        await _email.SendOtpAsync(email, otp, ct);
        return true;
    }

    public async Task<bool> VerifyOtpAsync(string email, string otp, CancellationToken ct = default)
    {
        var user = await _users.Find(u => u.Email == email).FirstOrDefaultAsync(ct);
        if (user == null || user.EmailOtp != otp) return false;
        if (user.OtpExpire == null || user.OtpExpire.Value <= DateTime.UtcNow) return false;

        await _users.UpdateOneAsync(
            u => u.Id == user.Id,
            Builders<User>.Update.Set(u => u.EmailOtp, (string?)null).Set(u => u.OtpExpire, (DateTime?)null),
            cancellationToken: ct);
        return true;
    }
}
