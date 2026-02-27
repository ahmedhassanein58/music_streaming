namespace Echonova.Api.Options;

public class MlServicesOptions
{
    public const string SectionName = "MlServices";

    /// <summary>
    /// Base URL for the facial emotion FastAPI service, e.g. http://localhost:8000
    /// </summary>
    public string FacialApiBaseUrl { get; set; } = "http://localhost:8000";

    /// <summary>
    /// Base URL for the music recommendation FastAPI service, e.g. http://localhost:8001
    /// </summary>
    public string MusicRecApiBaseUrl { get; set; } = "http://localhost:8001";
}

