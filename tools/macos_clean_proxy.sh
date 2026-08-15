#!/bin/bash
# macos_clean_proxy.sh
# 一键清理 macOS 代理冲突、杀死残留核心并重置网络代理

DIR="$(cd "$(dirname "$0")" && pwd)"

if [ -f "$DIR/macos_vpn_doctor.sh" ]; then
    bash "$DIR/macos_vpn_doctor.sh" --fix
    exit 0
fi

echo "================================================="
echo " 🧹 macOS VPN / 代理冲突一键清理与网络重置工具"
echo "================================================="

# 1. 杀死常见冲突内核与守护进程
echo "[-] 正在清理残留的代理内核进程 (Mihomo/Clash/AirTCP/夜煞云/Sing-box/Xray等)..."
pkill -9 -f "mihomo" 2>/dev/null
pkill -9 -f "clash" 2>/dev/null
pkill -9 -f "verge-mihomo" 2>/dev/null
pkill -9 -f "clash-verge" 2>/dev/null
pkill -9 -f "yeshaCore" 2>/dev/null
pkill -9 -f "夜煞云" 2>/dev/null
pkill -9 -f "AirTCP" 2>/dev/null
pkill -9 -f "flybird" 2>/dev/null
pkill -9 -f "v2ray" 2>/dev/null
pkill -9 -f "xray" 2>/dev/null
pkill -9 -f "sing-box" 2>/dev/null
pkill -9 -f "karing" 2>/dev/null
pkill -9 -f "flclash" 2>/dev/null
pkill -9 -f "shadowrocket" 2>/dev/null
pkill -9 -f "v2rayn" 2>/dev/null

# 2. 获取所有网络硬件接口并关闭系统代理
echo "[+] 正在重置 macOS 网络服务代理配置..."
networksetup -listallnetworkservices 2>/dev/null | grep -v '^\*' | grep -v "An asterisk" | sed '/^$/d' | while IFS= read -r iface; do
    networksetup -setwebproxystate "$iface" off 2>/dev/null
    networksetup -setsecurewebproxystate "$iface" off 2>/dev/null
    networksetup -setsocksfirewallproxystate "$iface" off 2>/dev/null
    networksetup -setautoproxystate "$iface" off 2>/dev/null
    networksetup -setdnsservers "$iface" empty 2>/dev/null
done

# 3. 清理死锁 TUN 路由
echo "[+] 正在清理异常分流路由..."
sudo route -n delete 128.0/1 2>/dev/null || true
sudo route -n delete 0.0.0.0/1 2>/dev/null || true
sudo route -n delete 1/8 2>/dev/null || true
sudo route -n delete 198.18.0.0/15 2>/dev/null || true
sudo route -n delete 198.18.0.0/16 2>/dev/null || true

# 4. 刷新 DNS 缓存
echo "[+] 正在刷新系统 DNS 缓存..."
dscacheutil -flushcache 2>/dev/null
sudo killall -HUP mDNSResponder 2>/dev/null

echo "[✓] macOS 网络代理、死锁路由与进程清理完毕！"
