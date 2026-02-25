namespace Echonova.Api.Options;

public class UploadOptions
{
    public const string SectionName = "Upload";
    public long MaxFileSizeBytes { get; set; } = 20 * 1024 * 1024; // 20 MB
    public string[] AllowedExtensions { get; set; } = [".mp3", ".wav"];
}
