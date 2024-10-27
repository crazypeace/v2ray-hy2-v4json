# v2ray-hy2-v4json
V2ray 支持 Hysteria2 配置文件v4格式 一键脚本演示

## 一键执行

```
bash <(curl -L https://github.com/crazypeace/v2ray-hy2-v4json/raw/main/install.sh)
```

# Uninstall
```
bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh) --remove
rm /etc/apt/sources.list.d/caddy-stable.list
apt remove -y caddy
```

## 带参数执行方式
```
bash <(curl -L https://github.com/crazypeace/v2ray-hy2-v4json/raw/main/install.sh) <netstack> <port> <domain> <password>
```
如
```
bash <(curl -L https://github.com/crazypeace/v2ray-hy2-v4json/raw/main/install.sh) 4 2096 bing.com d3b27d90-507d-30c0-93db-42982a5a33a7
```

## 说明
本项目主要目的是演示 V2ray 支持 Hysteria2 配置文件v4格式, 证书使用自签.  
如果你想用别的方式申请证书请自行参考其它教程/文档以实践.  
配置文件格式参考 https://github.com/JimmyHuang454/v2ray-core/blob/dev/release/config/hy2/hysteria2_offical_v4.json  
我把 tlsSettings 段补充完整, 并针对小白补充更详细的手搓过程.

## 手搓步骤如下

官方脚本安装 V2ray  
```
bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)
```

自签证书  
1. 安装 openssl
```
apt install -y openssl
```   
2. 建个目录用来存放自签证书  
   当然可以是任何你自己喜欢的目录
```
mkdir -p /etc/ssl/private/
```
3. 生成自签证书.crt .key文件  
   这里是自签 bing.com 当然可以是任何你自己喜欢的域名
```
openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) -keyout "/etc/ssl/private/bing.com.key" -out "/etc/ssl/private/bing.com.crt" -subj "/CN=bing.com" -days 36500
```   
4. 给目录和证书设置权限  
   这里粗暴了一点, 直接设置的777. 你想精细化呢, 就设置给官方脚本里service的用户nobody.
```
chmod -R 777 "/etc/ssl/private"
```
5. 修改 /usr/local/etc/v2ray/config.json  
   这个配置文件的位置是官方安装脚本设置的
```
{ // Hy2-v4-json
  "log": {
    "access": "/var/log/v2ray/access.log",
    "error": "/var/log/v2ray/error.log",
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": 54321,  // HY2工作端口 你自己修改
      "listen": "0.0.0.0",
      "protocol": "hysteria2",
      "streamSettings": {
        "network": "hysteria2",
        "security": "tls",
        "tlsSettings": {
          "alpn": [
            "h3"
          ],
          "certificates": [
            {
              "certificateFile": "/etc/ssl/private/bing.com.crt", // 证书文件路径
              "keyFile": "/etc/ssl/private/bing.com.key"          // 证书文件路径
            }
          ]
        },
        "hy2Settings": {
          "password": "************"  // HY2密码 你自己修改
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {
        "domainStrategy": "UseIP"
      },
      "tag": "direct"
    }
  ],
  "dns": {
    "servers": [
      "https+local://8.8.8.8/dns-query",
      "8.8.8.8",
      "1.1.1.1",
      "localhost"
    ]
  }
}
```

启用 service  
```
systemctl enable v2ray; systemctl start v2ray
```
