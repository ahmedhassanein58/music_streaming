using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace Echonova.Api.Models;

public class History
{
    [BsonId]
    [BsonRepresentation(BsonType.String)]
    public Guid Id { get; set; }

    [BsonRepresentation(BsonType.String)]
    [BsonElement("user_id")]
    public Guid UserId { get; set; }
    [BsonElement("track_id")]
    public string TrackId { get; set; } = string.Empty;
    [BsonElement("play_count")]
    public int PlayCount { get; set; }
    [BsonElement("last_played")]
    public DateTime LastPlayed { get; set; }
    [BsonElement("title")]
    public string? Title { get; set; }
    [BsonElement("artist")]
    public string? Artist { get; set; }
}
