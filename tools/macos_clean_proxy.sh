#!/bin/bash
# macos_clean_proxy.sh
# 一键清理 macOS 代理冲突、杀死残留核心并重置网络代理

echo "================================================="
echo " 🧹 macOS VPN / 代理冲突一键清理与网络重置工具"
echo "================================================="

# 1. 杀死冲突内核进程
echo "[-] 正在清理残留的代理内核进程..."
pkill -9 -f "mihomo" 2>/dev/null
pkill -9 -f "clash" 2>/dev/null
pkill -9 -f "v2ray" 2>/dev/null
pkill -9 -f "sing-box" 2>/dev/null

# 2. 获取所有网络硬件接口并关闭系统代理
echo "[+] 正在重置 macOS 网络服务代理配置..."
INTERFACES=$(networksetup -listallnetworkservices | grep -v "An asterisk")
for iface in $INTERFACES; do
    networksetup -setwebproxystate "$iface" off 2>/dev/null
    networksetup -setsecurewebproxystate "$iface" off 2>/dev/null
    networksetup -setsocksfirewallproxystate "$iface" off 2>/dev/null
done

# 3. 刷新 DNS 缓存
echo "[+] 正在刷新系统 DNS 缓存..."
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder 2>/dev/null

echo "[✓] macOS 网络代理与进程清理完毕！"
