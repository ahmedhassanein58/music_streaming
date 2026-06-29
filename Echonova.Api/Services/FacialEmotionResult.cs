using System.Text.Json.Serialization;

namespace Echonova.Api.Services;

public sealed class FacialEmotionResult
{
    [JsonPropertyName("filename")]
    public string FileName { get; set; } = string.Empty;

    [JsonPropertyName("predicted_label")]
    public string PredictedLabel { get; set; } = string.Empty;

    [JsonPropertyName("predicted_index")]
    public int PredictedIndex { get; set; }

    [JsonPropertyName("confidence")]
    public double Confidence { get; set; }

    [JsonPropertyName("probabilities")]
    public Dictionary<string, double> Probabilities { get; set; } = new();

    [JsonPropertyName("classes")]
    public IReadOnlyList<string> Classes { get; set; } = Array.Empty<string>();

    [JsonPropertyName("genres")]
    public IReadOnlyList<string>? Genres { get; set; }
}
