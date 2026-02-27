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

    public EmotionController(IEmotionService emotionService)
    {
        _emotionService = emotionService;
    }

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
}

