using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace Echonova.Api.Models;

public class AnonymousSession
{
    [BsonId]
    [BsonRepresentation(BsonType.String)]
    public Guid Id { get; set; }

    [BsonElement("browser_fingerprint")]
    public string BrowserFingerprint { get; set; } = string.Empty;
    [BsonRepresentation(BsonType.String)]
    [BsonElement("user_id")]
    [BsonIgnoreIfDefault]
    public Guid? UserId { get; set; }
}
