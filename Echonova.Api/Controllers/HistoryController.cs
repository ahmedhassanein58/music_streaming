using System.Security.Claims;
using Echonova.Api.DTOs;
using Echonova.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Echonova.Api.Controllers;

[ApiController]
[Route("history")]
[Authorize]
public class HistoryController : ControllerBase
{
    private readonly IHistoryService _history;

    public HistoryController(IHistoryService history)
    {
        _history = history;
    }

    private Guid UserId => Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    [HttpGet]
    public async Task<IActionResult> List(CancellationToken ct)
    {
        var list = await _history.ListByUserAsync(UserId, ct);
        return Ok(list);
    }

    [HttpPost]
    [HttpPut]
    public async Task<IActionResult> RecordPlay([FromBody] RecordPlayRequest request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.TrackId) || !Guid.TryParse(request.TrackId, out var trackId))
            return BadRequest(new { message = "Invalid track_id." });
        var result = await _history.RecordPlayAsync(UserId, trackId, ct);
        return result == null ? BadRequest() : Ok(result);
    }
}
