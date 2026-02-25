using Echonova.Api.Options;
using Microsoft.Extensions.Options;

namespace Echonova.Api.Services;

public interface IStorageService
{
    Task<string> UploadAsync(Stream stream, string key, string contentType, CancellationToken ct = default);
}

public class S3StorageService : IStorageService
{
    private readonly AwsOptions _options;

    public S3StorageService(IOptions<AwsOptions> options)
    {
        _options = options.Value;
    }

    public async Task<string> UploadAsync(Stream stream, string key, string contentType, CancellationToken ct = default)
    {
        var config = new Amazon.S3.AmazonS3Config
        {
            RegionEndpoint = Amazon.RegionEndpoint.GetBySystemName(_options.Region)
        };
        using var client = new Amazon.S3.AmazonS3Client(_options.AccessKeyId, _options.SecretAccessKey, config);
        var request = new Amazon.S3.Model.PutObjectRequest
        {
            BucketName = _options.BucketName,
            Key = key,
            InputStream = stream,
            ContentType = contentType
        };
        await client.PutObjectAsync(request, ct);
        return $"https://{_options.BucketName}.s3.{_options.Region}.amazonaws.com/{key}";
    }
}
