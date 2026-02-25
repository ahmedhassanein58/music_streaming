using System.Security.Claims;
using Echonova.Api.DTOs;
using Echonova.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Echonova.Api.Controllers;

[ApiController]
[Route("playlists")]
[Authorize]
public class PlaylistsController : ControllerBase
{
    private readonly IPlaylistService _playlists;

    public PlaylistsController(IPlaylistService playlists)
    {
        _playlists = playlists;
    }

    private Guid UserId => Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    [HttpGet]
    public async Task<IActionResult> List(CancellationToken ct)
    {
        var list = await _playlists.ListByUserAsync(UserId, ct);
        return Ok(list);
    }

    [HttpGet("{playlistId:guid}")]
    public async Task<IActionResult> Get(Guid playlistId, CancellationToken ct)
    {
        var p = await _playlists.GetAsync(playlistId, UserId, ct);
        if (p == null) return NotFound();
        return Ok(p);
    }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreatePlaylistRequest request, CancellationToken ct)
    {
        var p = await _playlists.CreateAsync(UserId, request, ct);
        return p == null ? BadRequest() : StatusCode(201, p);
    }

    [HttpPatch("{playlistId:guid}")]
    public async Task<IActionResult> Update(Guid playlistId, [FromBody] UpdatePlaylistRequest request, CancellationToken ct)
    {
        var p = await _playlists.UpdateAsync(playlistId, UserId, request, ct);
        if (p == null) return NotFound();
        return Ok(p);
    }

    [HttpDelete("{playlistId:guid}")]
    public async Task<IActionResult> Delete(Guid playlistId, CancellationToken ct)
    {
        var ok = await _playlists.DeleteAsync(playlistId, UserId, ct);
        if (!ok) return NotFound();
        return NoContent();
    }

    [HttpPost("{playlistId:guid}/tracks")]
    public async Task<IActionResult> AddTracks(Guid playlistId, [FromBody] AddTracksRequest request, CancellationToken ct)
    {
        var p = await _playlists.AddTracksAsync(playlistId, UserId, request.TrackIds, ct);
        if (p == null) return NotFound();
        return Ok(p);
    }

    [HttpDelete("{playlistId:guid}/tracks/{trackId}")]
    public async Task<IActionResult> RemoveTrack(Guid playlistId, string trackId, CancellationToken ct)
    {
        var p = await _playlists.RemoveTrackAsync(playlistId, UserId, trackId, ct);
        if (p == null) return NotFound();
        return Ok(p);
    }
}
