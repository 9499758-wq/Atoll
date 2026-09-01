<div align="center">

<p align="center">
  <img src=".github/assets/atoll-logo.png" alt="Atoll logo" width="120">
</p>

# 🏝️ Atoll - 专为 macOS 打造的原生刘海灵动岛 (二次开发版)
### *Dynamic Island for macOS — Enhanced Fork & Customization*

**基于开源项目 [Ebullioscopic/Atoll](https://github.com/Ebullioscopic/Atoll) 进行深度二次开发与定制增强**

[![Platform](https://img.shields.io/badge/Platform-macOS%2014.0%2B-black?style=flat-square&logo=apple)](https://github.com/9499758-wq/Atoll)
[![Language](https://img.shields.io/badge/Swift-5.9%2B-F05138?style=flat-square&logo=swift)](https://github.com/9499758-wq/Atoll)
[![UI Framework](https://img.shields.io/badge/UI-SwiftUI-007ACC?style=flat-square)](https://github.com/9499758-wq/Atoll)
[![License](https://img.shields.io/badge/License-GPL--3.0-green.svg?style=flat-square)](LICENSE)

**简体中文说明** · [English Docs](README_EN.md) · [报告问题](https://github.com/9499758-wq/Atoll/issues) · [贡献代码](https://github.com/9499758-wq/Atoll/pulls)

<p align="center">
  <img src="https://i.postimg.cc/t49mW5yN/Screenshot-2026-03-02-at-6-00-22-PM.png" alt="Atoll 锁屏与灵动岛展示" width="900">
</p>

</div>

---

## 🙏 开源致敬与二次开发说明

本项目基于原作者 **[Ebullioscopic/Atoll](https://github.com/Ebullioscopic/Atoll)** 的优秀开源成果进行深度二次开发与定制增强。在此由衷致敬并感谢原作者团队在 macOS 灵动岛领域做出的杰出贡献！

### 🌟 本次二次开发增强特色：
1. **天气预报动效序列优化**：重构并增强了全套 FluentAnim 动效帧序列（含雪花、暴雨、云层、多云太阳等流畅粒子级动效）；
2. **自动化构建与部署工具**：新增 `deploy-atoll.sh` 及 AppleScript 自动化本地构建、编译与部署流水线；
3. **跨进程桥接集成**：新增 `AtollBridge`（Python & Swift 跨进程桥接组件），支持外部工具链无感控制灵动岛状态；
4. **全套简体中文文档与本地化支持**。

---

## 📖 项目简介

**Atoll** 是一款专为搭载刘海屏的 MacBook（以及普通外接显示器）设计的原生 macOS 灵动岛交互工具。

它在平时隐匿于顶部刘海之中，不打扰日常工作；当有媒体播放、定时器运行、充电或硬件状态变动时，它会以丝滑流畅的 **原生 SwiftUI + Metal 动效** 优雅展开，为你提供极致的视效与操作便捷度。

---

## 🌟 核心功能特性

### 1. 🎵 媒体控制与桌面歌词
* **全平台音乐适配**：深度支持 Apple Music、Spotify、QQ音乐、网易云音乐等主流播放器；
* **实时歌词与音频动效**：内置 Metal 硬件加速音频可视化频谱，支持悬浮歌词与专辑封面预览；
* **快捷手势控制**：鼠标悬停展开播放面板，轻扫快速切歌、调整音量。

### 2. ⚡ 灵动岛实时活动 (Live Activities)
* **动态状态流转**：实时显示媒体播放、专注模式、屏幕录制、下载进度及充电动画；
* **隐私安全指示器**：麦克风、摄像头调用时即时在灵动岛给出醒目视觉反馈。

### 3. 🔒 锁屏小组件 (Lock Screen Widgets)
* 在 macOS 锁屏界面提供专属扩展小组件：
  * 正在播放的音乐与歌词进度；
  * 蓝牙外设（AirPods / 鼠标 / 键盘）实时电量监控；
  * 天气预报动效与温湿度详情；
  * 倒计时与番茄钟提醒。

### 4. 📊 极简系统性能监视器 (System Insights)
* **轻量级硬件监控**：低开销实时监测 CPU 占用、GPU 负载、内存压力、网络上传/下载速率与磁盘余量。

### 5. 🛠️ 实用生产力工具箱 (Productivity Tools)
* **番茄钟与定时器**：一键开启专注计时，倒计时结束伴随优雅提示音；
* **剪贴板历史记录**：快速检索最近复制的文本与代码片段；
* **屏幕取色器**：快速拾取屏幕像素颜色并转换为 HEX / RGB 格式；
* **日历与日程预览**：快捷查看近期日程安排。

---

## 🚀 安装与运行

### 方式 1：使用一键自动化部署脚本（推荐）
```bash
git clone https://github.com/9499758-wq/Atoll.git
cd Atoll
./deploy-atoll.sh
```

### 方式 2：使用 Xcode 编译源码
```bash
open DynamicIsland.xcodeproj
```

---

## 📄 开源许可证与致谢

本项目基于原作者项目并遵循 [GPL-3.0 License](LICENSE) 开源协议。
