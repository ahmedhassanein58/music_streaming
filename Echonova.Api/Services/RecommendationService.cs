using System.Net.Http.Json;
using Echonova.Api.DTOs;
using Echonova.Api.Options;
using Microsoft.Extensions.Options;

namespace Echonova.Api.Services;

public interface IRecommendationService
{
    Task<IReadOnlyList<SongResponse>> RecommendByTrackIdAsync(string trackId, int n, CancellationToken ct = default);
    Task<IReadOnlyList<SongResponse>> RecommendFromMultipleAsync(IReadOnlyList<string> trackIds, int n, CancellationToken ct = default);
}

public class RecommendationService : IRecommendationService
{
    private readonly ISongService _songs;
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly MlServicesOptions _options;

    public RecommendationService(
        ISongService songs,
        IHttpClientFactory httpClientFactory,
        IOptions<MlServicesOptions> options)
    {
        _songs = songs;
        _httpClientFactory = httpClientFactory;
        _options = options.Value;
    }

    public async Task<IReadOnlyList<SongResponse>> RecommendByTrackIdAsync(string trackId, int n, CancellationToken ct = default)
    {
        var seedSong = await _songs.GetByTrackIdAsync(trackId, ct);
        if (seedSong is null) return Array.Empty<SongResponse>();

        var payload = new { title = seedSong.Title, n };
        var items = await CallMusicRecApiAsync("/recommend/by-title", payload, ct);
        return await MapToSongsAsync(items, ct);
    }

    public async Task<IReadOnlyList<SongResponse>> RecommendFromMultipleAsync(IReadOnlyList<string> trackIds, int n, CancellationToken ct = default)
    {
        if (trackIds.Count == 0) return Array.Empty<SongResponse>();

        var titles = new List<string>();
        foreach (var id in trackIds.Distinct())
        {
            var song = await _songs.GetByTrackIdAsync(id, ct);
            if (song != null && !string.IsNullOrWhiteSpace(song.Title))
                titles.Add(song.Title);
        }

        if (titles.Count == 0) return Array.Empty<SongResponse>();

        var payload = new { titles, n };
        var items = await CallMusicRecApiAsync("/recommend/from-multiple", payload, ct);
        return await MapToSongsAsync(items, ct);
    }

    private async Task<IReadOnlyList<MusicRecItemDto>> CallMusicRecApiAsync(string path, object payload, CancellationToken ct)
    {
        var baseUrl = _options.MusicRecApiBaseUrl?.TrimEnd('/');
        if (string.IsNullOrWhiteSpace(baseUrl))
            throw new InvalidOperationException("MusicRecApiBaseUrl is not configured.");

        var client = _httpClientFactory.CreateClient("music-rec");
        client.BaseAddress ??= new Uri(baseUrl);

        using var response = await client.PostAsJsonAsync(path, payload, ct);
        response.EnsureSuccessStatusCode();

        var root = await response.Content.ReadFromJsonAsync<MusicRecRootDto>(cancellationToken: ct);
        return root?.Items ?? new List<MusicRecItemDto>();
    }

    private async Task<IReadOnlyList<SongResponse>> MapToSongsAsync(IReadOnlyList<MusicRecItemDto> items, CancellationToken ct)
    {
        var results = new List<SongResponse>();
        foreach (var item in items)
        {
            var song = await _songs.GetByTitleAndArtistAsync(item.Title, item.Artist, ct);
            if (song != null) results.Add(song);
        }
        return results;
    }

    private sealed class MusicRecRootDto
    {
        public List<MusicRecItemDto> Items { get; set; } = new();
    }
}
