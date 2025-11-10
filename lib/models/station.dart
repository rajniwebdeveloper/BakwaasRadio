class Station {
  final String id;
  final String name;
  final String? description;
  final String? profilepic;
  final String? banner;
  final String? mp3Url;
  final String? playerUrl;
  final String? streamURL;
  final String? seriesName;
  final int? episodeNumber;
  final String? episodeTitle;
  final bool isStandalone;
  final bool isPaid;
  final int audioCount;
  final String? duration;
  final String? genre;
  final String? contentLanguage;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  Station({
    required this.id,
    required this.name,
    this.description,
    this.profilepic,
    this.banner,
    this.mp3Url,
    this.playerUrl,
    this.streamURL,
    this.seriesName,
    this.episodeNumber,
    this.episodeTitle,
    required this.isStandalone,
    required this.isPaid,
    required this.audioCount,
    this.duration,
    this.genre,
    this.contentLanguage,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      id: json['_id'],
      name: json['name'],
      description: json['description'],
      profilepic: json['profilepic'],
      banner: json['banner'],
      mp3Url: json['mp3Url'],
      playerUrl: json['playerUrl'],
      streamURL: json['streamURL'],
      seriesName: json['seriesName'],
      episodeNumber: json['episodeNumber'],
      episodeTitle: json['episodeTitle'],
      isStandalone: json['isStandalone'] ?? false,
      isPaid: json['isPaid'] ?? false,
      audioCount: json['audioCount'] ?? 1,
      duration: json['duration'],
      genre: json['genre'],
      contentLanguage: json['contentLanguage'],
      tags: List<String>.from(json['tags'] ?? []),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }
}
