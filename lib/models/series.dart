class Series {
  final String id;
  final String name;
  final String? description;
  final String? profilepic;
  final String? banner;
  final String? genre;
  final String? language;
  final List<String> tags;
  final int episodeCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  Series({
    required this.id,
    required this.name,
    this.description,
    this.profilepic,
    this.banner,
    this.genre,
    this.language,
    required this.tags,
    required this.episodeCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Series.fromJson(Map<String, dynamic> json) {
    return Series(
      id: json['_id'],
      name: json['name'],
      description: json['description'] ?? json['seriesDescription'],
      profilepic: json['profilepic'],
      banner: json['banner'],
      genre: json['genre'],
      language: json['language'],
      tags: List<String>.from(json['tags'] ?? []),
      episodeCount: json['episodeCount'] ?? json['totalEpisodes'] ?? 0,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }
}
