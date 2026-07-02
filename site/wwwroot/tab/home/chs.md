---
title: One More Cap
excerpt: 一个 macOS 菜单栏 app，用来把外部字幕文件叠加到 QuickTime Player 上方。
---

One More Cap 是一个原生 macOS 菜单栏 app，适合这种简单场景：你正在播放一部电影，手上有一个外部字幕文件，然后想在画面上方多叠一层字幕。

它可以打开 SRT 和 WebVTT 字幕文件，把字幕显示在浮动 overlay 里，并在你点击 Sync 时读取 QuickTime Player 的当前播放时间来校准字幕。字幕文件只保留在你的 Mac 上。

## 它能做什么

- 打开 `.srt`、`.vtt` 和 `.webvtt` 字幕文件。
- 在播放器上方显示浮动字幕层。
- 点击 Sync 时读取 QuickTime Player 的当前播放时间。
- 在悬浮工具栏里调整字幕 offset 和字幕宽度。
- 尽量沿用 macOS 的字幕外观设置。

## 版本差异

App Store 版本只支持 QuickTime，同步功能不包含 Sparkle 更新，也不包含 Apple TV Accessibility sync。

GitHub 版本可以额外包含 Sparkle 更新和通过 Accessibility 实现的 Apple TV sync。

## 链接

- [隐私政策](?tab=privacy&lang=chs)
- [支持](?tab=support&lang=chs)
- [GitHub Releases](https://github.com/deemoe404/onemorecap/releases/latest)
