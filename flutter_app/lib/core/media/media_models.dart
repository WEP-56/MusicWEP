enum MediaType {
  music('music'),
  album('album'),
  artist('artist'),
  sheet('sheet'),
  lyric('lyric');

  const MediaType(this.value);

  final String value;
}

abstract class MediaItem {
  const MediaItem({
    required this.platform,
    required this.id,
    this.extra = const <String, dynamic>{},
  });

  final String platform;
  final String id;
  final Map<String, dynamic> extra;

  MediaType get mediaType;
  String get displayTitle;
  String get displaySubtitle;
  Map<String, dynamic> toJson();
}

class MusicItem extends MediaItem {
  const MusicItem({
    required super.platform,
    required super.id,
    required this.title,
    required this.artist,
    this.duration,
    this.album,
    this.artwork,
    this.url,
    this.lyricUrl,
    this.rawLyric,
    this.localPath,
    this.qualities = const <String, Map<String, dynamic>>{},
    super.extra = const <String, dynamic>{},
  });

  final String title;
  final String artist;
  final int? duration;
  final String? album;
  final String? artwork;
  final String? url;
  final String? lyricUrl;
  final String? rawLyric;
  final String? localPath;
  final Map<String, Map<String, dynamic>> qualities;

  @override
  MediaType get mediaType => MediaType.music;

  @override
  String get displayTitle => title;

  @override
  String get displaySubtitle =>
      <String>[artist, if (album?.isNotEmpty == true) album!].join(' · ');

  factory MusicItem.fromJson(Map<String, dynamic> json) {
    return MusicItem(
      platform: json['platform']?.toString() ?? '',
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      artist: json['artist']?.toString() ?? '',
      duration: (json['duration'] as num?)?.toInt(),
      album: json['album']?.toString(),
      artwork: json['artwork']?.toString(),
      url: json['url']?.toString(),
      lyricUrl: json['lrc']?.toString(),
      rawLyric: json['rawLrc']?.toString(),
      localPath:
          json['localPath']?.toString() ?? json[r'$$localPath']?.toString(),
      qualities: _readNestedMap(json['qualities']),
      extra: _readExtra(json, <String>{
        'platform',
        'id',
        'title',
        'artist',
        'duration',
        'album',
        'artwork',
        'url',
        'lrc',
        'rawLrc',
        'localPath',
        r'$$localPath',
        'qualities',
      }),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'platform': platform,
      'id': id,
      'title': title,
      'artist': artist,
      'duration': duration,
      'album': album,
      'artwork': artwork,
      'url': url,
      'lrc': lyricUrl,
      'rawLrc': rawLyric,
      'localPath': localPath,
      if (qualities.isNotEmpty) 'qualities': qualities,
      ...extra,
    };
  }

  MusicItem mergePatch(MusicInfoPatch patch) {
    return MusicItem(
      platform: platform,
      id: id,
      title: patch.title ?? title,
      artist: patch.artist ?? artist,
      duration: patch.duration ?? duration,
      album: patch.album ?? album,
      artwork: patch.artwork ?? artwork,
      url: patch.url ?? url,
      lyricUrl: patch.lyricUrl ?? lyricUrl,
      rawLyric: patch.rawLyric ?? rawLyric,
      localPath: patch.localPath ?? localPath,
      qualities: patch.qualities.isNotEmpty ? patch.qualities : qualities,
      extra: <String, dynamic>{...extra, ...patch.extra},
    );
  }
}

class AlbumItem extends MediaItem {
  const AlbumItem({
    required super.platform,
    required super.id,
    required this.title,
    this.artist,
    this.description,
    this.artwork,
    this.date,
    this.worksNum,
    this.musicList = const <MusicItem>[],
    super.extra = const <String, dynamic>{},
  });

  final String title;
  final String? artist;
  final String? description;
  final String? artwork;
  final String? date;
  final int? worksNum;
  final List<MusicItem> musicList;

  @override
  MediaType get mediaType => MediaType.album;

  @override
  String get displayTitle => title;

  @override
  String get displaySubtitle => artist ?? '';

  factory AlbumItem.fromJson(Map<String, dynamic> json) {
    return AlbumItem(
      platform: json['platform']?.toString() ?? '',
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      artist: json['artist']?.toString(),
      description: json['description']?.toString(),
      artwork: json['artwork']?.toString(),
      date: json['date']?.toString(),
      worksNum: (json['worksNum'] as num?)?.toInt(),
      musicList: _readMusicList(json['musicList']),
      extra: _readExtra(json, <String>{
        'platform',
        'id',
        'title',
        'artist',
        'description',
        'artwork',
        'date',
        'worksNum',
        'musicList',
      }),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'platform': platform,
      'id': id,
      'title': title,
      'artist': artist,
      'description': description,
      'artwork': artwork,
      'date': date,
      'worksNum': worksNum,
      if (musicList.isNotEmpty)
        'musicList': musicList
            .map((item) => item.toJson())
            .toList(growable: false),
      ...extra,
    };
  }
}

class ArtistItem extends MediaItem {
  const ArtistItem({
    required super.platform,
    required super.id,
    required this.name,
    this.avatar,
    this.description,
    this.fans,
    super.extra = const <String, dynamic>{},
  });

  final String name;
  final String? avatar;
  final String? description;
  final int? fans;

  @override
  MediaType get mediaType => MediaType.artist;

  @override
  String get displayTitle => name;

  @override
  String get displaySubtitle => description ?? '';

  factory ArtistItem.fromJson(Map<String, dynamic> json) {
    return ArtistItem(
      platform: json['platform']?.toString() ?? '',
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      avatar: json['avatar']?.toString(),
      description: json['description']?.toString(),
      fans: (json['fans'] as num?)?.toInt(),
      extra: _readExtra(json, <String>{
        'platform',
        'id',
        'name',
        'avatar',
        'description',
        'fans',
      }),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'platform': platform,
      'id': id,
      'name': name,
      'avatar': avatar,
      'description': description,
      'fans': fans,
      ...extra,
    };
  }
}

class MusicSheetItem extends MediaItem {
  const MusicSheetItem({
    required super.platform,
    required super.id,
    required this.title,
    this.artist,
    this.description,
    this.artwork,
    this.worksNum,
    this.playCount,
    this.createAt,
    this.musicList = const <MusicItem>[],
    super.extra = const <String, dynamic>{},
  });

  final String title;
  final String? artist;
  final String? description;
  final String? artwork;
  final int? worksNum;
  final int? playCount;
  final int? createAt;
  final List<MusicItem> musicList;

  @override
  MediaType get mediaType => MediaType.sheet;

  @override
  String get displayTitle => title;

  @override
  String get displaySubtitle => artist ?? '';

  factory MusicSheetItem.fromJson(Map<String, dynamic> json) {
    return MusicSheetItem(
      platform: json['platform']?.toString() ?? '',
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      artist: json['artist']?.toString(),
      description: json['description']?.toString(),
      artwork: json['artwork']?.toString(),
      worksNum: (json['worksNum'] as num?)?.toInt(),
      playCount: (json['playCount'] as num?)?.toInt(),
      createAt: (json['createAt'] as num?)?.toInt(),
      musicList: _readMusicList(json['musicList']),
      extra: _readExtra(json, <String>{
        'platform',
        'id',
        'title',
        'artist',
        'description',
        'artwork',
        'worksNum',
        'playCount',
        'createAt',
        'musicList',
      }),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'platform': platform,
      'id': id,
      'title': title,
      'artist': artist,
      'description': description,
      'artwork': artwork,
      'worksNum': worksNum,
      'playCount': playCount,
      'createAt': createAt,
      if (musicList.isNotEmpty)
        'musicList': musicList
            .map((item) => item.toJson())
            .toList(growable: false),
      ...extra,
    };
  }
}

class MediaTag {
  const MediaTag({
    required this.id,
    this.name,
    this.extra = const <String, dynamic>{},
  });

  final String id;
  final String? name;
  final Map<String, dynamic> extra;

  factory MediaTag.fromJson(Map<String, dynamic> json) {
    return MediaTag(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['title']?.toString(),
      extra: _readExtra(json, <String>{'id', 'name', 'title'}),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'id': id, 'name': name, ...extra};
  }
}

class MusicSheetGroup {
  const MusicSheetGroup({this.title, this.data = const <MusicSheetItem>[]});

  final String? title;
  final List<MusicSheetItem> data;

  factory MusicSheetGroup.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    return MusicSheetGroup(
      title: json['title']?.toString(),
      data: data is List
          ? data
                .whereType<Map>()
                .map(
                  (item) => MusicSheetItem.fromJson(
                    item.map((key, value) => MapEntry(key.toString(), value)),
                  ),
                )
                .toList(growable: false)
          : const <MusicSheetItem>[],
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'title': title,
      'data': data.map((item) => item.toJson()).toList(growable: false),
    };
  }
}

class CommentItem {
  const CommentItem({
    required this.nickName,
    required this.comment,
    this.id,
    this.avatar,
    this.like,
    this.createAt,
    this.location,
    this.replies = const <CommentItem>[],
    this.extra = const <String, dynamic>{},
  });

  final String nickName;
  final String comment;
  final String? id;
  final String? avatar;
  final int? like;
  final int? createAt;
  final String? location;
  final List<CommentItem> replies;
  final Map<String, dynamic> extra;

  factory CommentItem.fromJson(Map<String, dynamic> json) {
    final replies = json['replies'];
    return CommentItem(
      nickName: json['nickName']?.toString() ?? '',
      comment: json['comment']?.toString() ?? '',
      id: json['id']?.toString(),
      avatar: json['avatar']?.toString(),
      like: (json['like'] as num?)?.toInt(),
      createAt: (json['createAt'] as num?)?.toInt(),
      location: json['location']?.toString(),
      replies: replies is List
          ? replies
                .whereType<Map>()
                .map(
                  (item) => CommentItem.fromJson(
                    item.map((key, value) => MapEntry(key.toString(), value)),
                  ),
                )
                .toList(growable: false)
          : const <CommentItem>[],
      extra: _readExtra(json, <String>{
        'nickName',
        'comment',
        'id',
        'avatar',
        'like',
        'createAt',
        'location',
        'replies',
      }),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'nickName': nickName,
      'comment': comment,
      'id': id,
      'avatar': avatar,
      'like': like,
      'createAt': createAt,
      'location': location,
      if (replies.isNotEmpty)
        'replies': replies.map((item) => item.toJson()).toList(growable: false),
      ...extra,
    };
  }
}

class MusicInfoPatch {
  const MusicInfoPatch({
    this.title,
    this.artist,
    this.duration,
    this.album,
    this.artwork,
    this.url,
    this.lyricUrl,
    this.rawLyric,
    this.localPath,
    this.qualities = const <String, Map<String, dynamic>>{},
    this.extra = const <String, dynamic>{},
  });

  final String? title;
  final String? artist;
  final int? duration;
  final String? album;
  final String? artwork;
  final String? url;
  final String? lyricUrl;
  final String? rawLyric;
  final String? localPath;
  final Map<String, Map<String, dynamic>> qualities;
  final Map<String, dynamic> extra;

  factory MusicInfoPatch.fromJson(Map<String, dynamic> json) {
    return MusicInfoPatch(
      title: json['title']?.toString(),
      artist: json['artist']?.toString(),
      duration: (json['duration'] as num?)?.toInt(),
      album: json['album']?.toString(),
      artwork: json['artwork']?.toString(),
      url: json['url']?.toString(),
      lyricUrl: json['lrc']?.toString(),
      rawLyric: json['rawLrc']?.toString(),
      localPath:
          json['localPath']?.toString() ?? json[r'$$localPath']?.toString(),
      qualities: _readNestedMap(json['qualities']),
      extra: _readExtra(json, <String>{
        'title',
        'artist',
        'duration',
        'album',
        'artwork',
        'url',
        'lrc',
        'rawLrc',
        'localPath',
        r'$$localPath',
        'qualities',
      }),
    );
  }

  bool get isEmpty =>
      title == null &&
      artist == null &&
      duration == null &&
      album == null &&
      artwork == null &&
      url == null &&
      lyricUrl == null &&
      rawLyric == null &&
      localPath == null &&
      qualities.isEmpty &&
      extra.isEmpty;
}

List<MusicItem> _readMusicList(dynamic value) {
  if (value is! List) {
    return const <MusicItem>[];
  }
  return value
      .whereType<Map>()
      .map(
        (item) => MusicItem.fromJson(
          item.map((key, value) => MapEntry(key.toString(), value)),
        ),
      )
      .toList(growable: false);
}

Map<String, Map<String, dynamic>> _readNestedMap(dynamic value) {
  if (value is! Map) {
    return const <String, Map<String, dynamic>>{};
  }
  return value.map(
    (key, entry) => MapEntry(
      key.toString(),
      entry is Map
          ? entry.map(
              (nestedKey, nestedValue) =>
                  MapEntry(nestedKey.toString(), nestedValue),
            )
          : <String, dynamic>{},
    ),
  );
}

Map<String, dynamic> _readExtra(
  Map<String, dynamic> json,
  Set<String> excludedKeys,
) {
  final extra = <String, dynamic>{};
  for (final entry in json.entries) {
    if (!excludedKeys.contains(entry.key)) {
      extra[entry.key] = entry.value;
    }
  }
  return extra;
}
