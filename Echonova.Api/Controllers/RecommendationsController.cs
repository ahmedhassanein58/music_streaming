using System.Security.Claims;
using Echonova.Api.DTOs;
using Echonova.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Echonova.Api.Controllers;

[ApiController]
[Authorize]
[Route("recommendations")]
public class RecommendationsController : ControllerBase
{
    private readonly IRecommendationService _recommendations;
    private readonly IHistoryService _history;

    public RecommendationsController(IRecommendationService recommendations, IHistoryService history)
    {
        _recommendations = recommendations;
        _history = history;
    }

    private Guid UserId => Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    /// <summary>
    /// Personalized suggestions based on the user's most played songs.
    /// Uses top play history as seeds for the ML recommendation API.
    /// </summary>
    [HttpGet("suggested")]
    public async Task<IActionResult> GetSuggested(CancellationToken ct)
    {
        var trackIds = await _history.GetTopPlayedTrackIdsAsync(UserId, 3, ct);
        if (trackIds.Count == 0)
            return Ok(new RecommendationListResponse(Array.Empty<SongResponse>()));

        var items = trackIds.Count == 1
            ? await _recommendations.RecommendByTrackIdAsync(trackIds[0], 10, ct)
            : await _recommendations.RecommendFromMultipleAsync(trackIds, 10, ct);

        return Ok(new RecommendationListResponse(items));
    }

    [HttpPost("by-track-id")]
    public async Task<IActionResult> RecommendByTrackId([FromBody] RecommendByTrackIdRequest request, CancellationToken ct)
    {
        if (request.N <= 0 || request.N > 100)
            return BadRequest("N must be between 1 and 100.");

        var items = await _recommendations.RecommendByTrackIdAsync(request.TrackId, request.N, ct);
        return Ok(new RecommendationListResponse(items));
    }

    [HttpPost("from-multiple")]
    public async Task<IActionResult> RecommendFromMultiple([FromBody] RecommendFromMultipleRequest request, CancellationToken ct)
    {
        if (request.TrackIds == null || request.TrackIds.Count == 0)
            return BadRequest("TrackIds list cannot be empty.");
        if (request.N <= 0 || request.N > 100)
            return BadRequest("N must be between 1 and 100.");

        var items = await _recommendations.RecommendFromMultipleAsync(request.TrackIds, request.N, ct);
        return Ok(new RecommendationListResponse(items));
    }
}
