# 家用云盘搭建

> 当前基于Windows子系统Ubuntu搭建  
> 本来想用CentOS的，但是子系统上很多问题，于是子系统安装了Ubuntu，官方支持确实好很多  
> 也可以用树莓派或者单独linux主机  
> 存储：单独的USB或SATA外接存储、直接硬盘装到主机上都可以  
> 因为对于数据安全要求不高，而且做阵列那些也太贵了，于是买了一个16T的硬盘安装到主机上直接使用，对于安全要求高的数据，其实不是很多，做好多备份，单独用一个移动硬盘一个月备份一次就好  
> 采用开源nextcloud搭建  

* 教程主要基于WSL2的Ubuntu子系统

### 系统安装

* Ubuntu子系统（Windows10 WSL2）

* * 打开wsl支持

* * * 1：安装 WSL 2 之前，必须启用“虚拟机平台”可选功能。
* * * 2：以管理员身份打开 PowerShell 并运行：
* * * 然后运行：
~~~shell
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
~~~

* * * 重新启动计算机，以完成 WSL 安装并更新到 WSL 2。
* * * 下载下方连接 并安装 即可更新到wsl2

https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi

* * * 安装内核升级程序。
* * * 官方文档：https://docs.microsoft.com/zh-cn/windows/wsl/install

* * 管理员运行 Windows Terminal
* * 设置默认版本

~~~shell
wsl --set-default-version 2
~~~

* * 打开Microsoft Store下载安装Ubuntu20.04

* * 进入子系统启动ssh远程
* * * 出现：no hostkeys available— exiting
* * * root权限下，重新生成密钥：

~~~shell
ssh-keygen -t dsa -f /etc/ssh/ssh_host_dsa_key
ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key
# 修改密钥权限
chmod 600 /etc/ssh/ssh_host_dsa_key
chmod 600 /etc/ssh/ssh_host_rsa_key
# 然后启动
/etc/init.d/ssh start 
~~~

* * *  修改/etc/ssh/sshd_config，打开ssh的root登陆

* * 子系统关闭swap以及配置内存使用
* * * Windows /Users/${用户名}/.wslconfig

~~~
[wsl2]
memory=8G
swap=0
~~~

### 系统安装docker-ce

* Ubuntu修改更新源到阿里云
* 备份/etc/apt/sources.list
* 新的/etc/apt/sources.list

~~~
deb http://mirrors.aliyun.com/ubuntu/ focal main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ focal main restricted universe multiverse

deb http://mirrors.aliyun.com/ubuntu/ focal-security main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ focal-security main restricted universe multiverse

deb http://mirrors.aliyun.com/ubuntu/ focal-updates main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ focal-updates main restricted universe multiverse

deb http://mirrors.aliyun.com/ubuntu/ focal-proposed main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ focal-proposed main restricted universe multiverse

deb http://mirrors.aliyun.com/ubuntu/ focal-backports main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ focal-backports main restricted universe multiverse
~~~

* * * 更新

~~~shell
apt update
~~~

~~~shell
# root用户ssh到ubuntu
# 更新软件包索引，并且安装必要的依赖软件，来添加一个新的 HTTPS 软件源
apt update
apt install apt-transport-https ca-certificates curl gnupg-agent software-properties-common
# 使用 curl 导入源仓库的 GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
# 将 Docker APT 软件源添加到你的系统
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
# 安装 Docker 最新版本
apt update
apt install docker-ce docker-ce-cli containerd.io
~~~

* * * 启动

~~~shell
/etc/init.d/docker start
~~~

### 配置自动启动

* wsl 通过 /etc/init.wsl来启动

* init.wsl 加入需要自动启动的命令

~~~shell
#! /bin/sh
/etc/init.d/cron $1
/etc/init.d/ssh $1
/etc/init.d/docker $1
~~~

~~~shell
# 修改权限
chmod +x /etc/init.wsl
~~~

* 创建一个vbs脚本 ubuntu.vbs

~~~vbs
Set ws = CreateObject("Wscript.Shell")
ws.run "wsl -d Ubuntu-20.04 -u root /etc/init.wsl start", vbhide
~~~

* * 用wsl -l -v 查看子系统名称 Ubuntu-20.04  

* 把脚本ubuntu.vbs加入任务计划程序
* * 设置不登陆也启动
* * 使用最高权限
* * 系统启动时
* * 如果任务失败每十分钟运行一次，999次。

### 安装nextcloud

* 安装docker-compose

~~~shell
apt install -y python3
pip3 install docker-compose
~~~

* /data/webroot/nextcloud/docker-compose.yml

~~~yml
version: "3.3"
services:
  nas-mysql:
    image: mysql:8
    container_name: "nas-mysql"
    restart: always
    privileged: true
    command:
      --default-authentication-plugin=mysql_native_password
      --character-set-server=utf8mb4
      --collation-server=utf8mb4_general_ci
      --explicit_defaults_for_timestamp=true
      --lower_case_table_names=1
    environment:
      - MYSQL_ROOT_PASSWORD=Nas
      - MYSQL_PASSWORD=Nas
      - MYSQL_DATABASE=nextcloud
      - MYSQL_USER=nas
    volumes:
      - ./mysql/data:/var/lib/mysql
    networks:
      - nas_net
  nextcloud:
    image: nextcloud
    container_name: "nextcloud"
    restart: always
    privileged: true
    volumes:
      - ./nextcloud:/var/www/html
    environment:
      - MYSQL_PASSWORD=Nas
      - MYSQL_DATABASE=nextcloud
      - MYSQL_USER=nas
    depends_on:
      - nas-mysql
      - nas-ftp
      - nas-redis
    networks:
      - nas_net
  nas-nginx:
    image: openresty/openresty:alpine
    container_name: "nas-nginx"
    restart: always
    privileged: true
    volumes:
      - ./nginx/vhosts:/etc/nginx/conf.d
      - ./nginx/cert:/data/cert
      - ./nginx/logs:/data/logs
    ports:
      - 8080:80
      - 8443:443
    depends_on:
      - nextcloud
    networks:
      - nas_net
  nas-ftp:
    image: fauria/vsftpd
    container_name: "nas-ftp"
    restart: always
    privileged: true
    environment:
      - FTP_USER=nas
      - FTP_PASS=Nas
    volumes:
      - ./ftp:/home/vsftpd
    networks:
      - nas_net
  nas-redis:
    build: ./redis
    container_name: "nas-redis"
    restart: always
    privileged: true
    networks:
      - nas_net
networks:
  nas_net:
    external:
      name: nas_net
~~~

> 所有服务端口只有nginx的需要暴露出来，其他的只能内部访问  

* 创建 nginx目录及子目录
* * nginx/logs
* * nginx/cert 存放域名证书
* * nginx/vhosts

* nginx/vhosts/default.conf
~~~conf
client_max_body_size 0;

server {
    listen 80;
    server_name www.mynas.com;
    location / {
        if ($http_x_custom_header != "external") {
            rewrite ^(.*)$ https://$host$1 redirect;
        }

        proxy_pass http://nextcloud:80;
        proxy_read_timeout 30s;
        proxy_send_timeout 30s;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

        proxy_http_version 1.1;
    }
}

server {
    listen 443 ssl;
    server_name www.mynas.com;

    error_log /data/logs/www.mynas.com_error.log;
    access_log off;

    index index.html;

    ssl_certificate /data/cert/www.mynas.com.pem;
    ssl_certificate_key /data/cert/www.mynas.com.key;
    ssl_session_timeout 5m;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE:ECDH:AES:HIGH:!NULL:!aNULL:!MD5:!ADH:!RC4;
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_prefer_server_ciphers on;

    location / {
        proxy_pass http://nextcloud:80;
        proxy_read_timeout 30s;
        proxy_send_timeout 30s;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

        proxy_http_version 1.1;
    }
}
~~~

> 因为家里没有公网IP，所以通过穿透的方式，公网访问的时候反向代理过来的，所以对于公网访问，设置了自定义头，根据头判断，做相应的处理  

* 创建redis目录

* redis/Dockerfile

~~~conf
FROM redis:5
COPY redis.conf /usr/local/etc/redis/redis.conf
CMD [ "redis-server", "/usr/local/etc/redis/redis.conf" ]
~~~

> redis6 nextcloud暂时有点问题  

* redis/redis.conf
~~~conf
requirepass Nas
bind 0.0.0.0
~~~

### 配置端口转发

* 在子系统中的服务端口都是绑定到localhost上的，局域网通过主机IP地址访问到需要做一个端口映射

~~~shell
# 2222 => 22
netsh interface portproxy add v4tov4  listenport=2222 listenaddress=0.0.0.0  connectport=22 connectaddress=localhost
# 80 => 8080
netsh interface portproxy add v4tov4  listenport=80 listenaddress=0.0.0.0  connectport=8080 connectaddress=localhost
# 443 => 8443
netsh interface portproxy add v4tov4  listenport=443 listenaddress=0.0.0.0  connectport=8443 connectaddress=localhost
~~~

* 查看所有的端口转发

`netsh interface portproxy show all`

* 删除端口转发

`netsh interface portproxy delete v4tov4 listenport=2222 listenaddress=0.0.0.0`

###  配置内网穿透

* [下载frp](https://github.com/fatedier/frp/tags)

* 服务端配置frps.ini

~~~ini
[common]
bind_port = 9030
token = xxxxx
~~~

> token是密码，客户端需要配置一样  

* * 修改systemd/frps.service文件中的frps路径
* * 然后拷贝frps.service到/lib/systemd/system/目录/lib/systemd/system/frps.service
* * systemctl start frps
* * systemctl enable frps

* Windows上客户端配置frpc.ini

~~~ini
[common]
server_addr = 8.8.8.8
server_port = 9030
token = xxxxxx

[home-nas]
type = tcp
local_ip = 127.0.0.1
local_port = 80
remote_port = 9034
~~~

* * frp目录下配置bat，然后将bat加入到任务计划程序
* * 配置不需要登陆启动

~~~bat
@echo off
set retime=60
:start
frpc.exe -c frpc.ini
echo Error
echo --------------------------------------------
echo 连节点或登入失败-即将在%retime%秒后重新连
echo --------------------------------------------
timeout /t %retime% 
goto start
~~~

### 公网访问nginx配置

* www.mynas.com.conf

~~~conf
server {
    listen 80;
    server_name www.mynas.com;
    rewrite ^(.*)$  https://$host$1 redirect;
}
    
server {
    listen 443 ssl;
    server_name www.mynas.com;

    ssl_certificate /data/cert/www.mynas.com.pem;
    ssl_certificate_key /data/cert/www.mynas.com.key;
    ssl_session_timeout 5m;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE:ECDH:AES:HIGH:!NULL:!aNULL:!MD5:!ADH:!RC4;
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_prefer_server_ciphers on;

    client_max_body_size 0;
    
    location / {
        proxy_pass http://127.0.0.1:9034;
        proxy_read_timeout 30s;
        proxy_send_timeout 30s;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Custom-header "external";

        proxy_http_version 1.1;
    }
}
~~~

### 安装

* 访问 https://www.mynas.com
* 配置账号、访问数据开始安装
* 安装过程可能出现504什么，可以不用管，刷新页面重新来一次就可以了

* 修改配置，https配置
* 修改如下两行nextcloud/config/config.php

~~~php
  'overwriteprotocol' => 'https',
  'overwrite.cli.url' => 'www.mynas.com',
~~~

* 添加redis支持
* nextcloud/config/config.php 最后加入

~~~php
  'filelocking.enabled' => true,
  'memcache.distributed' => '\OC\Memcache\Redis',
  'memcache.locking' => '\OC\Memcache\Redis',
  'redis' => array (
    'host' => 'nas-redis',
    'password' => 'Nas',
  ),
~~~

### 配置ftp

* 使用ftp比较方便，配置外置存储
* 启用应用 External storage support	
* docker-compose.yml中把需要共享的存储配置到ftp下

~~~conf
      - /mnt/e:/home/vsftpd/nas/Family
      - /mnt/f:/home/vsftpd/nas/Works
      - /mnt/g:/home/vsftpd/nas/Amusement
      - /mnt/h:/home/vsftpd/nas/Robbie
~~~

> 把磁盘映射到ftp下  

* 然后配置外部存储

### 内网DNS

* 路由器可以直接配置（有些可以）
* 直接配置访问设备的hosts，但是公网访问的时候，需要去掉
* 因为家里正好有个树莓派，所以在树莓派配置了一个dnsmasq，然后路由器dns指向到树莓派的dnsmasq

### 客户端

[下载](https://nextcloud.com/install/#install-clients)

### Windows安装SMB服务

* 设置共享用户账号
* 设置共享目录

### 配置WebDAV

[nginx-WebDAV](https://github.com/arut/nginx-dav-ext-module)

* 安装nginx扩展
* 根据官方文档

* 安装htpasswd命令
* apt install apache2-utils 
* 生成密码
* htpasswd -c /data/htpasswd/dav dav

* 配置nginx

~~~conf
server {
  listen 8443 ssl;
  server_name wd.mynas.com;

  error_log /data/logs/wd.mynas.com_error.log;
  access_log off;
  
  index index.html;

  ssl_certificate /data/cert/n.ekuy.com.pem;
  ssl_certificate_key /data/cert/n.ekuy.com.key;
  ssl_session_timeout 5m;
  ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE:ECDH:AES:HIGH:!NULL:!aNULL:!MD5:!ADH:!RC4;
  ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
  ssl_prefer_server_ciphers on;

  location / {
    set $dest $http_destination;
    if (-d $request_filename) {
        rewrite ^(.*[^/])$ $1/;
        set $dest $dest/;
    }
    if ($request_method ~ (MOVE|COPY)) {
        more_set_input_headers 'Destination: $dest';
    }

    if ($request_method ~ MKCOL) {
        rewrite ^(.*[^/])$ $1/ break;
    }

    dav_methods PUT DELETE MKCOL COPY MOVE;
    dav_ext_methods PROPFIND OPTIONS;
    dav_access user:rw;
    create_full_put_path  on;
    root /data/webdav;

    auth_basic "Restricted access";
    auth_basic_user_file /data/htpasswd/.webdav;
  }
}
~~~

> 外网通过webdav访问 内网通过smb访问   
> 也可以配置dns，让webdav内网走局域网IP  
> 所以最后使ke"ES文件浏览器"，配置WebDAV，公网和局域网不同的请求域名解析。很好这样子，最后把nextcloud抛弃了  
> "ES文件浏览器"客户端是支持照片同步的    
>> nextcloud是在太慢了，局域网的时候就非常慢，不知道为什么，开始以为是子系统安装docker的原因   
>> 然后尝试直接在windows上安装各种依赖，直接安装nextcloud，最后发现安装不起，官方有提示，不支持windows  

### 安装rsync

> 用来替换之前的电脑端的同步工具  

~~~shell
brew install rsync
# 文件更新提示 
brew install fsevents-tools
# 配置免密登陆
# 把id_rsa.pub内容拷贝到~/.ssh/authorized_keys
~~~

* 同步脚本
* rsync.sh

~~~shell
#!/bin/bash

rsync -avz --progress --delete -e 'ssh -p 2222' /Users/username/HomeCloud root@192.168.31.55:/mnt/f
~~~

### 常用的几个参数

~~~
-v  verbose 详细输出
-a 	归档模式，递归方式传输文件，并保持连接，权限，用户和组，时间信息
-z  压缩文件传输
-h  human-readable, 输出友好
-u  跳过已经存在的文件，备份更新
~~~

### rsync 参数的具体解释如下：

~~~
-v, --verbose 详细模式输出
-q, --quiet 精简输出模式
-c, --checksum 打开校验开关，强制对文件传输进行校验
-a, --archive 归档模式，表示以递归方式传输文件，并保持所有文件属性，等于 -rlptgoD
-r, --recursive 对子目录以递归模式处理
-R, --relative 使用相对路径信息
-b, --backup 创建备份，也就是对于目的已经存在有同样的文件名时，将老的文件重新命名为~filename。可以使用 --suffix 选项来指定不同的备份文件前缀。
--backup-dir 将备份文件（如~filename) 存放在在目录下。
-suffix=SUFFIX 定义备份文件前缀
-u, --update 仅仅进行更新，也就是跳过所有已经存在于 DST，并且文件时间晚于要备份的文件。（不覆盖更新的文件）
-l, --links 保留软链结
-L, --copy-links 想对待常规文件一样处理软链结
--copy-unsafe-links 仅仅拷贝指向 SRC 路径目录树以外的链结
--safe-links 忽略指向 SRC 路径目录树以外的链结
-H, --hard-links 保留硬链结
-p, --perms 保持文件权限
-o, --owner 保持文件属主信息
-g, --group 保持文件属组信息
-D, --devices 保持设备文件信息
-t, --times 保持文件时间信息
-S, --sparse 对稀疏文件进行特殊处理以节省 DST 的空间
-n, --dry-run 现实哪些文件将被传输
-W, --whole-file 拷贝文件，不进行增量检测
-x, --one-file-system 不要跨越文件系统边界
-B, --block-size=SIZE 检验算法使用的块尺寸，默认是 700 字节
-e, --rsh=COMMAND 指定使用 rsh、ssh 方式进行数据同步
--rsync-path=PATH 指定远程服务器上的 rsync 命令所在路径信息
-C, --cvs-exclude 使用和 CVS 一样的方法自动忽略文件，用来排除那些不希望传输的文件
--existing 仅仅更新那些已经存在于 DST 的文件，而不备份那些新创建的文件
--delete 删除那些 DST 中 SRC 没有的文件
--delete-excluded 同样删除接收端那些被该选项指定排除的文件
--delete-after 传输结束以后再删除
--ignore-errors 及时出现 IO 错误也进行删除
--max-delete=NUM 最多删除 NUM 个文件
--partial 保留那些因故没有完全传输的文件，以是加快随后的再次传输
--force 强制删除目录，即使不为空
--numeric-ids 不将数字的用户和组 ID 匹配为用户名和组名
--timeout=TIME IP 超时时间，单位为秒
-I, --ignore-times 不跳过那些有同样的时间和长度的文件
--size-only 当决定是否要备份文件时，仅仅察看文件大小而不考虑文件时间
--modify-window=NUM 决定文件是否时间相同时使用的时间戳窗口，默认为 0
-T --temp-dir=DIR 在 DIR 中创建临时文件
--compare-dest=DIR 同样比较 DIR 中的文件来决定是否需要备份
-P 等同于 --partial
--progress 显示备份过程
-z, --compress 对备份的文件在传输时进行压缩处理
--exclude=PATTERN 指定排除不需要传输的文件模式
--include=PATTERN 指定不排除而需要传输的文件模式
--exclude-from=FILE 排除 FILE 中指定模式的文件
--include-from=FILE 不排除 FILE 指定模式匹配的文件
--version 打印版本信息
~~~