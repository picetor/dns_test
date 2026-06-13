#!/bin/bash

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

rand_prefix() {
    echo "rand-$(date +%s%N)-$RANDOM"
}

echo "========== 测试国内域名（应走本地 DoH）=========="
for domain in "${china_domains[@]}"; do
    rand_domain="$(rand_prefix).$domain"
    # 使用 +stats 但不加 +short，同时提取 Query time
    time=$(dig "$rand_domain" @127.0.0.1 +stats 2>&1 | grep -oP 'Query time: \K[0-9]+')
    echo "$rand_domain -> ${time:-未获取到} msec"
done

echo ""
echo "========== 测试国外域名（应走远程 DoH 或 udpme）=========="
for domain in "${foreign_domains[@]}"; do
    rand_domain="$(rand_prefix).$domain"
    time=$(dig "$rand_domain" @127.0.0.1 +stats 2>&1 | grep -oP 'Query time: \K[0-9]+')
    echo "$rand_domain -> ${time:-未获取到} msec"
done