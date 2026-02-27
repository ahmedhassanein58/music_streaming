using System.Net.Http.Headers;
using Echonova.Api.Options;
using Microsoft.Extensions.Options;

namespace Echonova.Api.Services;

public interface IEmotionService
{
    Task<FacialEmotionResult> PredictEmotionAsync(Stream imageStream, string fileName, CancellationToken ct = default);
}

public sealed class FacialEmotionResult
{
    public string FileName { get; set; } = string.Empty;
    public string PredictedLabel { get; set; } = string.Empty;
    public int PredictedIndex { get; set; }
    public IReadOnlyList<double> Probabilities { get; set; } = Array.Empty<double>();
    public IReadOnlyList<string> Classes { get; set; } = Array.Empty<string>();
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

        using var content = new MultipartFormDataContent();
        var streamContent = new StreamContent(imageStream);
        streamContent.Headers.ContentType = MediaTypeHeaderValue.Parse("image/jpeg");
        content.Add(streamContent, "file", fileName);

        using var response = await client.PostAsync("/emotion/predict", content, ct);
        response.EnsureSuccessStatusCode();

        var dto = await response.Content.ReadFromJsonAsync<FacialEmotionResult>(cancellationToken: ct);
        if (dto == null)
        {
            throw new InvalidOperationException("Failed to deserialize emotion prediction response.");
        }

        return dto;
    }
}

