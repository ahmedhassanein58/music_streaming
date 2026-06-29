using System.Net.Http.Headers;
using Echonova.Api.Options;
using Microsoft.Extensions.Options;

namespace Echonova.Api.Services;

public interface IEmotionService
{
    Task<FacialEmotionResult> PredictEmotionAsync(Stream imageStream, string fileName, CancellationToken ct = default);
}

public class EmotionService : IEmotionService
{
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly MlServicesOptions _options;

    public EmotionService(IHttpClientFactory httpClientFactory, IOptions<MlServicesOptions> options)
    {
        _httpClientFactory = httpClientFactory;
        _options = options.Value;
    }

    public async Task<FacialEmotionResult> PredictEmotionAsync(Stream imageStream, string fileName, CancellationToken ct = default)
    {
        var baseUrl = _options.FacialApiBaseUrl?.TrimEnd('/');
        if (string.IsNullOrWhiteSpace(baseUrl))
        {
            throw new InvalidOperationException("FacialApiBaseUrl is not configured.");
        }

        var client = _httpClientFactory.CreateClient("facial-emotion");
        client.BaseAddress ??= new Uri(baseUrl);
        client.Timeout = TimeSpan.FromSeconds(90);

        using var content = new MultipartFormDataContent();
        var streamContent = new StreamContent(imageStream);
        var contentType = GuessImageContentType(fileName);
        streamContent.Headers.ContentType = MediaTypeHeaderValue.Parse(contentType);
        content.Add(streamContent, "file", fileName);

        HttpResponseMessage response;
        try
        {
            response = await client.PostAsync("/emotion/predict", content, ct);
        }
        catch (HttpRequestException ex)
        {
            throw new InvalidOperationException(
                "Facial emotion service is unavailable. Ensure the Python service is running on port 8000 " +
                $"(cd 'Emotion Detection AI Models/Facial Recognition System' && .venv/bin/python -m uvicorn api:app --port 8000). Details: {ex.Message}",
                ex);
        }

        using (response)
        {
            if (!response.IsSuccessStatusCode)
            {
                var body = await response.Content.ReadAsStringAsync(ct);
                throw new InvalidOperationException(
                    $"Facial emotion service returned {(int)response.StatusCode}: {body}");
            }

            var dto = await response.Content.ReadFromJsonAsync<FacialEmotionResult>(cancellationToken: ct);
            if (dto == null)
            {
                throw new InvalidOperationException("Failed to deserialize emotion prediction response.");
            }

            return dto;
        }
    }

    private static string GuessImageContentType(string fileName)
    {
        var ext = Path.GetExtension(fileName).ToLowerInvariant();
        return ext switch
        {
            ".png" => "image/png",
            ".webp" => "image/webp",
            ".gif" => "image/gif",
            ".bmp" => "image/bmp",
            _ => "image/jpeg"
        };
    }
}

