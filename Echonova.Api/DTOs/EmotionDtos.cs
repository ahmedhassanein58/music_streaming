namespace Echonova.Api.DTOs;

public record EmotionMoodWeight(string Emotion, double Weight);

public record EmotionScanResponse(
    string Emotion,
    double Confidence,
    IReadOnlyList<EmotionMoodWeight> MoodMix,
    IReadOnlyList<string> MappedGenres,
    IReadOnlyDictionary<string, double> Probabilities,
    IReadOnlyList<SongResponse> Recommendations);
