using System.Security.Claims;
using Echonova.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Echonova.Api.Controllers;

[ApiController]
[Authorize]
[Route("emotion")]
public class EmotionController : ControllerBase
{
    private readonly IEmotionService _emotionService;
    private readonly IEmotionRecommendationService _emotionRecommendations;

    public EmotionController(
        IEmotionService emotionService,
        IEmotionRecommendationService emotionRecommendations)
    {
        _emotionService = emotionService;
        _emotionRecommendations = emotionRecommendations;
    }

    private Guid UserId => Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    /// <summary>
    /// Accepts a facial image and forwards it to the FastAPI emotion detection service.
    /// </summary>
    [HttpPost("facial")]
    [RequestSizeLimit(10 * 1024 * 1024)]
    public async Task<IActionResult> PredictFacialEmotion([FromForm] IFormFile file, CancellationToken ct)
    {
        if (file == null || file.Length == 0)
        {
            return BadRequest("Image file is required.");
        }

        await using var stream = file.OpenReadStream();
        var result = await _emotionService.PredictEmotionAsync(stream, file.FileName, ct);
        return Ok(result);
    }

    /// <summary>
    /// Scan face, detect emotion, map to genres, and return song recommendations.
    /// </summary>
    [HttpPost("scan")]
    [RequestSizeLimit(10 * 1024 * 1024)]
    public async Task<IActionResult> ScanAndRecommend([FromForm] IFormFile file, CancellationToken ct)
    {
        if (file == null || file.Length == 0)
        {
            return BadRequest("Image file is required.");
        }

        await using var stream = file.OpenReadStream();
        var result = await _emotionRecommendations.ScanAndRecommendAsync(UserId, stream, file.FileName, ct);
        return Ok(result);
    }
}
