using Echonova.Api.Models;

namespace Echonova.Api.DTOs;

public record AdminCreateSongRequest(string Title, string Artist, List<string> Genre, AudioFeature AudioFeature, string? S3Url);

public record AdminUpdateSongRequest(string? Title, string? Artist, List<string>? Genre, AudioFeature? AudioFeature, string? S3Url);

public record AdminCreateUserRequest(string Username, string Email, string Password);
