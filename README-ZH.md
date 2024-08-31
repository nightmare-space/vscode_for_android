# Code FA

Language: 中文简体 | [English](README.md)

这是一个使用 code-server 实现的 VS Code 安卓版。这个方案也有些人实现了，这里也是提供其中一种。

体积会比较大，由于所需要的资源都是整个运行初始化需要的，所以将资源集成到服务器，再动态下载的意义不大。

所以大家综合权衡这种方案与其他开发者的方案。

原理是运行 code-server 再使用 webview 加载视图，会有一些bug，但已经能有一些可观的表现。

这个项目是开源的，上层框架是 Flutter，加载 VS Code 是在 Flutter 中实现，VS Code 运行在 Android WebView 中。

工作比较忙，可能处理问题较慢，见谅。

Cheers! 🍻

## 功能特性

- 完全本地运行的 Code Server
- 支持最新4.13.0版本
- 支持快速升级 Code-Server 版本
- 支持自定义 Code-Server 版本
- 支持无网络环境下运行

## 开始使用

1.下载 [code-server-4.13.0-linux-arm64.tar.gz](https://github.com/coder/code-server/releases/download/v4.13.0/code-server-4.13.0-linux-arm64.tar.gz)

2.将下载的文件放到 /sdcard，注意不用解压，不要更改他的文件名

3.启动 Code FA，Engoy it!

## 更改 Code-Server 版本

1.在 /sdcard 中创建一个名为 `code_version` 的文件，文件内容为版本号，例如 `4.13.0`,不要有换行

2.下载对应的版本，放到 /sdcard 中，注意不用解压，不要更改它的文件名

3.启动 Code FA，Engoy it!

## 已知问题

- 内置 WebView 对剪切板的适配不友好：可通过外部浏览器打开 127.0.0.1:20000 来绕过这个问题

TODO: 像sula一样，侧边滑动直接输入粘贴文本

## Git History

[![Star History Chart](https://api.star-history.com/svg?repos=nightmare-space/adb_kit&type=Date)](https://star-history.com/#nightmare-space/adb_kit&Date)