#!/bin/bash
# -*- coding: UTF-8 -*-
#############################################
# 作者：KevinCheng
# 环境：Ubuntu18.04 64位
# 1. 配置域名解析
# 2. git clone **.git
# 3. cd *.git && sh ngrokd-ubuntu.sh							#
#############################################
source /etc/profile
# 获取当前脚本执行路径
SELFPATH=$(
    cd "$(dirname "$0")"
    pwd
)
GOOS=$(go env | grep GOOS | awk -F\" '{print $2}')
GOARCH=$(go env | grep GOARCH | awk -F\" '{print $2}')
# 安装依赖
install_yilai() {
    apt -y update
    apt -y upgrade
    # linux 屏幕管理包
    apt install -y screen
    # 清理openssl缓存
    openssl rand -writerand .rnd
}

# 安装git
install_git() {
    uninstall_git
    apt install -y git
}

# 卸载git
uninstall_git() {
    apt remove -y git
}

# 安装go
install_go() {
    cd $SELFPATH
    uninstall_go
    # 动态链接库，用于下面的判断条件生效
    ldconfig
    # 判断操作系统位数下载不同的安装包
    if [ $(getconf WORD_BIT) = '32' ] && [ $(getconf LONG_BIT) = '64' ]; then
        # 判断文件是否已经存在
        if [ ! -f $SELFPATH/go1.4.linux-amd64.tar.gz ]; then
            wget https://storage.googleapis.com/golang/go1.4.linux-amd64.tar.gz --no-check-certificate
            wget https://storage.googleapis.com/golang/go1.7.linux-amd64.tar.gz --no-check-certificate
        fi
        tar -zxf go1.4.linux-amd64.tar.gz
        mv go go1.4
        tar -C /usr/local/ -zxf go1.7.linux-amd64.tar.gz
    else
        # 暂时用不到
        echo "暂时不安装32位的"
    fi
    sed -i '$a export GOROOT=/usr/local/go' /etc/profile
    sed -i '$a export PATH=$GOROOT/bin:$PATH' /etc/profile
    source /etc/profile
}

# 卸载go

uninstall_go() {
    rm -rf /root/go1.4
    rm -rf /usr/local/go
}

# 安装ngrok
install_ngrok() {
    uninstall_ngrok
    cd $SELFPATH
    if [ ! -d ngrok ]; then
        git clone https://github.com/inconshreveable/ngrok.git
    fi
    cd $SELFPATH/ngrok
    echo '请输入解析的域名'
    read NGROK_DOMAIN
    openssl genrsa -out rootCA.key 2048
    openssl req -x509 -new -nodes -key rootCA.key -subj "/CN=$NGROK_DOMAIN" -days 5000 -out rootCA.pem
    openssl genrsa -out device.key 2048
    openssl req -new -key device.key -subj "/CN=$NGROK_DOMAIN" -out device.csr
    openssl x509 -req -in device.csr -CA rootCA.pem -CAkey rootCA.key -CAcreateserial -out device.crt -days 5000

    cp rootCA.pem assets/client/tls/ngrokroot.crt
    cp device.crt assets/server/tls/snakeoil.crt
    cp device.key assets/server/tls/snakeoil.key
    # 防止文件没生效c
    source /etc/profile
    # 编译服务端
    make release-server
}

# 卸载ngrok
uninstall_ngrok() {
    rm -rf $SELFPATH/ngrok
}

# 编译客户端
compile_client() {
    cd /usr/local/go/src
    GOOS=$1 GOARCH=$2 ./make.bash
    cd $SELFPATH/ngrok
    GOOS=$1 GOARCH=$2 make release-client
}

# 生成客户端
client() {
    echo "1、Linux 32位"
    echo "2、Linux 64位"
    echo "3、Windows 32位"
    echo "4、Windows 64位"
    echo "5、Mac OS 32位"
    echo "6、Mac OS 64位"
    echo "7、Linux ARM"

    read num
    case "$num" in
    [1])
        compile_client linux 386
        ;;
    [2])
        compile_client linux amd64
        ;;
    [3])
        compile_client windows 386
        ;;
    [4])
        compile_client windows amd64
        ;;
    [5])
        compile_client darwin 386
        ;;
    [6])
        compile_client darwin amd64
        ;;
    [7])
        compile_client linux arm
        ;;
    *) echo "选择错误，退出" ;;
    esac

}

echo "请输入下面数字进行选择"
echo "#############################################"
echo "#作者网名：KevinCheng"
echo "#############################################"
echo "------------------------"
echo "1、全新安装"
echo "2、生成客户端"
echo "3、启动服务"
echo "4、启动客户端"
echo "------------------------"
read num
case "$num" in
[1])
    install_yilai
    install_git
    install_go
    install_ngrok
    ;;
[2])
    client
    ;;
[3])
    echo "输入启动域名"
    read domain
    echo "服务端连接端口"
    read port
    $SELFPATH/ngrok/bin/ngrokd -domain=$domain -tunnelAddr=":$port"
    ;;
[4])
    echo "输入启动域名"
    read domain
    echo server_addr: '"'$domain:3399'"'
    echo "trust_host_root_certs: false"
    ;;
*) echo "" ;;
esac