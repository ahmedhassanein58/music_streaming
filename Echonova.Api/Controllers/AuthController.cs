using Echonova.Api.DTOs;
using Echonova.Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace Echonova.Api.Controllers;

[ApiController]
[Route("auth")]
public class AuthController : ControllerBase
{
    private readonly IAuthService _auth;

    public AuthController(IAuthService auth)
    {
        _auth = auth;
    }

    [HttpPost("signup")]
    public async Task<IActionResult> Signup([FromBody] SignupRequest request, CancellationToken ct)
    {
        var result = await _auth.SignupAsync(request, ct);
        if (result == null)
            return Conflict(new { message = "Email already registered." });
        return StatusCode(201, result);
    }

    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginRequest request, CancellationToken ct)
    {
        var result = await _auth.LoginAsync(request, ct);
        if (result == null)
            return Unauthorized(new { message = "Invalid email or password." });
        return Ok(result);
    }

    [HttpPost("send-otp")]
    public async Task<IActionResult> SendOtp([FromBody] SendOtpRequest request, CancellationToken ct)
    {
        var sent = await _auth.SendOtpAsync(request.Email, ct);
        if (!sent)
            return NotFound(new { message = "User not found." });
        return Ok(new { message = "OTP sent." });
    }

    [HttpPost("verify-otp")]
    public async Task<IActionResult> VerifyOtp([FromBody] VerifyOtpRequest request, CancellationToken ct)
    {
        var valid = await _auth.VerifyOtpAsync(request.Email, request.Otp, ct);
        if (!valid)
            return BadRequest(new { message = "Invalid or expired OTP." });
        return Ok(new { message = "OTP verified." });
    }
}
