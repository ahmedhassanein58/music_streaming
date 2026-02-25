namespace Echonova.Api.DTOs;

public record AnonymousSessionRequest(string BrowserFingerprint);

public record AnonymousSessionResponse(Guid SessionId);
