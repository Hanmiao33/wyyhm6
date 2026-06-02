# 网易云音乐播放器 - HarmonyOS

一个基于 HarmonyOS 开发的网易云音乐在线播放器，支持在线搜索、播放、歌词显示等功能。

## 功能特性

- 🔍 音乐搜索：支持歌曲、歌手、专辑搜索
- 🎵 在线播放：支持在线播放网易云音乐
- 📝 歌词显示：实时滚动歌词显示
- 🎛️ 播放控制：播放/暂停、上一首/下一首、进度拖拽
- 🔀 播放模式：顺序播放、列表循环、随机播放、单曲循环
- 💾 播放列表：支持播放列表管理

## 项目结构

```
entry/src/main/ets/
├── models/              # 数据模型
│   └── MusicModel.ets   # 音乐相关数据结构
├── services/            # 服务层
│   ├── ApiService.ets   # API服务（网易云音乐接口）
│   └── PlayerService.ets # 播放器服务
├── components/          # UI组件
│   ├── PlayerControls.ets # 播放控制组件
│   ├── SongItem.ets     # 歌曲列表项
│   └── LyricView.ets    # 歌词显示组件
├── pages/               # 页面
│   ├── Index.ets        # 首页（热门推荐）
│   ├── SearchPage.ets   # 搜索页面
│   └── PlayPage.ets     # 播放页面
└── utils/               # 工具类
    ├── TimeUtils.ets    # 时间格式化
    └── ToastUtils.ets   # 提示工具
```

## 技术栈

- HarmonyOS ArkTS
- @ohos.net.http - 网络请求
- @ohos.multimedia.media - 音频播放
- 网易云音乐第三方API

## 使用说明

1. 使用 DevEco Studio 打开项目
2. 连接 HarmonyOS 设备或启动模拟器
3. 点击运行按钮启动应用

## API 说明

本项目使用第三方网易云音乐API接口：
- 搜索接口：`https://api.lolimi.cn/api/netease/search`
- 播放链接：`https://api.lolimi.cn/api/netease/url`
- 歌词接口：`https://api.lolimi.cn/api/netease/lyric`
- 歌曲详情：`https://api.lolimi.cn/api/netease/detail`

## 注意事项

- 需要网络权限才能正常使用
- API 接口可能有访问限制
- 建议在真机上测试音频播放功能

## 开发者

- 项目创建时间：2026-05-27
- 基于 HarmonyOS 6.0 开发
