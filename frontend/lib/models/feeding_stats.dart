class FeedingStats {
  final int totalPellets;
  final int visiblePellets;
  final int peakVisible;
  final double uneatenRatio;
  final double fps;
  final double elapsedSeconds;
  final DateTime? startedAt;

  const FeedingStats({
    this.totalPellets = 0,
    this.visiblePellets = 0,
    this.peakVisible = 0,
    this.uneatenRatio = 0,
    this.fps = 0,
    this.elapsedSeconds = 0,
    this.startedAt,
  });

  factory FeedingStats.fromJson(Map<String, dynamic> j) => FeedingStats(
        totalPellets: (j['total_pellets'] ?? 0) as int,
        visiblePellets: (j['visible_pellets'] ?? 0) as int,
        peakVisible: (j['peak_visible'] ?? 0) as int,
        uneatenRatio: ((j['uneaten_ratio'] ?? 0) as num).toDouble(),
        fps: ((j['fps'] ?? 0) as num).toDouble(),
        elapsedSeconds: ((j['elapsed_s'] ?? 0) as num).toDouble(),
        startedAt: j['started_at'] != null
            ? DateTime.tryParse(j['started_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'total_pellets': totalPellets,
        'visible_pellets': visiblePellets,
        'peak_visible': peakVisible,
        'uneaten_ratio': uneatenRatio,
        'fps': fps,
        'elapsed_s': elapsedSeconds,
        'started_at': startedAt?.toIso8601String(),
      };
}
