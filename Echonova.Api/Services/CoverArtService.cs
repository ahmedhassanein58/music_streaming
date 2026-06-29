using System.Net.Http.Json;
using System.Text.Json.Serialization;
using Microsoft.Extensions.Caching.Memory;
using MongoDB.Driver;

namespace Echonova.Api.Services;

public interface ICoverArtService
{
    Task<string?> ResolveArtworkUrlAsync(string trackId, string title, string artist, CancellationToken ct = default);
}

public class CoverArtService : ICoverArtService
{
    private readonly HttpClient _http;
    private readonly IMemoryCache _cache;
    private readonly IMongoCollection<Models.Song> _songs;

    public CoverArtService(
        HttpClient http,
        IMemoryCache cache,
        IMongoCollection<Models.Song> songs)
    {
        _http = http;
        _cache = cache;
        _songs = songs;
    }

    public async Task<string?> ResolveArtworkUrlAsync(
        string trackId,
        string title,
        string artist,
        CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(trackId)) return null;

        var cacheKey = $"cover-art:{trackId}";
        if (_cache.TryGetValue(cacheKey, out string? cached) && !string.IsNullOrWhiteSpace(cached))
            return cached;

        var song = await _songs.Find(s => s.TrackId == trackId).FirstOrDefaultAsync(ct);
        if (song != null && !string.IsNullOrWhiteSpace(song.CoverUrl))
        {
            _cache.Set(cacheKey, song.CoverUrl, TimeSpan.FromDays(7));
            return song.CoverUrl;
        }

        var s3Cover = TryBuildS3CoverUrl(song?.S3Url, trackId);
        if (s3Cover != null && await UrlExistsAsync(s3Cover, ct))
        {
            await PersistCoverUrlAsync(trackId, s3Cover, ct);
            _cache.Set(cacheKey, s3Cover, TimeSpan.FromDays(7));
            return s3Cover;
        }

        var itunes = await LookupItunesArtworkAsync(title, artist, ct);
        if (!string.IsNullOrWhiteSpace(itunes))
        {
            await PersistCoverUrlAsync(trackId, itunes, ct);
            _cache.Set(cacheKey, itunes, TimeSpan.FromDays(7));
            return itunes;
        }

        var fallback = BuildFallbackAvatarUrl(title, artist);
        _cache.Set(cacheKey, fallback, TimeSpan.FromHours(6));
        return fallback;
    }

    private static string? TryBuildS3CoverUrl(string? s3Url, string trackId)
    {
        if (string.IsNullOrWhiteSpace(s3Url)) return null;
        if (!Uri.TryCreate(s3Url, UriKind.Absolute, out var uri)) return null;
        return $"{uri.Scheme}://{uri.Host}/covers/{trackId}.jpg";
    }

    private async Task<bool> UrlExistsAsync(string url, CancellationToken ct)
    {
        try
        {
            using var request = new HttpRequestMessage(HttpMethod.Head, url);
            using var response = await _http.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, ct);
            return response.IsSuccessStatusCode;
        }
        catch
        {
            return false;
        }
    }

    private async Task<string?> LookupItunesArtworkAsync(string title, string artist, CancellationToken ct)
    {
        var query = Uri.EscapeDataString($"{title} {artist}".Trim());
        if (string.IsNullOrWhiteSpace(query)) return null;

        try
        {
            var url = $"https://itunes.apple.com/search?term={query}&entity=song&limit=1";
            using var response = await _http.GetAsync(url, ct);
            if (!response.IsSuccessStatusCode) return null;

            var payload = await response.Content.ReadFromJsonAsync<ITunesSearchResponse>(cancellationToken: ct);
            var artwork = payload?.Results?.FirstOrDefault()?.ArtworkUrl100;
            if (string.IsNullOrWhiteSpace(artwork)) return null;

            return artwork.Replace("100x100bb", "600x600bb", StringComparison.Ordinal);
        }
        catch
        {
            return null;
        }
    }

    private static string BuildFallbackAvatarUrl(string title, string artist)
    {
        var label = !string.IsNullOrWhiteSpace(title) ? title : artist;
        if (string.IsNullOrWhiteSpace(label)) label = "Echo Nova";
        var initials = string.Concat(label.Split(' ', StringSplitOptions.RemoveEmptyEntries).Take(2).Select(w => char.ToUpperInvariant(w[0])));
        if (string.IsNullOrWhiteSpace(initials)) initials = "EN";
        return $"https://ui-avatars.com/api/?name={Uri.EscapeDataString(initials)}&background=7C3AED&color=fff&size=300&bold=true&format=png";
    }

    private async Task PersistCoverUrlAsync(string trackId, string coverUrl, CancellationToken ct)
    {
        await _songs.UpdateOneAsync(
            s => s.TrackId == trackId && (s.CoverUrl == null || s.CoverUrl == ""),
            MongoDB.Driver.Builders<Models.Song>.Update.Set(s => s.CoverUrl, coverUrl),
            cancellationToken: ct);
    }

    private sealed class ITunesSearchResponse
    {
        [JsonPropertyName("results")]
        public List<ITunesTrackResult>? Results { get; set; }
    }

    private sealed class ITunesTrackResult
    {
        [JsonPropertyName("artworkUrl100")]
        public string? ArtworkUrl100 { get; set; }
    }
}
