
// code-server版本号
import 'package:global_repository/global_repository.dart';

import 'config.dart';

String version = '4.4.0';
// prootDistro 路径
String prootDistroPath = '${RuntimeEnvir.usrPath}/var/lib/proot-distro';
// ubuntu 路径
String ubuntuPath = '$prootDistroPath/installed-rootfs/ubuntu';
String lockFile = RuntimeEnvir.dataPath + '/cache/init_lock';
// 清华源
String source = '''
deb [trusted=yes] http://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ hirsute main universe multiverse
deb [trusted=yes] http://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ hirsute-updates main universe multiverse
deb [trusted=yes] http://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ hirsute-security main universe multiverse
''';

String colorEcho = '''
colorEcho(){
  echo -e "\\033[31m\$@\\033[0m"
}
''';

// String installVsCodeScriptWithoutFullLinux = '''
// $colorEcho
// install_vs_code(){
//   colorEcho - 安装依赖
//   apt-get install -y libllvm
//   apt-get install -y clang
//   apt-get install -y nodejs
//   apt-get install -y python
//   apt-get install -y yarn
//   colorEcho - 解压 Vs Code Arm64
//   cd ~
//   unzip code-server-3.11.1-linux-arm64.zip
//   colorEcho - 执行 yarn install
//   cd code-server-3.11.1-linux-arm64
//   yarn config set registry https://registry.npm.taobao.org --global
//   yarn config set disturl https://npm.taobao.org/dist --global
//   npm config set registry https://registry.npm.taobao.org
//   yarn install
// }
// ''';
/// 安装ubuntu的shell
String installUbuntu = '''
install_ubuntu(){
  cd ~
  colorEcho - 安装Ubuntu Linux
  unzip proot-distro.zip >/dev/null
  #cd ~/proot-distro
  bash ./install.sh
  apt-get install -y proot
  proot-distro install ubuntu
  echo '$source' > $ubuntuPath/etc/apt/sources.list
  echo 'export PATH=/home/code-server-$version-linux-arm64/bin:\$PATH' >> $ubuntuPath/root/.bashrc
}
''';

/// 安装code-server的脚本
String installVsCodeScript = '''
$colorEcho
install_vs_code(){
  if [ ! -d "$ubuntuPath/home/code-server-$version-linux-arm64" ];then
    cd $ubuntuPath/home
    server_path="/sdcard/code-server-$version-linux-arm64.tar.gz"
    if [ ! -d "\$server_path" ];then
      dart_dio \\
      https://nightmare-my.oss-cn-beijing.aliyuncs.com/code-server-4.4.0-linux-arm64.tar.gz \\
      /sdcard/code-server-4.4.0-linux-arm64.tar.gz
    fi
    colorEcho - 解压 Vs Code Arm64
    tar zxvfh \$server_path
    cd code-server-$version-linux-arm64
  fi
}
''';

// TODO 加上端口的kill
/// 启动 vs code 的shell
String startVsCodeScript = '''
$installVsCodeScript
start_vs_code(){
  install_vs_code
  mkdir -p $ubuntuPath/root/.config/code-server 2>/dev/null
  echo '
  bind-addr: 0.0.0.0:10000
  auth: none
  password: none
  cert: false
  ' > $ubuntuPath/root/.config/code-server/config.yaml
  echo -e "\\033[31m- 启动中..\\033[0m"
  proot-distro login ubuntu -- /home/code-server-$version-linux-arm64/bin/code-server
}
''';

String getRedLog(String data) {
  return '\x1b[31m$data\x1b[0m';
}

/// 初始化类Linux环境的shell
String initShell = '''
$installUbuntu
$startVsCodeScript
function initApp(){
  cd ${RuntimeEnvir.usrPath}/
  colorEcho - 准备符号链接...
  for line in `cat SYMLINKS.txt`
  do
    OLD_IFS="\$IFS"
    IFS="←"
    arr=(\$line)
    IFS="\$OLD_IFS"
    ln -s \${arr[0]} \${arr[3]}
  done
  rm -rf SYMLINKS.txt
  TMPDIR=${RuntimeEnvir.tmpPath}
  filename=bootstrap
  rm -rf "\$TMPDIR/\$filename*"
  rm -rf "\$TMPDIR/*"
  chmod -R 0777 ${RuntimeEnvir.binPath}/*
  chmod -R 0777 ${RuntimeEnvir.usrPath}/lib/* 2>/dev/null
  chmod -R 0777 ${RuntimeEnvir.usrPath}/libexec/* 2>/dev/null
  apt update
  rm -rf $lockFile
  export LD_PRELOAD=${RuntimeEnvir.usrPath}/lib/libtermux-exec.so
  install_ubuntu
  start_vs_code
  bash
}
''';