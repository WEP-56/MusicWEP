import 'media_constants.dart';

Map<String, dynamic> resetMediaItem(
  Map<String, dynamic> mediaItem, {
  String? platform,
  bool clone = false,
}) {
  final currentPlatform = (platform ?? mediaItem['platform'])?.toString() ?? '';
  if (mediaItem['platform']?.toString() == localPluginName ||
      currentPlatform == localPluginName) {
    return clone ? Map<String, dynamic>.from(mediaItem) : mediaItem;
  }

  final next = clone ? Map<String, dynamic>.from(mediaItem) : mediaItem;
  next['platform'] = currentPlatform;
  next.remove(internalDataKey);
  return next;
}

String getMediaPrimaryKey(Map<String, dynamic>? mediaItem) {
  if (mediaItem == null) {
    return 'invalid@invalid';
  }
  final platform = mediaItem['platform']?.toString() ?? 'invalid';
  final id = mediaItem['id']?.toString() ?? 'invalid';
  return '$platform@$id';
}

Map<String, dynamic> toMediaBase(Map<String, dynamic> mediaItem) {
  return <String, dynamic>{
    'platform': mediaItem['platform'],
    'id': mediaItem['id'],
  };
}
