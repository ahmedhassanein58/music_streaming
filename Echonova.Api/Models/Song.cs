using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace Echonova.Api.Models;

public class Song
{
    [BsonId]
    [BsonRepresentation(BsonType.String)]
    public Guid Id { get; set; }

    [BsonElement("track_id")]
    public string TrackId { get; set; } = string.Empty;
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
    [BsonElement("cover_url")]
    public string? CoverUrl { get; set; }
}
