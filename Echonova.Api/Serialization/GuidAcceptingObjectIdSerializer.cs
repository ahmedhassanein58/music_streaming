using System.Security.Cryptography;
using System.Text;
using MongoDB.Bson;
using MongoDB.Bson.Serialization;
using MongoDB.Bson.Serialization.Serializers;

namespace Echonova.Api.Serialization;

/// <summary>
/// Serializes Guid to/from BSON. Accepts ObjectId, 24-char ObjectId hex strings, and normal Guid strings
/// so that existing MongoDB documents with ObjectId or string IDs can be read.
/// </summary>
public class GuidAcceptingObjectIdSerializer : SerializerBase<Guid>
{
    private static readonly GuidSerializer DefaultSerializer = new(BsonType.String);

    public override Guid Deserialize(BsonDeserializationContext context, BsonDeserializationArgs args)
    {
        var bsonType = context.Reader.GetCurrentBsonType();
        if (bsonType == BsonType.ObjectId)
        {
            var objectId = context.Reader.ReadObjectId();
            var bytes = new byte[16];
            var oidBytes = objectId.ToByteArray();
            Array.Copy(oidBytes, 0, bytes, 0, Math.Min(12, oidBytes.Length));
            return new Guid(bytes);
        }
        if (bsonType == BsonType.String)
        {
            var s = context.Reader.ReadString();
            if (Guid.TryParse(s, out var guid))
                return guid;
            // 24 hex chars = ObjectId as string (e.g. "507f1f77bcf86cd799439011")
            if (s != null && s.Length == 24 && IsHexString(s))
            {
                var bytes = new byte[16];
                for (var i = 0; i < 12; i++)
                    bytes[i] = Convert.ToByte(s.Substring(i * 2, 2), 16);
                return new Guid(bytes);
            }
            // Plain string (e.g. "829") -> deterministic Guid so list and get-by-trackId work
            if (!string.IsNullOrEmpty(s))
                return CreateDeterministicGuid(s);
            return Guid.Empty;
        }
        return DefaultSerializer.Deserialize(context, args);
    }

    private static bool IsHexString(string s)
    {
        foreach (var c in s)
            if (!Uri.IsHexDigit(c)) return false;
        return true;
    }

    private static Guid CreateDeterministicGuid(string s)
    {
        var bytes = MD5.HashData(Encoding.UTF8.GetBytes(s));
        return new Guid(bytes);
    }

    public override void Serialize(BsonSerializationContext context, BsonSerializationArgs args, Guid value)
    {
        DefaultSerializer.Serialize(context, args, value);
    }
}
