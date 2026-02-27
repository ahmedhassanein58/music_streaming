using Echonova.Api.Models;

namespace Echonova.Api.DTOs;

public record SongResponse(Guid Id, string TrackId, string Title, string Artist, List<string> Genre, AudioFeature AudioFeature, string S3Url, string? CoverUrl);

public record SongListResponse(IReadOnlyList<SongResponse> Items, int Total);

/// <summary>
/// Pairs each requested track ID with its resolved song (or null if not found).
/// Lets clients match playlist track IDs to songs without normalizing ID format.
/// </summary>
public record SongByTrackIdResult(string RequestedTrackId, SongResponse? Song);
