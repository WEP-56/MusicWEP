enum PluginCapability {
  search('search', 'Search'),
  getMediaSource('getMediaSource', 'Media source'),
  getMusicInfo('getMusicInfo', 'Music info'),
  getLyric('getLyric', 'Lyric'),
  getAlbumInfo('getAlbumInfo', 'Album detail'),
  getMusicSheetInfo('getMusicSheetInfo', 'Playlist detail'),
  getArtistWorks('getArtistWorks', 'Artist works'),
  importMusicSheet('importMusicSheet', 'Import playlist'),
  importMusicItem('importMusicItem', 'Import track'),
  getTopLists('getTopLists', 'Top lists'),
  getTopListDetail('getTopListDetail', 'Top list detail'),
  getRecommendSheetTags('getRecommendSheetTags', 'Recommend tags'),
  getRecommendSheetsByTag('getRecommendSheetsByTag', 'Recommend playlists'),
  getMusicComments('getMusicComments', 'Comments');

  const PluginCapability(this.method, this.label);

  final String method;
  final String label;

  static PluginCapability? fromMethod(String method) {
    for (final capability in PluginCapability.values) {
      if (capability.method == method) {
        return capability;
      }
    }
    return null;
  }
}
