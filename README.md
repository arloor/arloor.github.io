[![](https://img.shields.io/github/last-commit/arloor/blog.svg?style=flat)](https://github.com/arloor/blog/commit/master)
![](https://img.shields.io/github/languages/code-size/arloor/blog.svg?style=flat)

# 访问[八股文](https://www.arloor.dev)
使用hugo生成静态博客

## 安装[hugo 0.96.0 extended](https://github.com/gohugoio/hugo/releases/tag/v0.96.0) （需要支持 scss）

## 部署

```
## 支持centos8和ubuntu20.04
wget -O /usr/local/bin/tarloor http://www.arloor.com/tarloor.sh
bash tarloor
```

## nginx配置（ubuntu20.04下）

```shell
cat > /etc/nginx/sites-enabled/default <<\EOF
log_format  arloor  '$remote_addr # [$time_iso8601] # "$request_uri" # '
                    '$status # '
                    '"$http_user_agent" # "$request_time" # "$http_referer"';

server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name          www.arloor.dev;
    return               301 https://$host$request_uri;
}

server {
    listen               443 ssl http2;
    listen               [::]:443 ssl http2;
    server_name          arloor.dev;
    return               301 https://www.arloor.dev$request_uri;
}

server {
    listen               443 ssl http2 default_server;
    listen               [::]:443 ssl http2 default_server;

    root /usr/share/nginx/html/baguwen;
    index index.html index.htm index.nginx-debian.html;
    access_log /var/log/nginx/arloor.access.log arloor;
    server_name          www.arloor.dev;

    ssl_certificate      /root/.acme.sh/arloor.dev/fullchain.cer;
    ssl_certificate_key  /root/.acme.sh/arloor.dev/arloor.dev.key;
    error_page 404 /404.html;
    location / {
                # First attempt to serve request as file, then
                # as directory, then fall back to displaying a 404.
                try_files $uri $uri/ =404;
    }
}
EOF
service nginx restart
```

## nginx配置(rhel8下)

```shell
cat > /etc/nginx/conf.d/arloor.conf <<\EOF
log_format  arloor  '$remote_addr # [$time_iso8601] # "$request_uri" # '
                    '$status # '
                    '"$http_user_agent" # "$request_time" # "$http_referer"';

server {
    listen 80;
    listen [::]:80;
    server_name          www.arloor.dev;
    return               301 https://$host$request_uri;
}

server {
    listen               443 ssl http2;
    listen               [::]:443 ssl http2;
    server_name          arloor.dev;
    return               301 https://www.arloor.dev$request_uri;
}

server {
    listen               443 ssl http2 default_server;
    listen               [::]:443 ssl http2 default_server;

    root /usr/share/nginx/html/baguwen;
    index index.html index.htm index.nginx-debian.html;
    access_log /var/log/nginx/arloor.access.log arloor;
    server_name          www.arloor.dev;

    ssl_certificate      /root/.acme.sh/arloor.dev/fullchain.cer;
    ssl_certificate_key  /root/.acme.sh/arloor.dev/arloor.dev.key;
    error_page 404 /404.html;
    location / {
                # First attempt to serve request as file, then
                # as directory, then fall back to displaying a 404.
                try_files $uri $uri/ =404;
    }
}
EOF
service nginx restart
```

## 查看nginx访问日志

基于以上log_format，提供一个查看本博客访问日志的脚本：

```shell
cat >/usr/local/bin/arloor <<\EOF
tail -n 10000 `ls -ltc /var/log/nginx/arloor.access.log*|head -n 1|awk '{print $9}'`|awk -F" # " '$3~"(.*post.*|.*about.*|.*page.*|.*tags.*|^\"/\"$)" && $4==200 {printf("%s %15s %-30s %s\n",$2,$1,$3,$5)}'
EOF
chmod +x /usr/local/bin/arloor
arloor
```

效果如下：

```shell
112.2.xxx.xxx   [2022-05-09T11:02:26+08:00] "/about/"
223.70.xxx.x    [2022-05-09T11:02:46+08:00] "/posts/redis/redis-cluster/"
14.25.xxx.xxx   [2022-05-09T11:03:45+08:00] "/posts/i-was-young/"
113.89.xx.xx    [2022-05-09T11:03:58+08:00] "/posts/shell-tricks/"
110.53.xx.xx    [2022-05-09T11:04:01+08:00] "/posts/shell-tricks/"
```
