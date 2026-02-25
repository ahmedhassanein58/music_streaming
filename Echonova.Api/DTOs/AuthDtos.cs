namespace Echonova.Api.DTOs;

public record SignupRequest(string Username, string Email, string Password);

public record LoginRequest(string Email, string Password);

public record AuthResponse(Guid UserId, string Email, string Username, string Token, bool IsAdmin);

public record SendOtpRequest(string Email);

public record VerifyOtpRequest(string Email, string Otp);
