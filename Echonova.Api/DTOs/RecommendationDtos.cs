using System.Text.Json.Serialization;

namespace Echonova.Api.DTOs;

public record RecommendByTrackIdRequest(string TrackId, int N = 10);

public record RecommendFromMultipleRequest(IReadOnlyList<string> TrackIds, int N = 20);

public record RecommendationListResponse(IReadOnlyList<SongResponse> Items);

/// <summary>
/// Shape of a single recommendation item returned by the Python FastAPI service.
/// We only rely on title/artist/genre to map back to our Song collection.
/// </summary>
public sealed class MusicRecItemDto
{
    [JsonPropertyName("$oid")]
    public string? Oid { get; set; }

    [JsonPropertyName("track_id")]
    public string? TrackId { get; set; }

    [JsonPropertyName("title")]
    public string Title { get; set; } = string.Empty;

    [JsonPropertyName("artist")]
    public string Artist { get; set; } = string.Empty;

    [JsonPropertyName("genre")]
    public List<string> Genre { get; set; } = new();

    [JsonPropertyName("similarity_score")]
    public double SimilarityScore { get; set; }
}

