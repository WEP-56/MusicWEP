# MusicFree Flutter 接手文档

## 1. 目标与边界

- 项目目标：使用 `Dart + Flutter` 复现原项目 `D:\musicWEP\example\MusicFreeDesktop-master`
- 当前优先级：`Windows` 优先，`Android` 后接
- 明确不做：主题下载、主题市场、主题包兼容
- 当前阶段重点：插件系统、搜索/发现/详情链路、宿主运行时能力

## 2. 当前完成情况

### 2.1 基础工程

- Flutter 工程位于：`D:\musicWEP\flutter_app`
- 已有基础结构：
  - `app/`
  - `core/`
  - `features/`
  - `shared/`
  - `test/`

### 2.2 插件安装与管理

已实现：

- 本地安装 `.js`
- 本地安装 `.json` 订阅源
- 远程安装 `.js`
- 远程安装 `.json` 订阅源
- 插件去重
- 插件启用 / 禁用
- 插件排序
- 插件更新
- 订阅保存 / 刷新
- 诊断信息持久化

相关文件：

- `lib/features/plugins/application/plugin_installation_coordinator.dart`
- `lib/features/plugins/application/plugin_manager_service.dart`
- `lib/features/plugins/infrastructure/plugin_file_repository.dart`
- `lib/features/plugins/infrastructure/plugin_meta_repository.dart`
- `lib/features/plugins/infrastructure/plugin_subscription_repository.dart`

### 2.3 插件运行时

已补到运行时的宿主能力：

- `URL`
- `URLSearchParams`
- `axios`
- `crypto-js`
- `cheerio`
- `dayjs`
- `big-integer`
- `qs`
- `he`
- `musicfree/storage`
- `@react-native-cookies/cookies`
- `webdav`

相关文件：

- `lib/core/runtime/plugin_runtime_host.dart`
- `lib/core/runtime/internal/plugin_runtime_shared_scope_builder.dart`
- `lib/core/runtime/internal/plugin_runtime_package_shims.dart`
- `lib/core/runtime/internal/plugin_runtime_host_bridges.dart`
- `lib/core/runtime/internal/plugin_runtime_state_bridge.dart`
- `lib/core/runtime/internal/plugin_runtime_webdav_bridge.dart`

### 2.4 已实现的插件方法

已实现并统一为 typed media model：

- `search`
- `getMediaSource`
- `getMusicInfo`
- `getLyric`
- `getAlbumInfo`
- `getMusicSheetInfo`
- `getArtistWorks`
- `importMusicItem`
- `importMusicSheet`
- `getTopLists`
- `getTopListDetail`
- `getRecommendSheetTags`
- `getRecommendSheetsByTag`
- `getMusicComments`

相关文件：

- `lib/features/plugins/application/plugin_method_service.dart`
- `lib/core/media/media_models.dart`
- `lib/core/media/media_utils.dart`

### 2.5 页面与布局

已改为接近原项目的简化布局：

- 顶部橙色头栏
- 左侧固定导航
- 右侧内容区
- 底部播放器壳

当前主要页面：

- 搜索页：`lib/features/search/presentation/pages/search_page.dart`
- 发现页：`lib/features/discover/presentation/pages/discover_page.dart`
- 插件页：`lib/features/plugins/presentation/pages/plugins_page.dart`
- 订阅页：`lib/features/plugins/presentation/pages/subscriptions_page.dart`
- 设置页：`lib/features/plugins/presentation/pages/settings_page.dart`
- 详情页：
  - `music_detail_page.dart`
  - `album_detail_page.dart`
  - `sheet_detail_page.dart`
  - `artist_detail_page.dart`
  - `toplist_detail_page.dart`

壳层与主题：

- `lib/shared/ui/app_shell.dart`
- `lib/app/theme/app_theme.dart`

## 3. 当前最核心的问题

### 3.1 插件状态正常，但无法稳定获取真实音乐内容

现状：

- 插件可以安装
- 插件可以解析
- 插件诊断页一般能看到正常 `platform/version/supportedMethods`
- 但很多插件在真正调用 `search / getTopListDetail / getMediaSource / getLyric` 时仍然失败

当前判断：

- 主要问题已不在“安装链路”
- 主要问题在“运行时宿主行为”与参考项目仍存在细节差异
- 即：
  - 某些依赖虽然已补，但返回值形状/默认导出/异常行为未完全对齐
  - 某些 HTTP/XHR 行为和原 Electron/Node 环境仍不一致
  - 某些插件对特定站点返回体结构高度敏感

### 3.2 实际遇到过的错误

已修过的：

- `ReferenceError: 'URL' is not defined`
- `TypeError: cannot read property 'get' of undefined`
  - 已按参考项目 `_require` 行为补 `default = pkg`
- `adad23u.appinstall.life` 这类插件 URL 404
  - 这是源站失效，不是本地逻辑问题

仍需继续排查的：

- `TypeError: cannot read property 'map' of undefined`
  - 已知出现在某些插件的 `getTopListDetail`
  - 当前已做两层处理：
    - 详情 provider 不再因为插件列表变化无关重拉
    - `getTopListDetail` 增加了更具体的错误信息

### 3.3 搜索网络层疑点

用户实际遇到过：

- `ClientException: Connection closed before full header was received`
- 发生位置：
  - `flutter_js/extensions/xhr.dart`
  - 某些站点，如 `https://ghyinyue.com/index/index/search`

这个问题目前尚未彻底解决，判断为：

- `flutter_js` 自带 XHR / fetch 的宿主 HTTP 行为与原项目存在差异
- 后续应优先对照原项目的网络访问策略，而不是继续补 UI

## 4. 当前代码上的关键判断

### 4.1 添加插件后发生了什么

添加插件只会做：

1. 解析订阅源
2. 下载插件脚本
3. `inspectPlugin`
4. 写入插件目录
5. 刷新插件列表

不会在安装阶段调用：

- `getTopListDetail`
- `getMediaSource`
- `getLyric`
- `getAlbumInfo`
- `getMusicComments`

所以如果安装后立刻报这些错误，通常是：

- 当前打开的页面在自动拉数据
- 或新增插件触发了页面 provider 重算

### 4.2 已经修过的“无关页面重拉”

`media_providers.dart` 之前直接依赖整个插件快照，新增插件后会导致当前详情页重拉。

现在已改成只依赖目标插件：

- `pluginByIdProvider`
- 各详情 provider 只读对应 `pluginId`

这部分已经收敛过一次。

## 5. 下一次会话建议的排查顺序

建议不要再优先改 UI，直接按真实插件验证驱动。

### 步骤 1：锁定一个真实插件

建议优先用这些源中的单个插件做最小复现：

- `https://gitee.com/maotoumao/MusicFreePlugins/raw/master/plugins.json`
- `https://musicfreepluginshub.2020818.xyz/plugins.json`
- `https://fastly.jsdelivr.net/gh/Huibq/keep-alive/Music_Free/myPlugins.json`

先避开已经明确 404 的 `adad23u.appinstall.life` 这一类链接。

### 步骤 2：优先验证这三个方法

按优先级：

1. `search`
2. `getTopListDetail`
3. `getMediaSource`

原因：

- 这是最容易稳定复现的问题链
- 也是从“能看到内容”到“能拿到音源”的关键路径

### 步骤 3：重点看两类不一致

下一次排查应优先比对：

- 参考项目里同一个插件在 Electron/Node 下的返回体
- Flutter 端当前宿主下的返回体

尤其关注：

- `axios` 返回结构
- XHR / fetch 行为
- headers / cookies / referer
- gzip / chunked / early close
- 站点对 UA / origin / cookie 的依赖

## 6. 不建议做的事

- 不要继续扩主题系统
- 不要改成新的播放器产品形态
- 不要把插件协议改成 Flutter 专用新协议
- 不要用“兜底成功”的方式掩盖真实请求失败

## 7. 当前验证命令

每次修改后至少执行：

```bash
flutter analyze
flutter test
```

工作目录：

```bash
D:\musicWEP\flutter_app
```

## 8. 推荐下一步任务标题

如果下一次会话继续接：

**任务标题建议：**

`对照参考项目，逐个修复真实音乐源插件的 search/getTopListDetail/getMediaSource 行为`

这样能直接延续当前最核心的问题，不会跑偏。
