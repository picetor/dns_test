# DNS 性能测试工具集

本仓库提供两个 Bash 脚本，用于测试和对比 DNS 解析性能：

- **`local_dns_test.sh`**：快速测试指定 DNS 服务器解析国内/国外域名的延迟（支持自定义上游）。
```
wget -O local_dns_test.sh https://raw.githubusercontent.com/picetor/dns_test/main/local_dns_test.sh
```

赋权&运行，默认[localhost:53]，参数见[用法](#用法)
```
chmod +x local_dns_test.sh && ./local_dns_test.sh -c
```
---
- **`dns.sh`**：全面的 DNS 性能对比工具，支持 UDP、TCP、DoH、DoT 协议，预定义多家服务商，并生成对比表格。
```
wget -O dns.sh https://raw.githubusercontent.com/picetor/dns_test/main/dns.sh && chmod +x dns.sh && ./dns.sh
```
---

## 📦 依赖安装

脚本依赖以下工具（部分系统可能需要手动安装）：

- `dig` (dnsutils) – 用于 `local_dns_test.sh`
- `kdig` (knot-dnsutils) – 用于 `dns.sh` 的全协议测试
- `bc` – 用于计算

### Debian / Ubuntu
```bash
sudo apt update
sudo apt install -y dnsutils knot-dnsutils bc
```

### CentOS / RHEL
```bash
sudo yum install -y bind-utils knot-dnsutils bc
```

> `dns.sh` 会自动检测缺失依赖并询问是否安装。

---

## 🚀 脚本 1：`local_dns_test.sh` – 快速单服务器测试

### 功能
- 测试指定 DNS 服务器解析**国内域名**（baidu.com, qq.com, taobao.com, aliyun.com）和**国外域名**（google.com, youtube.com, twitter.com, github.com）的延迟。
- 每次查询使用随机子域名（例如 `rand-12345678.baidu.com`）绕过缓存。
- 支持分别指定国内和国外域名使用的 DNS 服务器（默认 `127.0.0.1`）。

### 用法
```bash
chmod +x local_dns_test.sh
./local_dns_test.sh [-c 国内DNS_IP] [-f 国外DNS_IP]
```

| 选项 | 说明 |
|------|------|
| `-c IP` | 国内域名使用的 DNS 服务器 IP（例如 `223.5.5.5`） |
| `-f IP` | 国外域名使用的 DNS 服务器 IP（例如 `1.1.1.1`） |
| `-h`   | 显示帮助信息 |

### 示例

1. **使用默认本机 MosDNS (127.0.0.1)**
   ```bash
   ./local_dns_test.sh
   ```

2. **国内用阿里 DNS，国外用 Cloudflare DNS**
   ```bash
   ./local_dns_test.sh -c 223.5.5.5 -f 1.1.1.1
   ```

3. **仅指定国内 DNS，国外仍用本机**
   ```bash
   ./local_dns_test.sh -c 119.29.29.29
   ```

### 输出示例
```
========== 测试国内域名（DNS: 127.0.0.1）==========
rand-1781354256267011538-31281.baidu.com -> 44 msec
rand-1781354256320326575-2334.qq.com -> 40 msec
rand-1781354256372625959-20677.taobao.com -> 28 msec
rand-1781354256419470816-28055.aliyun.com -> 64 msec

========== 测试国外域名（DNS: 127.0.0.1）==========
rand-1781354256491826022-20897.google.com -> 84 msec
rand-1781354256582228913-4938.youtube.com -> 136 msec
rand-1781354256727295946-26997.twitter.com -> 188 msec
rand-1781354256922001231-6808.github.com -> 84 msec
```

---

## 📊 脚本 2：`dns.sh` – 多服务商全协议对比

### 功能
- 对比多家 DNS 服务商（阿里、腾讯、Cloudflare、谷歌、思科、DNS.SB）在 **UDP、TCP、DoH、DoT** 四种协议下的解析性能。
- 国内服务商测试全部域名（国内+国外），国外服务商仅测试国外域名（国内域名位置显示 `-`）。
- 输出整齐的表格，国外协议组之间以 `-----` 分隔，不显示文字标签。
- 串行执行，实时打印结果（无需等待所有测试完成）。
- 自动检查并安装缺失依赖（`kdig`、`bc`）。

### 用法
```bash
chmod +x dns.sh
./dns.sh
```

运行后出现菜单：
```
DNS 性能对比工具（基于 kdig，串行实时输出）
1) 方案1：预定义 DNS（阿里/腾讯/CF/谷歌/思科/DNS.SB）
2) 方案2：自定义 DNS（手动输入）
请选择 [1/2]: 
```

- **方案1**：直接测试预定义的 6 家服务商的所有协议。
- **方案2**：允许你手动输入自定义 DNS 服务器（支持 `IP`、`tcp://IP`、`https://domain/path`、`tls://domain`），然后测试所有域名。

### 输出示例（部分）
```
========== DNS 性能对比（国内/国外合并） ==========
DNS 服务器               baidu.com   qq.com      taobao.com  aliyun.com  google.com  youtube.com twitter.com github.com  
--------------------------  ------------------------------------------------------------------------------------------------
阿里_UDP                  23ms        33ms        30ms        25ms        263ms       34ms        33ms        34ms        
腾讯_UDP                  21ms        32ms        26ms        29ms        72ms        34ms        32ms        37ms        
阿里_TCP                  45ms        288ms       40ms        46ms        274ms       75ms        47ms        65ms        
腾讯_TCP                  FAIL        FAIL        FAIL        FAIL        FAIL        FAIL        FAIL        FAIL        
阿里_DOH                  69ms        78ms        73ms        74ms        126ms       99ms        76ms        71ms        
腾讯_DOH                  163ms       107ms       371ms       196ms       400ms       132ms       160ms       193ms       
阿里_DOT                  71ms        1241ms      68ms        65ms        142ms       97ms        65ms        136ms       
腾讯_DOT                  153ms       103ms       FAIL        99ms        FAIL        121ms       106ms       173ms       
========================================
CF_UDP                      -           -           -           -           82ms        115ms       84ms        82ms        
谷歌_UDP                  -           -           -           -           98ms        85ms        87ms        88ms        
思科_UDP                  -           -           -           -           115ms       86ms        154ms       88ms        
DNS.SB_UDP                  -           -           -           -           82ms        83ms        82ms        190ms       
-----
CF_TCP                      -           -           -           -           174ms       466ms       182ms       160ms       
谷歌_TCP                  -           -           -           -           171ms       172ms       534ms       174ms       
思科_TCP                  -           -           -           -           184ms       450ms       171ms       175ms       
DNS.SB_TCP                  -           -           -           -           468ms       171ms       173ms       169ms       
-----
CF_DOH                      -           -           -           -           332ms       353ms       411ms       348ms       
谷歌_DOH                  -           -           -           -           346ms       444ms       713ms       333ms       
思科_DOH                  -           -           -           -           744ms       695ms       376ms       885ms       
DNS.SB_DOH                  -           -           -           -           474ms       476ms       484ms       1081ms      
-----
CF_DOT                      -           -           -           -           334ms       309ms       369ms       352ms       
谷歌_DOT                  -           -           -           -           364ms       694ms       401ms       421ms       
思科_DOT                  -           -           -           -           1058ms      358ms       420ms       344m
```

### 自定义 DNS 输入示例
```
名称: my-doh
地址: https://1.1.1.1/dns-query
名称: my-dot
地址: tls://1.1.1.1
名称: my-udp
地址: 8.8.8.8
（空行结束）
```

---

## 🔧 常见问题

### Q: `local_dns_test.sh` 提示 `dig: command not found`
安装 `dnsutils`：
```bash
sudo apt install dnsutils   # Debian/Ubuntu
sudo yum install bind-utils # CentOS
```

### Q: `dns.sh` 提示 `kdig: command not found`
安装 `knot-dnsutils`，脚本会自动尝试安装。

### Q: 为什么某些协议显示 `FAIL`？
- 网络环境可能屏蔽了特定端口（如 TCP 53、DoT 853 等）。
- 上游 DNS 服务器不支持该协议（如部分服务商 DoT 证书问题）。
- 可以改用方案2手动输入其他地址测试。

### Q: 测试结果中延迟数值差异很大？
- 随机子域名强制绕过缓存，每次查询都是真实往返时间。
- 网络波动、路由变化都会影响数值，建议多次测试取平均。

