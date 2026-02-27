namespace Echonova.Api.Services;

public interface IProfileImageStorageService
{
    Task<string> SaveAsync(Guid userId, Stream stream, string contentType, CancellationToken ct = default);
}

public class LocalProfileImageStorageService : IProfileImageStorageService
{
    private readonly IWebHostEnvironment _env;
    private const string SubDir = "profile-images";
    private const long MaxSizeBytes = 5 * 1024 * 1024; // 5 MB
    private static readonly HashSet<string> AllowedTypes = new(StringComparer.OrdinalIgnoreCase)
        { "image/jpeg", "image/png", "image/webp" };

    public LocalProfileImageStorageService(IWebHostEnvironment env)
    {
        _env = env;
    }

    public async Task<string> SaveAsync(Guid userId, Stream stream, string contentType, CancellationToken ct = default)
    {
        if (!AllowedTypes.Contains(contentType))
            throw new ArgumentException("Invalid image type. Use JPEG, PNG, or WebP.");

        var ext = contentType switch
        {
            "image/jpeg" => ".jpg",
            "image/png" => ".png",
            "image/webp" => ".webp",
            _ => ".jpg"
        };

        var webRoot = _env.WebRootPath ?? Path.Combine(_env.ContentRootPath ?? ".", "wwwroot");
        var dir = Path.Combine(webRoot, SubDir);
        Directory.CreateDirectory(dir);

        var fileName = $"{userId}{ext}";
        var filePath = Path.Combine(dir, fileName);

        await using var fileStream = File.Create(filePath);
        var buffer = new byte[8192];
        long totalRead = 0;
        int read;
        while ((read = await stream.ReadAsync(buffer, ct)) > 0)
        {
            totalRead += read;
            if (totalRead > MaxSizeBytes)
                throw new InvalidOperationException("Image too large. Max 5 MB.");
            await fileStream.WriteAsync(buffer.AsMemory(0, read), ct);
        }

        return $"/{SubDir}/{fileName}";
    }
}
