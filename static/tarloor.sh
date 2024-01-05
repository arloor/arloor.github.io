#! /bin/bash

repo=https://github.com/arloor/baguwen.git
hugoVersion="0.96.0"
hugoURL=https://github.com/gohugoio/hugo/releases/download/v${hugoVersion}/hugo_extended_${hugoVersion}_Linux-64bit.tar.gz
is_deb="1"
if ! grep debian /etc/os-release &>/dev/null; then
  is_deb="0"
  echo "使用redhat系命令"
else
  echo "使用debian系命令"
fi

## 检查依赖
function CheckDependence() {
  FullDependence='0'
  for BIN_DEP in $(echo "$1" | sed 's/,/\n/g'); do
    if [[ -n "$BIN_DEP" ]]; then
      Founded='0'
      for BIN_PATH in $(echo "$PATH" | sed 's/:/\n/g'); do
        ls $BIN_PATH/$BIN_DEP >/dev/null 2>&1
        if [ $? == '0' ]; then
          Founded='1'
          break
        fi
      done
      if [ "$Founded" == '1' ]; then
        echo -en "$BIN_DEP\t\t[\033[32mok\033[0m]\n"
      else
        FullDependence='1'
        echo -en "$BIN_DEP\t\t[\033[31mfail\033[0m]\n"
      fi
    fi
  done
  if [ "$FullDependence" == '1' ]; then
    echo "安装缺失的依赖....."
    if [ "$is_deb" == "1" ]; then
      apt install -y git tar wget
    else
      yum install -y git tar wget
    fi
  fi
}

echo -e "\n\033[36m# Check Dependence\033[0m\n"
CheckDependence git,tar,wget
echo -e "\n\033[36m# Dependence Check done\033[0m\n"

# 如果不需要使用代理，则使用 bash tarloor 0
[ "$1" = "1" ] && {
  proxystart=1
  # 设置http代理，使用方法：
  export http_proxy=http://127.0.0.1:3128
  export https_proxy=http://127.0.0.1:3128
  git config --global http.proxy 'http://127.0.0.1:3128'
  git config --global https.proxy 'http://127.0.0.1:3128'
}

# 检查/var/blog是否存在，存在则update
[ ! -d /var/blog ] && echo -e "\n\033[36marloor blog not exits. git clone....\033[0m\n" && {
  git clone ${repo} /var/blog
} || {
  echo -e "\n\033[36marloor's blog exits. git pull....\033[0m\n"
  cd /var/blog
  git pull --ff-only || {
    echo "git pull 失败，重新clone"
    cd $home
    rm -rf /var/blog
    git clone ${repo} /var/blog
  }
}

# 检查hugo是否安装

hashugo=$(hugo version | grep ${hugoVersion}) && [ "" != " $hashugo" ] && hugo version || {
  echo -e "\n\033[36m# Installing hugo extended...\033[0m\n"
  mkdir /tmp/hugo
  wget $hugoURL -O /tmp/hugo/hugo.tar.gz
  tar -zxf /tmp/hugo/hugo.tar.gz -C /tmp/hugo/
  mv -f /tmp/hugo/hugo /usr/local/bin/
  chmod +x /usr/local/bin/hugo
  rm -rf /tmp/hugo
}

# 现在可以关闭代理了
[ "$proxystart" = "1" ] && {
  export http_proxy=
  export https_proxy=
  #git config --global --unset http.proxy
  #git config --global --unset https.proxy
}

# 检查httpd是否安装
if [ "$is_deb" == "1" ]; then
  nginx=$(nginx -v 2>&1 | grep "nginx version") && [ "" != "$nginx" ] && echo -e "\n\033[36m# nginx installed\033[0m\n" || {
    echo -e "\n\033[36m# Installing nginx\033[0m\n"
    apt install nginx-full -y
    service nginx start
    systemctl enable nginx
  }
else
  nginx=$(rpm -qa nginx) && [ ! -z $nginx ] && echo -e "\n\033[36m# nginx installed\033[0m\n" || {
    echo -e "\n\033[36m# Installing nginx\033[0m\n"
    yum install nginx -y
    service nginx start
    systemctl enable nginx
  }
fi

cd /var/blog
hugo -d /usr/share/nginx/html/
service nginx reload
