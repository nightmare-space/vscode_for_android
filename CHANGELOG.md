## 1.5.0
很抱歉，所有还在用 Code FA 的用户，这个项目的维护并不积极，Code LFA 免费且开源，所有的投入都是我无偿奉献出我的时间，而且我很难从这一切中找到平衡，后续也会面临经济上的一些问题

简单了解过我的朋友可能知道，我手上的项目非常的多，也非常的忙

项目更名为 code_lfa

Code LFA(Code Launcher For Android)

如名称所示，这只是一个启动器，并不是自己实现的 VS Code，在过去，它经常会带来一些歧义，更有甚者会有人辱骂我违反了开源协议

我并未使用任何 code-server 的代码，code-server 也是以压缩包的方式存在 Code LFA 中，更何况 Code LFA 本身也是开源的

同时更新了 Readme，部分朋友总是觉得安装依赖是 Code FA 的问题，所以我加了一些说明

其实绝大部分的问题，都是大家完全不会使用 Ubuntu 导致的，也不会使用 apt

### 更新日志
**1.移除 termux 环境**

在以往的版本中，Code LFA 其实包含了一个完整的 termux 环境，简单说是，里面内置了一个和 termux 一模一样的类 Linux 环境，而这都是需要修改包名，重新编译 termux-package 的 bootstrap，这个过程非常复杂，而我精力分散后，这部分几乎无法维护，并且会增加 26M 的 apk 体积

这部分去除后，原有的包体积增加只需要 1.6M

相关依赖来源
- bash: proot-distro 语法依赖
- busybox: proot-distro 需要依赖很多安卓本身没有的命令
- proot、libtalloc、loader: 这个仍然需要自编译 termux-package，但是好在动态链接很少，不需要经常更新

我也思考过，移除 bash 和 proot-distro，但其实 proot-distro 帮我们处理了很多事情，如果最后仅精简成一行 proot 命令的话，可能启动的 ubuntu 会有一些问题

**2.升级 Target SDK 到35**

为后续上架 Google Play 做准备

**3.升级默认 code-server 到 4.96.2**

目前有开发者为 Code LFA 提交了一个 PR 以实现工作流产出 Apk，但我当前没有精力测试

**4.优化启动界面 UI**

一个遗留了很久的问题，目前我尽可能让它看起来美观一点，并加了玄学的进度条

也许大家启动失败的时候，我可以根据进度条的位置和终端输出来判断问题

**5.移除 Tar 依赖**

在最早的版本中，Code LFA 是无法使用直接从 code-server 下载的 .gz 包的，需要先解压，再压缩，因为压缩包中有一些 hardlink，在安卓上不支持

后来改用了 Dart Tar 来处理

现在移除了这部分，尽可能减少 Code LFA 的代码和依赖

直接用 busybox tar 来解压，然后 hardlink 目前是针对这个 code-server 版本写死的，后续可能会解析 tar tvf 的结果，再动态拷贝硬链接的文件，

```bash
tar tvf 'assets/code-server-4.96.2-linux-arm64.tar.gz' | grep '^hr' tar.txt

hrwxr-xr-x  0 root   root        0 Dec 21 05:39 code-server-4.96.2-linux-arm64/node_modules/argon2/build-tmp-napi-v3/Release/obj.target/argon2.node link to code-server-4.96.2-linux-arm64/node_modules/argon2/build-tmp-napi-v3/Release/argon2.node
hrw-r--r--  0 root   root        0 Dec 21 05:39 code-server-4.96.2-linux-arm64/node_modules/argon2/build-tmp-napi-v3/Release/obj.target/argon2.a link to code-server-4.96.2-linux-arm64/node_modules/argon2/build-tmp-napi-v3/Release/argon2.a
hrwxr-xr-x  0 root   root        0 Dec 21 05:39 code-server-4.96.2-linux-arm64/node_modules/argon2/lib/binding/napi-v3/argon2.node link to code-server-4.96.2-linux-arm64/node_modules/argon2/build-tmp-napi-v3/Release/argon2.node
hrwxr-xr-x  0 root   root        0 Dec 21 05:39 code-server-4.96.2-linux-arm64/lib/vscode/node_modules/@parcel/watcher/build/Release/watcher.node link to code-server-4.96.2-linux-arm64/lib/vscode/node_modules/@parcel/watcher/build/Release/obj.target/watcher.node
hrw-r--r--  0 root   root        0 Dec 21 05:39 code-server-4.96.2-linux-arm64/lib/vscode/node_modules/@parcel/watcher/build/node-addon-api/nothing.a link to code-server-4.96.2-linux-arm64/lib/vscode/node_modules/@parcel/watcher/build/Release/nothing.a
hrwxr-xr-x  0 root   root        0 Dec 21 05:39 code-server-4.96.2-linux-arm64/lib/vscode/node_modules/kerberos/build/Release/obj.target/kerberos.node link to code-server-4.96.2-linux-arm64/lib/vscode/node_modules/kerberos/build/Release/kerberos.node
hrwxr-xr-x  0 root   root        0 Dec 21 05:39 code-server-4.96.2-linux-arm64/lib/vscode/node_modules/native-watchdog/build/Release/obj.target/watchdog.node link to code-server-4.96.2-linux-arm64/lib/vscode/node_modules/native-watchdog/build/Release/watchdog.node
hrwxr-xr-x  0 root   root        0 Dec 21 05:39 code-server-4.96.2-linux-arm64/lib/vscode/node_modules/@vscode/windows-registry/build/Release/winregistry.node link to code-server-4.96.2-linux-arm64/lib/vscode/node_modules/@vscode/windows-registry/build/Release/obj.target/winregistry.node
hrwxr-xr-x  0 root   root        0 Dec 21 05:39 code-server-4.96.2-linux-arm64/lib/vscode/node_modules/@vscode/windows-process-tree/build/Release/obj.target/windows_process_tree.node link to code-server-4.96.2-linux-arm64/lib/vscode/node_modules/@vscode/windows-process-tree/build/Release/windows_process_tree.node
hrwxr-xr-x  0 root   root        0 Dec 21 05:39 code-server-4.96.2-linux-arm64/lib/vscode/node_modules/@vscode/spdlog/build/Release/obj.target/spdlog.node link to code-server-4.96.2-linux-arm64/lib/vscode/node_modules/@vscode/spdlog/build/Release/spdlog.node
hrwxr-xr-x  0 root   root        0 Dec 21 05:39 code-server-4.96.2-linux-arm64/lib/vscode/node_modules/@vscode/deviceid/build/Release/obj.target/windows.node link to code-server-4.96.2-linux-arm64/lib/vscode/node_modules/@vscode/deviceid/build/Release/windows.node
```

### 其他更新
- 多 Activty 切换成 Fragment，这个还没确定会保留，目前是为了兼容 AR 眼镜
- 升级 Ubuntu 到 24.04
- 代码精简，优化


##  TODO 中英文


## 1.4.0
- 支持剪切板啦
- 升级自带 code-server 到 4.95.2

## 1.3.0
- 支持剪切板啦
- 升级自带 code-server 到 4.90.3

## 1.2.1
- 采取大家的建议，将新版的 code-server 内置到 apk 中，不再需要下载，开箱即用
- 加了一些启动日志，在卡住不动的时候，方便排查问题
- 修复了其他的一些小问题

如果还有白屏的情况，更多可能是因为系统自带 WebView 版本不够导致的，尝试用 GooglePlay 升级 WebView 试试
或者用其他浏览器打开 http://127.0.0.1:10000

友善反馈是解决一切问题的必要条件


## 1.2.0
- 支持 code-server-v4.13.0

- 去除开屏广告，起初我加上这个就是为了挣钱，来平衡我对软件付出的时间，最后发现用户量很少，目前这样的广告没收益，这很现实，想挣钱，也很现实，拉黑也是任何人都有的权利。

- 解决之前 tar 符号链接的问题，之前版本需要重新解压再打包 tar，所以大家只能下我给的tar去使用，现在可以直接支持从 code-server 下载的arm64压缩包

- 支持完全离线模式，之前会请求一部分服务，导致首次始终是需要联网的，现在不需要了。
- 简化启动时的终端输出

迁移服务器的时候 terminal 的源不小心被删了，重新编译了一下，这些都是需要花的时间成本，包括服务器，开发成本，大家如果觉得有帮助，只需要给这个项目点一个star，就是最大的支持，万分感谢。

https://github.com/nightmare-space/vscode_for_android

## 1.1.9
- 不再会往root/home写入收款二维码
- 更改多版本加载策略
- 加入开屏广告(介意慎更)

## 1.1.8
- 限制Android版本

## 1.1.7
- 增加了一件简陋的版本选择页面，现在只需要把对应的版本放在 /Sdcard 下然后输入版本号即可加载对应的 Code Server
Code Server 下载地址 http://nightmare.press:5244/AliYun

## 1.1.6
- ubuntu 版本升级到 22.04，并切换至相应的源
- 此版本会覆盖升级 ubuntu 版本，会自动备份 home 文件夹
- 精简控制台输出
- 修复 g++ 不能使用的问题
- 修复中文插件不能使用的问题

注意！！！目前 oss 不能上传文件，需要去 QQ 群961959652下载
Code Server zip包放到外置储存

## 1.1.5
- 修复 apt update 失败的问题ß

## 1.1.4
- 更新Code Server核心至4.5.0
- 补充隐私政策

## 1.1.3
- 支持屏幕旋转

## 1.1.2
- 支持自动下载 code-server

## 1.1.1
- 修复Code FA屏幕旋转不跟随系统的问题

## 1.1.0

- 增加进入VS Code页面的按钮
- code-server核心升级至v4.4.0
注意！！！
为了后续版本升级，从这个版本开始，code-server不再集成到apk内部
需要下载code-server到外置储存
链接如下（code-serer github release下载的不行）
https://nightmare-my.oss-cn-beijing.aliyuncs.com/code-server-4.4.0-linux-arm64.tar.gz


## 1.0.0
- 第一个版本
