using Echonova.Api.Models;
using MongoDB.Bson;
using MongoDB.Bson.IO;
using MongoDB.Bson.Serialization;
using MongoDB.Bson.Serialization.Serializers;

namespace Echonova.Api.Serialization;

/// <summary>
/// Atlas data stores audio_feature either as a named document or as an 8-value array
/// [acousticness, danceability, energy, instrumentalness, liveness, speechiness, tempo, valence].
/// </summary>
public sealed class AudioFeatureSerializer : SerializerBase<AudioFeature>
{
    public override AudioFeature Deserialize(BsonDeserializationContext context, BsonDeserializationArgs args)
    {
        var reader = context.Reader;
        var bsonType = reader.GetCurrentBsonType();

        if (bsonType == BsonType.Null)
        {
            reader.ReadNull();
            return new AudioFeature();
        }

        if (bsonType == BsonType.Array)
        {
            var array = BsonArraySerializer.Instance.Deserialize(context, args);
            var values = array.Select(v => v.ToDouble()).ToList();
            return FromArray(values);
        }

        if (bsonType == BsonType.Document)
        {
            var doc = BsonDocumentSerializer.Instance.Deserialize(context, args);
            return new AudioFeature
            {
                Acousticness = GetDouble(doc, "acousticness"),
                Danceability = GetDouble(doc, "danceability"),
                Energy = GetDouble(doc, "energy"),
                Instrumentalness = GetDouble(doc, "instrumentalness"),
                Liveness = GetDouble(doc, "liveness"),
                Speechiness = GetDouble(doc, "speechiness"),
                Tempo = GetDouble(doc, "tempo"),
                Valence = GetDouble(doc, "valence"),
            };
        }

        reader.SkipValue();
        return new AudioFeature();
    }

    public override void Serialize(BsonSerializationContext context, BsonSerializationArgs args, AudioFeature value)
    {
        context.Writer.WriteStartDocument();
        WriteNamed(context.Writer, "acousticness", value.Acousticness);
        WriteNamed(context.Writer, "danceability", value.Danceability);
        WriteNamed(context.Writer, "energy", value.Energy);
        WriteNamed(context.Writer, "instrumentalness", value.Instrumentalness);
        WriteNamed(context.Writer, "liveness", value.Liveness);
        WriteNamed(context.Writer, "speechiness", value.Speechiness);
        WriteNamed(context.Writer, "tempo", value.Tempo);
        WriteNamed(context.Writer, "valence", value.Valence);
        context.Writer.WriteEndDocument();
    }

    private static AudioFeature FromArray(List<double> values)
    {
        double? At(int i) => values.Count > i ? values[i] : null;
        return new AudioFeature
        {
            Acousticness = At(0),
            Danceability = At(1),
            Energy = At(2),
            Instrumentalness = At(3),
            Liveness = At(4),
            Speechiness = At(5),
            Tempo = At(6),
            Valence = At(7),
        };
    }

    private static double? GetDouble(BsonDocument doc, string name) =>
        doc.TryGetValue(name, out var v) && v.IsNumeric ? v.ToDouble() : null;

    private static void WriteNamed(IBsonWriter writer, string name, double? value)
    {
        writer.WriteName(name);
        if (value.HasValue) writer.WriteDouble(value.Value);
        else writer.WriteNull();
    }
}
