using Echonova.Api.DTOs;
using Echonova.Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace Echonova.Api.Controllers;

[ApiController]
[Route("songs")]
public class SongsController : ControllerBase
{
    private readonly ISongService _songs;

    public SongsController(ISongService songs)
    {
        _songs = songs;
    }

    [HttpGet]
    public async Task<IActionResult> List(
        [FromQuery] string? genre,
        [FromQuery] string? search,
        [FromQuery] int page = 0,
        [FromQuery] int pageSize = 20,
        CancellationToken ct = default)
    {
        pageSize = Math.Clamp(pageSize, 1, 100);
        var result = await _songs.ListAsync(genre, search, page, pageSize, ct);
        return Ok(result);
    }

    [HttpGet("{trackId}")]
    public async Task<IActionResult> GetByTrackId(string trackId, CancellationToken ct)
    {
        var song = await _songs.GetByTrackIdAsync(trackId, ct);
        if (song == null) return NotFound();
        return Ok(song);
    }

    /// <summary>
    /// Accepts a list of track IDs (e.g. "829", "7762") and returns matching songs.
    /// </summary>
    [HttpPost("by-ids")]
    public async Task<IActionResult> GetByTrackIds([FromBody] List<string>? trackIds, CancellationToken ct = default)
    {
        if (trackIds == null || trackIds.Count == 0) return Ok(new List<object>());
        var list = await _songs.GetByTrackIdsAsync(trackIds, ct);
        return Ok(list);
    }
}
