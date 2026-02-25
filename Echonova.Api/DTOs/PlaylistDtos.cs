namespace Echonova.Api.DTOs;

public record PlaylistResponse(Guid Id, Guid UserId, string Name, List<string> TracksId);

public record CreatePlaylistRequest(string Name, List<string>? TracksId);

public record UpdatePlaylistRequest(string? Name, List<string>? TracksId);

public record AddTracksRequest(List<string> TrackIds);
