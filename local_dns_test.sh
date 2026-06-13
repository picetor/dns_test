#!/bin/bash
# DNS 解析延迟测试工具
# 支持自定义国内/国外 DNS 服务器（默认 127.0.0.1）
# 用法:
#   ./local_dns_test.sh [-c 国内DNS] [-f 国外DNS]
# 示例:
#   ./local_dns_test.sh -c 223.5.5.5 -f 1.1.1.1
#   ./local_dns_test.sh                     # 使用默认 127.0.0.1

set -e

# 默认 DNS 服务器地址
DEFAULT_DNS="127.0.0.1"

# 解析命令行参数
CHINA_DNS="$DEFAULT_DNS"
FOREIGN_DNS="$DEFAULT_DNS"
while getopts "c:f:h" opt; do
    case $opt in
        c) CHINA_DNS="$OPTARG" ;;
        f) FOREIGN_DNS="$OPTARG" ;;
        h)
            echo "用法: $0 [-c 国内DNS] [-f 国外DNS]"
            echo "  -c  指定国内域名使用的 DNS 服务器 IP"
            echo "  -f  指定国外域名使用的 DNS 服务器 IP"
            echo "  默认均使用 127.0.0.1"
            exit 0
            ;;
        *) exit 1 ;;
    esac
done

# 测试域名列表
china_domains=(
    "baidu.com"
    "qq.com"
    "taobao.com"
    "aliyun.com"
)

foreign_domains=(
    "google.com"
    "youtube.com"
    "twitter.com"
    "github.com"
)

# 生成随机子域名（绕过缓存）
rand_prefix() {
    echo "rand-$(date +%s%N)-$RANDOM"
}

# 测试函数
test_dns() {
    local dns_server="$1"
    local domain="$2"
    local rand_domain="$(rand_prefix).$domain"
    local time=$(dig "$rand_domain" @"$dns_server" +stats 2>&1 | grep -oP 'Query time: \K[0-9]+')
    echo "${time:-未获取到}"
}

echo "========== 测试国内域名（DNS: $CHINA_DNS）=========="
for domain in "${china_domains[@]}"; do
    rand_domain="$(rand_prefix).$domain"
    time=$(test_dns "$CHINA_DNS" "$domain")
    echo "$rand_domain -> ${time} msec"
done

echo ""
echo "========== 测试国外域名（DNS: $FOREIGN_DNS）=========="
for domain in "${foreign_domains[@]}"; do
    rand_domain="$(rand_prefix).$domain"
    time=$(test_dns "$FOREIGN_DNS" "$domain")
    echo "$rand_domain -> ${time} msec"
done