class IdentifyResult {
  final String title;
  final String? artist;

  const IdentifyResult({required this.title, this.artist});
}

class IdentifyRepository {
  /// Stub: simulates a recognition API call. Returns null until a real
  /// audio upload + external API is wired in.
  Future<IdentifyResult?> identify() async {
    // TODO: POST audio to recognition API (e.g. Audd.io, AcoustID)
    await Future.delayed(const Duration(seconds: 2));
    return null;
  }
}
