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

    [HttpGet("{trackId:guid}")]
    public async Task<IActionResult> GetByTrackId(Guid trackId, CancellationToken ct)
    {
        var song = await _songs.GetByTrackIdAsync(trackId, ct);
        if (song == null) return NotFound();
        return Ok(song);
    }
}
