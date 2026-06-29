namespace Echonova.Api.Services;

public static class EmotionGenreMapper
{
    private static readonly Dictionary<string, string[]> Map = new(StringComparer.OrdinalIgnoreCase)
    {
        ["happy"] = ["Pop", "Dance", "Electronic", "Hip-Hop"],
        ["sad"] = ["Blues", "Acoustic", "Indie-Rock", "Folk"],
        ["angry"] = ["Rock", "Loud-Rock", "Metal", "Punk"],
        ["fear"] = ["Ambient", "Electronic", "Psych-Rock"],
        ["surprise"] = ["Pop", "Electronic", "Indie-Rock"],
        ["neutral"] = ["Pop", "Rock", "Hip-Hop"],
        ["disgust"] = ["Experimental", "Loud-Rock", "Metal"],
    };

    public static IReadOnlyList<string> GetGenresForEmotion(string emotion)
    {
        if (Map.TryGetValue(emotion, out var genres))
            return genres;
        return Map["neutral"];
    }

    public static IReadOnlyList<string> GetBlendedGenres(
        IReadOnlyDictionary<string, double> probabilities,
        int maxGenres = 8)
    {
        var top = probabilities
            .OrderByDescending(p => p.Value)
            .Take(3)
            .Where(p => p.Value >= 0.10)
            .ToList();

        if (top.Count == 0)
        {
            var primary = probabilities.OrderByDescending(p => p.Value).FirstOrDefault();
            if (primary.Key != null)
                top = [primary];
            else
                return Map["neutral"];
        }

        var genreScores = new Dictionary<string, double>(StringComparer.OrdinalIgnoreCase);
        foreach (var (emotion, weight) in top)
        {
            foreach (var genre in GetGenresForEmotion(emotion))
            {
                genreScores[genre] = genreScores.GetValueOrDefault(genre) + weight;
            }
        }

        return genreScores
            .OrderByDescending(g => g.Value)
            .Select(g => g.Key)
            .Take(maxGenres)
            .ToList();
    }

    public static IReadOnlyList<(string Emotion, double Weight)> GetMoodMix(
        IReadOnlyDictionary<string, double> probabilities,
        double minWeight = 0.10,
        int maxCount = 3)
    {
        return probabilities
            .OrderByDescending(p => p.Value)
            .Where(p => p.Value >= minWeight)
            .Take(maxCount)
            .Select(p => (p.Key, p.Value))
            .ToList();
    }
}
