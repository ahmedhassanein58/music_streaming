using MongoDB.Bson.Serialization.Attributes;

namespace Echonova.Api.Models;

public class AudioFeature
{
    [BsonElement("acousticness")]
    public double? Acousticness { get; set; }
    [BsonElement("danceability")]
    public double? Danceability { get; set; }
    [BsonElement("energy")]
    public double? Energy { get; set; }
    [BsonElement("instrumentalness")]
    public double? Instrumentalness { get; set; }
    [BsonElement("liveness")]
    public double? Liveness { get; set; }
    [BsonElement("speechiness")]
    public double? Speechiness { get; set; }
    [BsonElement("tempo")]
    public double? Tempo { get; set; }
    [BsonElement("valence")]
    public double? Valence { get; set; }
}
