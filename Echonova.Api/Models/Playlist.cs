using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace Echonova.Api.Models;

public class Playlist
{
    [BsonId]
    [BsonRepresentation(BsonType.String)]
    public Guid Id { get; set; }

    [BsonRepresentation(BsonType.String)]
    [BsonElement("user_id")]
    public Guid UserId { get; set; }
    [BsonElement("name")]
    public string Name { get; set; } = string.Empty;
    [BsonElement("tracks_id")]
    public List<string> TracksId { get; set; } = new();
}
