# 等待1秒, 避免curl下载脚本的打印与脚本本身的显示冲突, 吃掉了提示用户按回车继续的信息
sleep 1

echo -e "                     _ ___                   \n ___ ___ __ __ ___ _| |  _|___ __ __   _ ___ \n|-_ |_  |  |  |-_ | _ |   |- _|  |  |_| |_  |\n|___|___|  _  |___|___|_|_|___|  _  |___|___|\n        |_____|               |_____|        "
red='\e[91m'
green='\e[92m'
yellow='\e[93m'
magenta='\e[95m'
cyan='\e[96m'
none='\e[0m'

error() {
    echo -e "\n${red} 输入错误! ${none}\n"
}

warn() {
    echo -e "\n$yellow $1 $none\n"
}

pause() {
    read -rsp "$(echo -e "按 ${green} Enter 回车键 ${none} 继续....或按 ${red} Ctrl + C ${none} 取消.")" -d $'\n'
    echo
}

# 说明
echo
echo -e "${yellow}此脚本仅兼容于Debian 10+系统. 如果你的系统不符合,请Ctrl+C退出脚本${none}"
echo -e "可以去 ${cyan}https://github.com/crazypeace/v2ray-hy2-v4json${none} 查看脚本整体思路和关键命令, 以便针对你自己的系统做出调整."
echo -e "有问题加群 ${cyan}https://t.me/+ISuvkzFGZPBhMzE1${none}"
echo -e "本脚本支持带参数执行, 省略交互过程, 详见GitHub."
echo "----------------------------------------------------------------"

# 本机 IP
InFaces=($(ifconfig -s | awk '{print $1}' | grep -E '^(eth|ens|eno|esp|enp|venet|vif)'))  #找所有的网口

for i in "${InFaces[@]}"; do  # 从网口循环获取IP
    # 增加超时时间, 以免在某些网络环境下请求IPv6等待太久
    Public_IPv4=$(curl -4s --interface "$i" --m 2 https://www.cloudflare.com/cdn-cgi/trace | grep -oP "ip=\K.*$")
    Public_IPv6=$(curl -6s --interface "$i" --m 2 https://www.cloudflare.com/cdn-cgi/trace | grep -oP "ip=\K.*$")

    if [[ -n "$Public_IPv4" ]]; then  # 检查是否获取到IP地址
        IPv4="$Public_IPv4"
    fi
    if [[ -n "$Public_IPv6" ]]; then  # 检查是否获取到IP地址            
        IPv6="$Public_IPv6"
    fi
done

# 通过IP, host, 时区, 生成UUID. 重装脚本不改变, 不改变节点信息, 方便个人使用
uuidSeed=${IPv4}${IPv6}$(cat /proc/sys/kernel/hostname)$(cat /etc/timezone)
default_uuid=$(curl -sL https://www.uuidtools.com/api/generate/v3/namespace/ns:dns/name/${uuidSeed} | grep -oP '[^-]{8}-[^-]{4}-[^-]{4}-[^-]{4}-[^-]{12}')

# 如果你想使用纯随机的UUID
# default_uuid=$(cat /proc/sys/kernel/random/uuid)

# 默认端口2096
default_port=2096
# 如果你想使用随机的端口
# default_port=$(shuf -i20001-65535 -n1)

# 执行脚本带参数
if [ $# -ge 1 ]; then
    # 第1个参数是搭在ipv4还是ipv6上
    case ${1} in
    4)
        netstack=4
        ip=${IPv4}
        ;;
    6)
        netstack=6
        ip=${IPv6}
        ;;
    *) # initial
        if [[ -n "$IPv4" ]]; then  # 检查是否获取到IP地址
            netstack=4
            ip=${IPv4}
        elif [[ -n "$IPv6" ]]; then  # 检查是否获取到IP地址            
            netstack=6
            ip=${IPv6}
        else
            warn "没有获取到公共IP"
        fi
        ;;
    esac

    # 第2个参数是port
    port=${2}
    if [[ -z $port ]]; then
      port=${default_port}
    fi

    # 第3个参数是域名
    domain=${3}
    if [[ -z $domain ]]; then
      domain="learn.microsoft.com"
    fi

    # 第4个参数是密码
    pwd=${4}
    if [[ -z $pwd ]]; then
        pwd=${default_uuid}
    fi

    echo -e "${yellow} netstack = ${cyan}${netstack}${none}"
    echo -e "${yellow} 本机IP = ${cyan}${ip}${none}"
    echo -e "${yellow} 端口 (Port) = ${cyan}${port}${none}"
    echo -e "${yellow} 密码 (Password) = ${cyan}${pwd}${none}"
    echo -e "${yellow} 自签证书所用域名 (Certificate Domain) = ${cyan}${domain}${none}"
    echo "----------------------------------------------------------------"
fi

pause

# 准备工作
apt update
apt install -y curl openssl qrencode net-tools lsof

# V2ray官方脚本 安装最新版本
echo
echo -e "${yellow}V2ray官方脚本安装最新版本${none}"
echo "----------------------------------------------------------------"
bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)

systemctl enable v2ray; systemctl start v2ray

# 配置 Hy2, 使用自签证书, 需要:端口, 密码, 证书所用域名(不必拥有该域名)
echo
echo -e "${yellow}配置 Hy2, 使用自签证书${none}"
echo "----------------------------------------------------------------"

# 网络栈
if [[ -z $netstack ]]; then
  echo
  echo -e "如果你的小鸡是${magenta}双栈(同时有IPv4和IPv6的IP)${none}，请选择你把Xray搭在哪个'网口'上"
  echo "如果你不懂这段话是什么意思, 请直接回车"
  read -p "$(echo -e "Input ${cyan}4${none} for IPv4, ${cyan}6${none} for IPv6:") " netstack

  if [[ $netstack == "4" ]]; then
    ip=${IPv4}
  elif [[ $netstack == "6" ]]; then
    ip=${IPv6}
  else
    if [[ -n "$IPv4" ]]; then  # 检查是否获取到IP地址
        netstack=4
        ip=${IPv4}
    elif [[ -n "$IPv6" ]]; then  # 检查是否获取到IP地址            
        netstack=6
        ip=${IPv6}
    else
        warn "没有获取到公共IP"
    fi    
  fi
fi

# 端口
if [[ -z $port ]]; then
  while :; do
    read -p "$(echo -e "请输入端口 [${magenta}1-65535${none}] Input port (默认Default ${cyan}${default_port}$none):")" port
    [ -z "$port" ] && port=$default_port
    case $port in
    [1-9] | [1-9][0-9] | [1-9][0-9][0-9] | [1-9][0-9][0-9][0-9] | [1-5][0-9][0-9][0-9][0-9] | 6[0-4][0-9][0-9][0-9] | 65[0-4][0-9][0-9] | 655[0-3][0-5])
      echo
      echo
      echo -e "$yellow 端口 (Port) = ${cyan}${port}${none}"
      echo "----------------------------------------------------------------"
      echo
      break
      ;;
    *)
      error
      ;;
    esac
  done
fi

# 域名
if [[ -z $domain ]]; then
    echo
    echo -e "请输入自签证书使用的 ${magenta}域名${none} Input certificate domain"
    read -p "(默认: learn.microsoft.com): " domain
    [ -z "$domain" ] && domain="learn.microsoft.com"
    echo
    echo
    echo -e "$yellow 证书域名 Certificate Domain = ${cyan}${domain}${none}"
    echo "----------------------------------------------------------------"
    echo
fi

# 密码
if [[ -z $pwd ]]; then
    echo -e "请输入 ${yellow}密码${none}"
    read -p "$(echo -e "(默认ID: ${cyan}${default_uuid}$none):")" pwd
    [ -z "$pwd" ] && pwd=${default_uuid}
    echo
    echo
    echo -e "${yellow} 密码 (Password) = ${cyan}${pwd}${none}"
    echo "----------------------------------------------------------------"
    echo
fi

# 生成证书
cert_dir="/etc/ssl/private"
mkdir -p ${cert_dir}
openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) -keyout "${cert_dir}/${domain}.key" -out "${cert_dir}/${domain}.crt" -subj "/CN=${domain}" -days 36500
chmod -R 777 ${cert_dir}

# 配置 /usr/local/etc/v2ray/config.json
echo
echo -e "${yellow}配置 /usr/local/etc/v2ray/config.json${none}"
echo "----------------------------------------------------------------"
cat >/usr/local/etc/v2ray/config.json <<-EOF
{ // Hy2-v4-json
  "log": {
    "access": "/var/log/v2ray/access.log",
    "error": "/var/log/v2ray/error.log",
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": ${port},      // ***
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
              "certificateFile": "${cert_dir}/${domain}.crt",    // ***
              "keyFile": "${cert_dir}/${domain}.key"             // ***
            }
          ]
        },
        "hy2Settings": {
          "password": "${pwd}"    // ***
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
    },
// [outbound]
{
  "protocol": "freedom",
  "settings": {
    "domainStrategy": "UseIPv4"
  },
  "tag": "force-ipv4"
},
{
  "protocol": "freedom",
  "settings": {
    "domainStrategy": "UseIPv6"
  },
  "tag": "force-ipv6"
},
{
  "protocol": "socks",
  "settings": {
    "servers": [
      {
        "address": "127.0.0.1",
        "port": 40000
      }
    ]
  },
  "tag": "socks5-warp"
},
    {
      "protocol": "blackhole",
      "settings": {},
      "tag": "blocked"
    }
  ],
  "dns": {
    "servers": [
      "https+local://8.8.8.8/dns-query",
      "8.8.8.8",
      "1.1.1.1",
      "localhost"
    ]
  },
  "routing": {
    "domainStrategy": "IPOnDemand",
    "rules": [
      {
        "type": "field",
        "ip": [
          "0.0.0.0/8",
          "10.0.0.0/8",
          "100.64.0.0/10",
          "127.0.0.0/8",
          "169.254.0.0/16",
          "172.16.0.0/12",
          "192.0.0.0/24",
          "192.0.2.0/24",
          "192.168.0.0/16",
          "198.18.0.0/15",
          "198.51.100.0/24",
          "203.0.113.0/24",
          "::1/128",
          "fc00::/7",
          "fe80::/10"
        ],
        "outboundTag": "blocked"
      },
// [routing-rule]
//{
//     "type": "field",
//     "domain": ["geosite:google", "geosite:openai"],  // ***
//     "outboundTag": "force-ipv6"  // force-ipv6 // force-ipv4 // socks5-warp
//},
//{
//     "type": "field",
//     "domain": ["geosite:cn"],  // ***
//     "outboundTag": "force-ipv6"  // force-ipv6 // force-ipv4 // socks5-warp // blocked
//},
//{
//     "type": "field",
//     "ip": ["geoip:cn"],  // ***
//     "outboundTag": "force-ipv6"  // force-ipv6 // force-ipv4 // socks5-warp // blocked
//},
      {
        "type": "field",
        "protocol": [
          "bittorrent"
        ],
        "outboundTag": "blocked"
      }
    ]
  }  
}

EOF


# 重启 V2Ray
echo
echo -e "$yellow重启 V2Ray$none"
echo "----------------------------------------------------------------"
service v2ray restart


echo
echo
echo "---------- Hy2 客户端配置信息 ----------"
echo -e "$yellow 地址 (Address) = $cyan${ip}$none"
echo -e "$yellow 端口 (Port) = ${cyan}${port}${none}"
echo -e "$yellow 密码 (Password) = ${cyan}${pwd}${none}"
echo -e "$yellow 传输层安全 (TLS) = ${cyan}tls${none}"
echo -e "$yellow 应用层协议协商 (Alpn) = ${cyan}h3${none}"
echo -e "$yellow 跳过证书验证 (allowInsecure) = ${cyan}true${none}"
echo
echo "---------- 链接 URL ----------"
v2ray_hy2_url="hysteria2://${pwd}@${ip}:${port}?alpn=h3&insecure=1#HY2-${ip}"
echo -e "${cyan}${v2ray_hy2_url}${none}"
echo
sleep 3
echo "以下两个二维码完全一样的内容"
qrencode -t UTF8 $v2ray_hy2_url
qrencode -t ANSI $v2ray_hy2_url
echo
echo "---------- END -------------"
echo "以上节点信息保存在 ~/_v2ray_hy2_url_ 中"

# 节点信息保存到文件中
echo $v2ray_hy2_url > ~/_v2ray_hy2_url_
echo "以下两个二维码完全一样的内容" >> ~/_v2ray_hy2_url_
qrencode -t UTF8 $v2ray_hy2_url >> ~/_v2ray_hy2_url_
qrencode -t ANSI $v2ray_hy2_url >> ~/_v2ray_hy2_url_


# 如果是 IPv6 小鸡，用 WARP 创建 IPv4 出站
if [[ $netstack == "6" ]]; then
    echo
    echo -e "$yellow这是一个 IPv6 小鸡，用 WARP 创建 IPv4 出站$none"
    echo "Telegram电报是直接访问IPv4地址的, 需要IPv4出站的能力"    
    echo -e "如果WARP安装不顺利, 请在命令行执行${cyan} bash <(curl -L https://ghproxy.crazypeace.workers.dev/https://github.com/crazypeace/warp.sh/raw/main/warp.sh) 4 ${none}"
    echo "----------------------------------------------------------------"
    pause

    # 安装 WARP IPv4
    bash <(curl -fsSL git.io/warp.sh) 4

    # 重启 V2Ray
    echo
    echo -e "$yellow重启 V2Ray$none"
    echo "----------------------------------------------------------------"
    service v2ray restart

    # 重启 CaddyV2
    echo
    echo -e "$yellow重启 CaddyV2$none"
    echo "----------------------------------------------------------------"
    service caddy restart

# 如果是 IPv4 小鸡，用 WARP 创建 IPv6 出站
elif  [[ $netstack == "4" ]]; then
    echo
    echo -e "$yellow这是一个 IPv4 小鸡，用 WARP 创建 IPv6 出站$none"
    echo -e "有些热门小鸡用原生的IPv4出站访问Google需要通过人机验证, 可以通过修改config.json指定google流量走WARP的IPv6出站解决"
    echo -e "群组: ${cyan} https://t.me/+ISuvkzFGZPBhMzE1 ${none}"
    echo -e "教程: ${cyan} https://zelikk.blogspot.com/2022/03/racknerd-v2ray-cloudflare-warp--ipv6-google-domainstrategy-outboundtag-routing.html ${none}"
    echo -e "视频: ${cyan} https://youtu.be/Yvvm4IlouEk ${none}"
    echo -e "如果WARP安装不顺利, 请在命令行执行${cyan} bash <(curl -L https://ghproxy.crazypeace.workers.dev/https://github.com/crazypeace/warp.sh/raw/main/warp.sh) 6 ${none}"
    echo "----------------------------------------------------------------"
    pause

    # 安装 WARP IPv6    
    bash <(curl -fsSL git.io/warp.sh) 6

    # 重启 V2Ray
    echo
    echo -e "$yellow重启 V2Ray$none"
    echo "----------------------------------------------------------------"
    service v2ray restart

    # 重启 CaddyV2
    echo
    echo -e "$yellow重启 CaddyV2$none"
    echo "----------------------------------------------------------------"
    service caddy restart

fi
