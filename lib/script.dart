// code-server版本号
import 'package:global_repository/global_repository.dart';

import 'config.dart';

String version = '';
// proot distro 路径
String prootDistroPath = '${RuntimeEnvir.usrPath}/var/lib/proot-distro';
// ubuntu 路径
String ubuntuPath = '$prootDistroPath/installed-rootfs/ubuntu';

String function = '''
export UBUNTU_PATH=$ubuntuPath
export CSPORT=${Config.port}
export CSVERSION=${Config.defaultCodeServerVersion}
export TMPDIR=${RuntimeEnvir.tmpPath}
export BIN=${RuntimeEnvir.binPath}

progress_echo(){
  echo -e "\\033[31m\$@\\033[0m"
}
''';

/// 安装ubuntu的shell
String functions = r'''
change_ubuntu_source(){
  cat <<EOF > $UBUNTU_PATH/etc/apt/sources.list
deb [trusted=yes] http://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ jammy-backports main restricted universe multiverse
# deb-src http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-backports main restricted universe multiverse
deb [trusted=yes] http://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ jammy-security main restricted universe multiverse
# deb-src http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-security main restricted universe multiverse

# 预发布软件源，不建议启用
# deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-proposed main restricted universe multiverse
# deb-src http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-proposed main restricted universe multiverse
EOF
}
gen_code_server_config(){
  mkdir -p $UBUNTU_PATH/root/.config/code-server 2>/dev/null
  echo "
  bind-addr: 0.0.0.0:$CSPORT
  auth: none
  password: none
  cert: false
  " > $UBUNTU_PATH/root/.config/code-server/config.yaml
}

remove_old_ubuntu(){
  progress_echo "- 移除旧版Ubuntu"
}

install_proot_distro(){
  proot_distro_path=`which proot-distro`
  if [ -z "$proot_distro_path" ]; then
    progress_echo "- proot-distro 未安装, 安装中..."
    cd ~
    busybox unzip proot-distro.zip -d proot-distro
    cd ~/proot-distro
    bash ./install.sh
  else
    progress_echo "- proot-distro 已安装"
  fi
}

install_ubuntu(){
  mkdir -p $UBUNTU_PATH 2>/dev/null
  if [ -z "$(ls -A $UBUNTU_PATH)" ]; then
    progress_echo "- Ubuntu 未安装, 安装中..."
    busybox tar xvf ~/ubuntu-noble-aarch64-pd-v4.11.0.tar.xz -C $UBUNTU_PATH/ | while read line; do
      # echo -ne "\033[2K\0337\r$line\0338"
      echo $line
    done
    mv $UBUNTU_PATH/ubuntu-noble-aarch64/* $UBUNTU_PATH/
    rm -rf $UBUNTU_PATH/ubuntu-noble-aarch64
  else
    VERSION=`cat $UBUNTU_PATH/etc/issue.net 2>/dev/null`
    # VERSION=`cat $UBUNTU_PATH/etc/issue 2>/dev/null | sed 's/\\n//g' | sed 's/\\l//g'`
    progress_echo "- Ubuntu 已安装 -> $VERSION"
  fi
  change_ubuntu_source
  # TODO 下面代码不能被反复执行
  echo 'export PATH=/opt/code-server-$version-linux-arm64/bin:\$PATH' >> $UBUNTU_PATH/root/.bashrc
  echo 'export ANDROID_DATA=/home/' >> $UBUNTU_PATH/root/.bashrc
}


install_vs_code_old(){
  if [ ! -d "$UBUNTU_PATH/home/code-server-$CSVERSION-linux-arm64" ];then
    cd $ubuntuPath/home
    server_path="/sdcard/code-server-$CSVERSION-linux-arm64.tar.gz"
    if [ ! -f "\$server_path" ];then
      echo "没有发现外置包,请下载外置包"
    else
      progress_echo - 解压 Vs Code Arm64
      tar zxfh \$server_path > /dev/null
      cd code-server-$version-linux-arm64
    fi
  fi
}

fix_code_server_hard_link(){
  cd $UBUNTU_PATH/opt/code-server-$CSVERSION-linux-arm64/
  ls node_modules/argon2/build-tmp-napi-v3/Release
  cp node_modules/argon2/build-tmp-napi-v3/Release/argon2.node node_modules/argon2/build-tmp-napi-v3/Release/obj.target/argon2.node
  cp node_modules/argon2/build-tmp-napi-v3/Release/argon2.a node_modules/argon2/build-tmp-napi-v3/Release/obj.target/argon2.a
  cp node_modules/argon2/build-tmp-napi-v3/Release/argon2.node node_modules/argon2/lib/binding/napi-v3/argon2.node
  cp lib/vscode/node_modules/@parcel/watcher/build/Release/obj.target/watcher.node lib/vscode/node_modules/@parcel/watcher/build/Release/watcher.node
  cp lib/vscode/node_modules/@parcel/watcher/build/Release/nothing.a lib/vscode/node_modules/@parcel/watcher/build/node-addon-api/nothing.a
  cp lib/vscode/node_modules/kerberos/build/Release/kerberos.node lib/vscode/node_modules/kerberos/build/Release/obj.target/kerberos.node
  cp lib/vscode/node_modules/native-watchdog/build/Release/watchdog.node lib/vscode/node_modules/native-watchdog/build/Release/obj.target/watchdog.node
  cp lib/vscode/node_modules/@vscode/windows-registry/build/Release/obj.target/winregistry.node lib/vscode/node_modules/@vscode/windows-registry/build/Release/winregistry.node
  cp lib/vscode/node_modules/@vscode/windows-process-tree/build/Release/windows_process_tree.node lib/vscode/node_modules/@vscode/windows-process-tree/build/Release/obj.target/windows_process_tree.node
  cp lib/vscode/node_modules/@vscode/spdlog/build/Release/spdlog.node lib/vscode/node_modules/@vscode/spdlog/build/Release/obj.target/spdlog.node
  cp lib/vscode/node_modules/@vscode/deviceid/build/Release/windows.node lib/vscode/node_modules/@vscode/deviceid/build/Release/obj.target/windows.node
}

install_vs_code(){
  if [ ! -d "$UBUNTU_PATH/opt/code-server-$CSVERSION-linux-arm64" ];then
    tar zxfh $TMPDIR/code-server-$CSVERSION-linux-arm64.tar.gz -C $UBUNTU_PATH/opt | while read line; do
      # echo -ne "\033[2K\0337\r$line\0338"
      echo $line
    done
    progress_echo "pwd: `pwd`"
    fix_code_server_hard_link
    progress_echo "pwd: `pwd`"
  fi
}

login_ubuntu(){
  bash $BIN/proot-distro login --bind /storage/emulated/0:/storage/emulated/0/ ubuntu  -- /opt/code-server-$CSVERSION-linux-arm64/bin/code-server
}

''';

/// 启动 vs code 的shell
String startVsCodeScript = '''
$function
$functions

clear_lines(){
  printf "\\033[1A" # Move cursor up one line
  printf "\\033[K"  # Clear the line
  printf "\\033[1A" # Move cursor up one line
  printf "\\033[K"  # Clear the line
}
start_vs_code(){
  clear_lines
  install_proot_distro
  sleep 1
  echo 7 > \$TMPDIR/progress
  install_ubuntu
  sleep 1
  echo 8 > \$TMPDIR/progress
  install_vs_code
  sleep 1
  echo 9 > \$TMPDIR/progress
  gen_code_server_config
  sleep 1
  echo 10 > \$TMPDIR/progress
  login_ubuntu
}
''';
