using Echonova.Api.DTOs;
using Echonova.Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace Echonova.Api.Controllers;

[ApiController]
[Route("anonymous")]
public class AnonymousController : ControllerBase
{
    private readonly IAnonymousSessionService _sessions;

    public AnonymousController(IAnonymousSessionService sessions)
    {
        _sessions = sessions;
    }

    [HttpPost("session")]
    public async Task<IActionResult> CreateOrGetSession([FromBody] AnonymousSessionRequest request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.BrowserFingerprint))
            return BadRequest(new { message = "BrowserFingerprint required." });
        var sessionId = await _sessions.CreateOrGetAsync(request.BrowserFingerprint, ct);
        return Ok(new AnonymousSessionResponse(sessionId));
    }
}
