// code-server版本号
import 'package:global_repository/global_repository.dart';

import 'config.dart';

String version = '';
// prootDistro 路径
String prootDistroPath = '${RuntimeEnvir.usrPath}/var/lib/proot-distro';
// ubuntu 路径
String ubuntuPath = '$prootDistroPath/installed-rootfs/ubuntu';
String lockFile = '${RuntimeEnvir.dataPath}/cache/init_lock';
// 清华源
String source = '''
# 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释
deb [trusted=yes] http://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ jammy main restricted universe multiverse
# deb-src http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy main restricted universe multiverse
deb [trusted=yes] http://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ jammy-updates main restricted universe multiverse
# deb-src http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-updates main restricted universe multiverse
deb [trusted=yes] http://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ jammy-backports main restricted universe multiverse
# deb-src http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-backports main restricted universe multiverse
deb [trusted=yes] http://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ jammy-security main restricted universe multiverse
# deb-src http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-security main restricted universe multiverse
 
# 预发布软件源，不建议启用
# deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-proposed main restricted universe multiverse
# deb-src http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-proposed main restricted universe multiverse
''';

String colorEcho = '''
colorEcho(){
  echo -e "\\033[31m\$@\\033[0m"
}
''';

/// 安装ubuntu的shell
/// todo 内置proot，然后用dpkg安装
String installUbuntu = '''
install_ubuntu(){
  cd ~
  colorEcho - 安装Ubuntu Linux
  cd ~/proot-distro-master
  bash ./install.sh
  apt-get install -y proot >/dev/null
  old=`cat $ubuntuPath/etc/issue 2>/dev/null`
  #echo \$old
  strB="21.04"
  result=\$(echo \$old | grep "\${strB}")
  if [ "\$result" != "" ]; then
    echo "升级ubuntu中"
    mv -f $ubuntuPath/home ./
    rm -rf $ubuntuPath
  fi
  proot-distro install ubuntu >/dev/null 2>&1
  mv -f ./home $ubuntuPath/ >/dev/null 2>&1
  echo '$source' > $ubuntuPath/etc/apt/sources.list
  echo 'export PATH=/opt/code-server-$version-linux-arm64/bin:\$PATH' >> $ubuntuPath/root/.bashrc
  echo 'export ANDROID_DATA=/home/' >> $ubuntuPath/root/.bashrc
}
''';

/// 安装code-server的脚本
String installVsCodeScript = '''
$colorEcho
install_vs_code(){
  if [ ! -d "$ubuntuPath/home/code-server-$version-linux-arm64" ];then
    cd $ubuntuPath/home
    server_path="/sdcard/code-server-$version-linux-arm64.tar.gz"
    if [ ! -f "\$server_path" ];then
      echo "没有发现外置包，请到http://nightmare.press:5244/AliYun下载外置包"
    else
      colorEcho - 解压 Vs Code Arm64
      tar zxvfh \$server_path > /dev/null
      cd code-server-$version-linux-arm64
    fi
  fi
}
''';

/// TODO 加上端口的kill
/// 启动 vs code 的shell
String startVsCodeScript = '''
$installUbuntu
$installVsCodeScript
start_vs_code(){
  install_ubuntu
  #install_vs_code
  mkdir -p $ubuntuPath/root/.config/code-server 2>/dev/null
  echo '$source' > $ubuntuPath/etc/apt/sources.list
  echo '
  bind-addr: 0.0.0.0:${Config.port}
  auth: none
  password: none
  cert: false
  ' > $ubuntuPath/root/.config/code-server/config.yaml
  # 可能切换了版本，对应的code server被解压到app的home了
  CODE_PATH=$ubuntuPath/opt/code-server-$version-linux-arm64
  mv ${RuntimeEnvir.homePath}/code-server-$version-linux-arm64 $ubuntuPath/opt/ 2>/dev/null
  chmod +x \$CODE_PATH/bin/code-server
  chmod +x \$CODE_PATH/lib/node
  chmod +x \$CODE_PATH/lib/vscode/node_modules/@vscode/ripgrep/bin/rg
  echo -e "\\033[31m- 启动中..\\033[0m"
  proot-distro  login --bind /sdcard:/sd --bind /storage/emulated/0:/storage/emulated/0/ ubuntu  -- /opt/code-server-$version-linux-arm64/bin/code-server
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
    filename=\$(basename "\${arr[0]}")
    echo -n -e "\x1b[2K\r- \$filename"
    ln -s \${arr[0]} \${arr[3]}
  done
  echo
  rm -rf SYMLINKS.txt
  TMPDIR=${RuntimeEnvir.tmpPath}
  filename=bootstrap
  rm -rf "\$TMPDIR/\$filename*"
  rm -rf "\$TMPDIR/*"
  chmod -R 0777 ${RuntimeEnvir.binPath}/*
  chmod -R 0777 ${RuntimeEnvir.usrPath}/lib/* 2>/dev/null
  chmod -R 0777 ${RuntimeEnvir.usrPath}/libexec/* 2>/dev/null
  rm -rf $lockFile
  export LD_PRELOAD=${RuntimeEnvir.usrPath}/lib/libtermux-exec.so
  install_ubuntu
  start_vs_code
  bash
}
''';
