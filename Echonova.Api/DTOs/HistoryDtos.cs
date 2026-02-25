namespace Echonova.Api.DTOs;

public record HistoryResponse(Guid Id, Guid UserId, Guid TrackId, int PlayCount, DateTime LastPlayed);

public record RecordPlayRequest(string TrackId);
