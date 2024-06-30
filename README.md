# Code FA

Language: English | [中文简体](README-ZH.md)

This is an Android version of VS Code implemented using code-server. Some have already implemented similar solutions, and this is one of them.

The package size is relatively large since the resources required are necessary for the initial run, so integrating them into the server and dynamically downloading them is not very meaningful.

Users should weigh this solution against others available from different developers.

The principle is to run code-server and then use a webview to load the view. There might be some bugs, but it performs reasonably well.

This project is open source, with the upper framework being Flutter. The loading of VS Code is implemented in Flutter, and VS Code runs in the Android WebView.

I'm quite busy, so responses to issues might be slow. Thank you for your understanding.

Cheers! 🍻

## Features

- Fully local operation of Code Server
- Supports the latest version 4.13.0
- Supports quick updates to Code-Server versions
- Supports custom Code-Server versions
- Can run without an internet connection

## Getting Started

1. Download [code-server-4.13.0-linux-arm64.tar.gz](https://github.com/coder/code-server/releases/download/v4.13.0/code-server-4.13.0-linux-arm64.tar.gz)

2. Place the downloaded file in /sdcard. Do not unzip or change its filename.

3. Launch Code FA, and enjoy it!

## Changing Code-Server Version

1. Create a file named `code_version` in /sdcard with the version number as its content, such as `4.13.0`, without any line breaks.

2. Download the corresponding version and place it in /sdcard. Do not unzip or change its filename.

3. Launch Code FA, and enjoy it!

## Known Issues

- The built-in WebView does not handle the clipboard well: you can open 127.0.0.1:10000 in an external browser to bypass this issue.

TODO: Like Sula, slide the sidebar to directly input pasted text.

## Git History

[![Star History Chart](https://api.star-history.com/svg?repos=nightmare-space/vscode_for_android&type=Date)](https://star-history.com/#nightmare-space/vscode_for_android&Date)