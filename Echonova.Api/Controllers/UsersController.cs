using System.Security.Claims;
using Echonova.Api.DTOs;
using Echonova.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Echonova.Api.Controllers;

[ApiController]
[Route("users")]
[Authorize]
public class UsersController : ControllerBase
{
    private readonly IUserService _users;
    private readonly IProfileImageStorageService _profileStorage;

    public UsersController(IUserService users, IProfileImageStorageService profileStorage)
    {
        _users = users;
        _profileStorage = profileStorage;
    }

    private Guid UserId => Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    [HttpGet("me")]
    public async Task<IActionResult> GetMe(CancellationToken ct)
    {
        var me = await _users.GetMeAsync(UserId, ct);
        if (me == null) return NotFound();
        return Ok(me);
    }

    [HttpPatch("me")]
    public async Task<IActionResult> UpdateMe([FromBody] UpdateMeRequest request, CancellationToken ct)
    {
        var me = await _users.UpdateMeAsync(UserId, request, ct);
        if (me == null) return NotFound();
        return Ok(me);
    }

    [HttpPost("me/image")]
    [RequestSizeLimit(5 * 1024 * 1024)]
    public async Task<IActionResult> UploadProfileImage(IFormFile file, CancellationToken ct)
    {
        if (file == null || file.Length == 0)
            return BadRequest(new { message = "Image file required." });

        var contentType = file.ContentType ?? "image/jpeg";
        if (contentType != "image/jpeg" && contentType != "image/png" && contentType != "image/webp")
            return BadRequest(new { message = "Invalid type. Use JPEG, PNG, or WebP." });

        if (file.Length > 5 * 1024 * 1024)
            return BadRequest(new { message = "Image too large. Max 5 MB." });

        await using var stream = file.OpenReadStream();
        var path = await _profileStorage.SaveAsync(UserId, stream, contentType, ct);

        var baseUrl = $"{Request.Scheme}://{Request.Host}";
        var fullUrl = path.StartsWith("/") ? baseUrl + path : baseUrl + "/" + path;

        var me = await _users.UpdateProfileImageAsync(UserId, fullUrl, ct);
        if (me == null) return NotFound();
        return Ok(me);
    }
}
