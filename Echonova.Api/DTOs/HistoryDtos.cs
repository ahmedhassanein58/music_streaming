namespace Echonova.Api.DTOs;

public record HistoryResponse(Guid Id, Guid UserId, Guid TrackId, int PlayCount, DateTime LastPlayed, string? Title = null, string? Artist = null);

public record RecordPlayRequest(string TrackId);
