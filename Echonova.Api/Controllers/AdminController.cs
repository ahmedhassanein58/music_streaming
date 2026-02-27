using Echonova.Api.DTOs;
using Echonova.Api.Models;
using Echonova.Api.Options;
using Echonova.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.Extensions.Options;
using Microsoft.AspNetCore.Mvc;

namespace Echonova.Api.Controllers;

[ApiController]
[Route("admin")]
[Authorize(Policy = "AdminOnly")]
public class AdminController : ControllerBase
{
    private readonly IAdminService _admin;
    private readonly IStorageService _storage;
    private readonly UploadOptions _upload;

    public AdminController(IAdminService admin, IStorageService storage, IOptions<UploadOptions> upload)
    {
        _admin = admin;
        _storage = storage;
        _upload = upload.Value;
    }

    [HttpGet("songs")]
    public async Task<IActionResult> ListSongs(
        [FromQuery] int page = 0,
        [FromQuery] int pageSize = 20,
        CancellationToken ct = default)
    {
        pageSize = Math.Clamp(pageSize, 1, 100);
        var result = await _admin.ListSongsAsync(page, pageSize, ct);
        return Ok(result);
    }

    [HttpPost("songs/upload")]
    [RequestSizeLimit(21_000_000)]
    public async Task<IActionResult> UploadSong(CancellationToken ct)
    {
        if (!Request.HasFormContentType)
            return BadRequest(new { message = "Expect multipart/form-data." });
        var form = await Request.ReadFormAsync(ct);
        var file = form.Files.GetFile("file");
        if (file == null || file.Length == 0)
            return BadRequest(new { message = "File required." });
        if (file.Length > _upload.MaxFileSizeBytes)
            return BadRequest(new { message = "File too large." });
        var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (!_upload.AllowedExtensions.Contains(ext))
            return BadRequest(new { message = "Invalid file type." });

        var title = form["title"].ToString() ?? "Unknown";
        var artist = form["artist"].ToString() ?? "Unknown";
        var genreStr = form["genre"].ToString();
        var genre = string.IsNullOrWhiteSpace(genreStr) ? new List<string>() : genreStr.Split(',', StringSplitOptions.RemoveEmptyEntries).Select(s => s.Trim()).ToList();
        var audioFeature = new AudioFeature();
        var afStr = form["audioFeature"].ToString();
        if (!string.IsNullOrWhiteSpace(afStr))
        {
            try
            {
                var opts = new System.Text.Json.JsonSerializerOptions { PropertyNameCaseInsensitive = true };
                var af = System.Text.Json.JsonSerializer.Deserialize<AudioFeature>(afStr, opts);
                if (af != null) audioFeature = af;
            }
            catch { /* use defaults */ }
        }

        var trackId = Guid.NewGuid().ToString();
        var key = $"tracks/{trackId}{ext}";
        string s3Url;
        await using (var stream = file.OpenReadStream())
        {
            s3Url = await _storage.UploadAsync(stream, key, file.ContentType, ct);
        }

        var createRequest = new AdminCreateSongRequest(title, artist, genre, audioFeature, s3Url);
        var song = await _admin.CreateSongAsync(createRequest, s3Url, trackId, ct);
        return song == null ? StatusCode(500) : StatusCode(201, song);
    }

    [HttpPost("songs")]
    public async Task<IActionResult> CreateSong([FromBody] AdminCreateSongRequest request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.S3Url))
            return BadRequest(new { message = "S3Url required for this endpoint." });
        var song = await _admin.CreateSongAsync(request, request.S3Url!, null, ct);
        return StatusCode(201, song);
    }

    [HttpPut("songs/{trackId}")]
    public async Task<IActionResult> UpdateSong(string trackId, [FromBody] AdminUpdateSongRequest request, CancellationToken ct)
    {
        var song = await _admin.UpdateSongAsync(trackId, request, ct);
        if (song == null) return NotFound();
        return Ok(song);
    }

    [HttpDelete("songs/{trackId}")]
    public async Task<IActionResult> DeleteSong(string trackId, CancellationToken ct)
    {
        var ok = await _admin.DeleteSongAsync(trackId, ct);
        if (!ok) return NotFound();
        return NoContent();
    }

    [HttpPost("users")]
    public async Task<IActionResult> CreateUser([FromBody] AdminCreateUserRequest request, CancellationToken ct)
    {
        var user = await _admin.CreateUserAsync(request, ct);
        if (user == null) return Conflict(new { message = "Email already registered." });
        return StatusCode(201, user);
    }

    [HttpGet("users")]
    public async Task<IActionResult> ListUsers(
        [FromQuery] int page = 0,
        [FromQuery] int pageSize = 20,
        CancellationToken ct = default)
    {
        pageSize = Math.Clamp(pageSize, 1, 100);
        var list = await _admin.ListUsersAsync(page, pageSize, ct);
        return Ok(list);
    }

    [HttpPost("recommendations/send-now")]
    public async Task<IActionResult> SendRecommendationsNow(CancellationToken ct)
    {
        var sent = await _admin.SendRecommendationEmailsNowAsync(ct);
        return Ok(new { message = $"Sent {sent} recommendation emails." });
    }
}
