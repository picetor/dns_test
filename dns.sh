#!/bin/bash
# dns_bench.sh - DNS 性能对比工具（仅依赖 kdig）
# 支持 UDP, TCP, DoH, DoT
# 串行执行，实时打印结果，只显示网络延迟
# 合并国内国外 DNS 到一张表，国外 DNS 对国内域名显示 "-"
# 国外 DNS 协议之间用 "-----" 分隔，不显示文字标签

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 测试域名
CHINA_DOMAINS=("baidu.com" "qq.com" "taobao.com" "aliyun.com")
FOREIGN_DOMAINS=("google.com" "youtube.com" "twitter.com" "github.com")
ALL_DOMAINS=("${CHINA_DOMAINS[@]}" "${FOREIGN_DOMAINS[@]}")

# 生成随机子域名（绕过缓存）
rand_sub() {
    echo "rand-$(date +%s%N)-$RANDOM"
}

# ---------- 依赖检查与安装 ----------
check_deps() {
    local missing=()
    if ! command -v kdig &>/dev/null; then
        missing+=("kdig")
    fi
    if ! command -v bc &>/dev/null; then
        missing+=("bc")
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "${YELLOW}缺少依赖: ${missing[*]}${NC}"
        read -p "是否尝试自动安装？(y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if [[ -f /etc/debian_version ]]; then
                sudo apt update
                sudo apt install -y knot-dnsutils bc
            elif [[ -f /etc/redhat-release ]]; then
                sudo yum install -y knot-dnsutils bc
            else
                echo -e "${RED}不支持自动安装，请手动安装 knot-dnsutils 和 bc。${NC}"
                exit 1
            fi
            local still_missing=()
            if ! command -v kdig &>/dev/null; then
                still_missing+=("kdig")
            fi
            if ! command -v bc &>/dev/null; then
                still_missing+=("bc")
            fi
            if [[ ${#still_missing[@]} -gt 0 ]]; then
                echo -e "${RED}安装失败，仍缺少: ${still_missing[*]}。请手动安装。${NC}"
                exit 1
            fi
            echo -e "${GREEN}依赖安装完成。${NC}"
        else
            echo -e "${RED}请手动安装后重新运行。${NC}"
            exit 1
        fi
    fi
}

# ---------- 测试单个 DNS 服务器（返回网络延迟毫秒数或 FAIL）----------
test_dns() {
    local server_spec="$1"
    local domain="$2"
    local rand_domain="$(rand_sub).$domain"

    local proto=""
    local addr=""
    if [[ "$server_spec" =~ ^https?:// ]]; then
        proto="doh"
        addr="$server_spec"
    elif [[ "$server_spec" =~ ^tls:// ]]; then
        proto="dot"
        addr="${server_spec#tls://}"
    elif [[ "$server_spec" =~ ^tcp:// ]]; then
        proto="tcp"
        addr="${server_spec#tcp://}"
    else
        proto="udp"
        addr="$server_spec"
    fi

    local kdig_out=""
    case "$proto" in
        udp)
            kdig_out=$(kdig "$rand_domain" @"$addr" +stats 2>&1)
            ;;
        tcp)
            kdig_out=$(kdig +tcp "$rand_domain" @"$addr" +stats 2>&1)
            ;;
        doh)
            local host=$(echo "$addr" | sed -E 's|https?://([^/]+).*|\1|')
            kdig_out=$(kdig +https @"$host" "$rand_domain" +stats 2>&1)
            ;;
        dot)
            kdig_out=$(kdig +tls-ca +tls-host="$addr" @"$addr" "$rand_domain" +stats 2>&1)
            ;;
    esac

    local time_str=""
    time_str=$(echo "$kdig_out" | grep -oP '(?<=Time: )[0-9]+' | head -1)
    if [[ -z "$time_str" ]]; then
        time_str=$(echo "$kdig_out" | grep -oP 'in \K[0-9.]+(?= ms)' | head -1)
    fi

    if [[ -n "$time_str" ]]; then
        local time_ms=$(echo "$time_str" | awk '{print int($1+0.5)}')
        echo "${time_ms}ms"
    else
        echo "FAIL"
    fi
}

# ---------- 合并打印表格（国内+国外）----------
print_merged_table() {
    local -n servers=$1
    local title=$2

    echo -e "${GREEN}========== $title ==========${NC}"
    # 表头（全部域名）
    printf "%-28s" "DNS 服务器"
    for d in "${ALL_DOMAINS[@]}"; do
        printf "%-12s" "$d"
    done
    echo ""
    printf "%-28s" "--------------------------"
    for d in "${ALL_DOMAINS[@]}"; do
        printf "%-12s" "------------"
    done
    echo ""

    # 定义国内和国外服务商列表
    local china_providers=("阿里" "腾讯")
    local foreign_providers=("CF" "谷歌" "思科" "DNS.SB")
    local protocols=("UDP" "TCP" "DOH" "DOT")

    # 先打印国内 DNS（全部域名）
    for proto in "${protocols[@]}"; do
        for prov in "${china_providers[@]}"; do
            local key="${prov}_${proto}"
            if [[ -n "${servers[$key]}" ]]; then
                local addr="${servers[$key]}"
                printf "%-28s" "$key"
                for domain in "${ALL_DOMAINS[@]}"; do
                    local result=$(test_dns "$addr" "$domain")
                    printf "%-12s" "$result"
                    sleep 0.1
                done
                echo ""
            fi
        done
    done

    # 分隔线（国内与国外之间）
    echo -e "${BLUE}========================================${NC}"

    # 打印国外 DNS（国内域名显示 "-"，国外域名实际测试）
    # 协议之间输出 "-----" 分隔线（UDP 之前不加，从第二个协议开始）
    local first_protocol=true
    for proto in "${protocols[@]}"; do
        # 如果不是第一个协议，则输出分隔线
        if [[ "$first_protocol" == "false" ]]; then
            echo "-----"
        fi
        for prov in "${foreign_providers[@]}"; do
            local key="${prov}_${proto}"
            if [[ -n "${servers[$key]}" ]]; then
                local addr="${servers[$key]}"
                printf "%-28s" "$key"
                for domain in "${ALL_DOMAINS[@]}"; do
                    local is_china=false
                    for cd in "${CHINA_DOMAINS[@]}"; do
                        if [[ "$domain" == "$cd" ]]; then
                            is_china=true
                            break
                        fi
                    done
                    if [[ "$is_china" == "true" ]]; then
                        printf "%-12s" "-"
                    else
                        local result=$(test_dns "$addr" "$domain")
                        printf "%-12s" "$result"
                        sleep 0.1
                    fi
                done
                echo ""
            fi
        done
        first_protocol=false
    done
    echo ""
}

# ---------- 方案1：预定义 DNS ----------
declare -A PRE_DNS

# 阿里
PRE_DNS["阿里_UDP"]="223.5.5.5"
PRE_DNS["阿里_TCP"]="tcp://223.5.5.5"
PRE_DNS["阿里_DOH"]="https://dns.alidns.com/dns-query"
PRE_DNS["阿里_DOT"]="tls://dns.alidns.com"

# 腾讯
PRE_DNS["腾讯_UDP"]="119.29.29.29"
PRE_DNS["腾讯_TCP"]="tcp://119.29.29.29"
PRE_DNS["腾讯_DOH"]="https://doh.pub/dns-query"
PRE_DNS["腾讯_DOT"]="tls://dot.pub"

# Cloudflare (CF)
PRE_DNS["CF_UDP"]="1.1.1.1"
PRE_DNS["CF_TCP"]="tcp://1.1.1.1"
PRE_DNS["CF_DOH"]="https://1.1.1.1/dns-query"
PRE_DNS["CF_DOT"]="tls://1.1.1.1"

# 谷歌
PRE_DNS["谷歌_UDP"]="8.8.8.8"
PRE_DNS["谷歌_TCP"]="tcp://8.8.8.8"
PRE_DNS["谷歌_DOH"]="https://dns.google/dns-query"
PRE_DNS["谷歌_DOT"]="tls://dns.google"

# 思科 (OpenDNS)
PRE_DNS["思科_UDP"]="208.67.222.222"
PRE_DNS["思科_TCP"]="tcp://208.67.222.222"
PRE_DNS["思科_DOH"]="https://doh.opendns.com/dns-query"
PRE_DNS["思科_DOT"]="tls://208.67.222.222"

# DNS.SB
PRE_DNS["DNS.SB_UDP"]="185.222.222.222"
PRE_DNS["DNS.SB_TCP"]="tcp://185.222.222.222"
PRE_DNS["DNS.SB_DOH"]="https://doh.dns.sb/dns-query"

# ---------- 方案2：自定义 DNS ----------
declare -A CUSTOM_DNS
custom_dns() {
    echo -e "${YELLOW}请输入自定义 DNS 服务器（支持格式：IP、tcp://IP、https://domain/path、tls://domain）${NC}"
    echo "每行格式: 名称 地址 (例如: my-doh https://1.1.1.1/dns-query)"
    echo "输入空行结束。"
    while true; do
        read -p "名称: " name
        [[ -z "$name" ]] && break
        read -p "地址: " addr
        [[ -z "$addr" ]] && { echo "地址不能为空"; continue; }
        CUSTOM_DNS["$name"]="$addr"
        echo "已添加: $name -> $addr"
    done
    if [[ ${#CUSTOM_DNS[@]} -eq 0 ]]; then
        echo -e "${RED}未添加任何自定义 DNS，跳过方案2。${NC}"
        return 1
    fi
    return 0
}

print_custom_table() {
    local -n servers=$1
    local title=$2

    echo -e "${GREEN}========== $title ==========${NC}"
    printf "%-28s" "DNS 服务器"
    for d in "${ALL_DOMAINS[@]}"; do
        printf "%-12s" "$d"
    done
    echo ""
    printf "%-28s" "--------------------------"
    for d in "${ALL_DOMAINS[@]}"; do
        printf "%-12s" "------------"
    done
    echo ""

    for name in "${!servers[@]}"; do
        local addr="${servers[$name]}"
        printf "%-28s" "$name"
        for domain in "${ALL_DOMAINS[@]}"; do
            local result=$(test_dns "$addr" "$domain")
            printf "%-12s" "$result"
            sleep 0.1
        done
        echo ""
    done
    echo ""
}

# ---------- 主菜单 ----------
main() {
    check_deps

    echo -e "${BLUE}DNS 性能对比工具（基于 kdig，串行实时输出）${NC}"
    echo "1) 方案1：预定义 DNS（阿里/腾讯/CF/谷歌/思科/DNS.SB）"
    echo "2) 方案2：自定义 DNS（手动输入）"
    read -p "请选择 [1/2]: " choice

    case $choice in
        1)
            print_merged_table PRE_DNS "DNS 性能对比（国内/国外合并）"
            ;;
        2)
            if custom_dns; then
                print_custom_table CUSTOM_DNS "自定义 DNS 对比（测试全部域名）"
            fi
            ;;
        *)
            echo -e "${RED}无效选择，退出。${NC}"
            exit 1
            ;;
    esac
}

main