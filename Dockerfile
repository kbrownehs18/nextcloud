FROM nextcloud:latest

RUN echo "deb http://mirrors.aliyun.com/debian/ $(. /etc/os-release && echo $VERSION_CODENAME) main non-free contrib" > /etc/apt/sources.list && \
    echo "deb-src http://mirrors.aliyun.com/debian/ $(. /etc/os-release && echo $VERSION_CODENAME) main non-free contrib" >> /etc/apt/sources.list && \
    echo "deb http://mirrors.aliyun.com/debian-security/ $(. /etc/os-release && echo $VERSION_CODENAME)-security main" >> /etc/apt/sources.list && \
    echo "deb-src http://mirrors.aliyun.com/debian-security/ $(. /etc/os-release && echo $VERSION_CODENAME)-security main" >> /etc/apt/sources.list && \
    echo "deb http://mirrors.aliyun.com/debian/ $(. /etc/os-release && echo $VERSION_CODENAME)-updates main non-free contrib" >> /etc/apt/sources.list && \
    echo "deb-src http://mirrors.aliyun.com/debian/ $(. /etc/os-release && echo $VERSION_CODENAME)-updates main non-free contrib" >> /etc/apt/sources.list && \
    echo "deb http://mirrors.aliyun.com/debian/ $(. /etc/os-release && echo $VERSION_CODENAME)-backports main non-free contrib" >> /etc/apt/sources.list && \
    echo "deb-src http://mirrors.aliyun.com/debian/ $(. /etc/os-release && echo $VERSION_CODENAME)-backports main non-free contrib" >> /etc/apt/sources.list

RUN apt update && apt upgrade -y
RUN apt install ffmpeg smbclient libsmbclient-dev -y
RUN pecl install smbclient
RUN docker-php-ext-enable smbclient