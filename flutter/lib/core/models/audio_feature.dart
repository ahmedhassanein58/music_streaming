class AudioFeature {
  final double acousticness;
  final double danceability;
  final double energy;
  final double instrumentalness;
  final double liveness;
  final double speechiness;
  final double tempo;
  final double valence;

  const AudioFeature({
    this.acousticness = 0,
    this.danceability = 0,
    this.energy = 0,
    this.instrumentalness = 0,
    this.liveness = 0,
    this.speechiness = 0,
    this.tempo = 0,
    this.valence = 0,
  });

  factory AudioFeature.fromJson(Map<String, dynamic> json) {
    return AudioFeature(
      acousticness: (json['acousticness'] as num?)?.toDouble() ?? 0,
      danceability: (json['danceability'] as num?)?.toDouble() ?? 0,
      energy: (json['energy'] as num?)?.toDouble() ?? 0,
      instrumentalness: (json['instrumentalness'] as num?)?.toDouble() ?? 0,
      liveness: (json['liveness'] as num?)?.toDouble() ?? 0,
      speechiness: (json['speechiness'] as num?)?.toDouble() ?? 0,
      tempo: (json['tempo'] as num?)?.toDouble() ?? 0,
      valence: (json['valence'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'acousticness': acousticness,
        'danceability': danceability,
        'energy': energy,
        'instrumentalness': instrumentalness,
        'liveness': liveness,
        'speechiness': speechiness,
        'tempo': tempo,
        'valence': valence,
      };
}
