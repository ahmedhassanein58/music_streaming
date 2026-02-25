using Echonova.Api.Models;
using MongoDB.Driver;

namespace Echonova.Api.Services;

public interface IAnonymousSessionService
{
    Task<Guid> CreateOrGetAsync(string browserFingerprint, CancellationToken ct = default);
}

public class AnonymousSessionService : IAnonymousSessionService
{
    private readonly IMongoCollection<AnonymousSession> _sessions;

    public AnonymousSessionService(IMongoCollection<AnonymousSession> sessions)
    {
        _sessions = sessions;
    }

    public async Task<Guid> CreateOrGetAsync(string browserFingerprint, CancellationToken ct = default)
    {
        var existing = await _sessions.Find(s => s.BrowserFingerprint == browserFingerprint).FirstOrDefaultAsync(ct);
        if (existing != null) return existing.Id;

        var session = new AnonymousSession
        {
            Id = Guid.NewGuid(),
            BrowserFingerprint = browserFingerprint,
            UserId = null
        };
        await _sessions.InsertOneAsync(session, cancellationToken: ct);
        return session.Id;
    }
}
