using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace Echonova.Api.Models;

public class Song
{
    [BsonId]
    [BsonRepresentation(BsonType.String)]
    public Guid Id { get; set; }

    [BsonRepresentation(BsonType.String)]
    [BsonElement("track_id")]
    public Guid TrackId { get; set; }
    [BsonElement("title")]
    public string Title { get; set; } = string.Empty;
    [BsonElement("artist")]
    public string Artist { get; set; } = string.Empty;
    [BsonElement("genre")]
    public List<string> Genre { get; set; } = new();
    [BsonElement("audio_feature")]
    public AudioFeature AudioFeature { get; set; } = new();
    [BsonElement("s3_url")]
    public string S3Url { get; set; } = string.Empty;
}
