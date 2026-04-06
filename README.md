# MusicWEP - MusicFree flutter 重制版
![MusicFree](https://github.com/maotoumao/MusicFreeDesktop) 

---

## 项目使用约定：
本项目基于 AGPL 3.0 协议开源，使用此项目时请遵守开源协议。  
除此外，希望你在使用代码时已经了解以下额外说明：

1. 打包、二次分发 **请保留代码出处**：上游项目：https://github.com/maotoumao/MusicFree  本项目：https://github.com/WEP-56/MusicWEP
2. 请不要用于商业用途，合法合规使用代码；
3. 如果开源协议变更，将在此 Github 仓库更新，不另行通知。
---

## 简介

一个插件化、定制化、无广告的免费音乐播放器。
> 此重置版本将支持 Windows 、 macOS 、 Linux 、 Android 、iPhone等



### 下载地址


## 特性

- 插件化：本软件仅仅是一个播放器，本身**并不集成**任何平台的任何音源，所有的搜索、播放、歌单导入等功能全部基于**插件**。这也就意味着，**只要可以在互联网上搜索到的音源，只要有对应的插件，你都可以使用本软件进行搜索、播放等功能。** 关于插件的详细说明请参考 [安卓版 Readme 的插件部分](https://github.com/maotoumao/MusicFree#%E6%8F%92%E4%BB%B6)。

- 插件支持的功能：搜索（音乐、专辑、作者、歌单）、播放、查看专辑、查看作者详细信息、导入单曲、导入歌单、获取歌词等。

- 定制化：本软件可以通过主题包定义软件外观及背景，详见下方主题包一节。

- 无广告：基于 AGPL3.0 协议开源，将会保持免费。

- 隐私：软件所有数据存储在本地，本软件不会上传你的个人信息。

## 插件

插件协议和原版完全相同。

[示例插件仓库](https://github.com/maotoumao/MusicFreePlugins)，你可以根据[插件开发文档](https://musicfree.catcat.work/plugin/introduction.html) 开发适配于任意音源的插件。



## 启动项目

下载仓库代码之后，在根目录下执行：

```bash
cd flutter_app
flutter run
```

