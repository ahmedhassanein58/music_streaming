using Echonova.Api.Models;

namespace Echonova.Api.DTOs;

public record SongResponse(Guid Id, Guid TrackId, string Title, string Artist, List<string> Genre, AudioFeature AudioFeature, string S3Url);

public record SongListResponse(IReadOnlyList<SongResponse> Items, int Total);
