# Code FA

Language: English | [中文简体](README-ZH.md)

This is an Android version of VS Code implemented using code-cli. Some have already implemented similar solutions, and this is one of them.

The package size is relatively large since the resources required are necessary for the initial run, so integrating them into the server and dynamically downloading them is not very meaningful.

Users should weigh this solution against others available from different developers.

The principle is to run visual Studio code Cli and then use a webview to load the view. There might be some bugs, but it performs reasonably well.

This project is open source, with the upper framework being Flutter. The loading of VS Code is implemented in Flutter, and VS Code runs in the Android WebView.

I'm quite busy, so responses to issues might be slow. Thank you for your understanding.

Cheers! 🍻

## Features

- Fully local operation of VSCode Server
- Supports quick updates to Code-Server versions
- Currently not supported in a no-network environment (an update request will be sent prior to startup)

## Getting Started

1. Launch Code FA, and enjoy it!


## Known Issues

- The built-in WebView does not handle the clipboard well: you can open 127.0.0.1:8000 in an external browser to bypass this issue.

TODO: Like Sula, slide the sidebar to directly input pasted text.

## Git History

[![Star History Chart](https://api.star-history.com/svg?repos=nightmare-space/vscode_for_android&type=Date)](https://star-history.com/#nightmare-space/vscode_for_android&Date)