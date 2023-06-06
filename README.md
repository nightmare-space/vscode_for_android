# Code FA

这是一个使用 code-server 实现的 VS Code 安卓版。这个方案也有些人实现了，这里也是提供其中一种。

体积会比较大，由于所需要的资源都是整个运行初始化需要的，所以将资源集成到服务器，再动态下载的意义不大。

所以大家综合权衡这种方案与其他开发者的方案。

原理是运行 code-server 再使用 webview 加载视图，会有一些bug，但已经能有一些可观的表现。

这个项目是开源的，上层框架是 Flutter，VS Code不是运行在 Flutter 中的，只有初始化的那个界面是。

工作比较忙，可能处理问题较慢，见谅。

Cheers! 🍻

## 一个坑
code-server github release 中发布的 arm 版本的压缩包中存在硬链接，这部分文件解压到安卓上会失败。
所以需要将下载的 gz 压缩包解压到电脑上，再压缩回去，带上 --hard-dereference 参数。

**macOS 需要安装 gnu-tar，不然在安卓上解压会各种报错**

brew install gnu-tar

### 解压
```
gtar -zxvf code-server-4.12.0-linux-arm64.tar.gz
```
### 打包

```sh
mv code-server-4.12.0-linux-arm64.tar.gz code-server-4.12.0-linux-arm64-old.tar.gz
gtar --hard-dereference -zcvhf code-server-4.12.0-linux-arm64.tar.gz code-server-4.12.0-linux-arm64
```

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://flutter.dev/docs/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://flutter.dev/docs/cookbook)

For help getting started with Flutter, view our
[online documentation](https://flutter.dev/docs), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
