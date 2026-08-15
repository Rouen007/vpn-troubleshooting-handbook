#!/usr/bin/env python3
"""
android_clean_vpn.py
ADB script to scan and force-stop conflicting Android VPN apps and reset system proxy.
"""

import subprocess
import sys
import argparse

KNOWN_VPN_PACKAGES = [
    "io.github.clashparticipant.flclash",
    "com.karing",
    "com.github.kr328.clash",
    "com.github.kr328.clash.foss",
    "com.github.metacubex.clash.meta",
    "com.v2ray.ang",
    "io.nekohasekai.sagernet",
    "moe.nb4a",
    "com.shadowsocks",
    "com.wireguard.android",
    "org.openvpn.openvpn"
]

def clean_android_vpns(device=None):
    base_cmd = ["adb"]
    if device:
        base_cmd.extend(["-s", device])
    
    print("[*] 正在扫描 Android 设备上的 VPN 客户端...")
    for pkg in KNOWN_VPN_PACKAGES:
        print(f"[-] 强制停止 (force-stop): {pkg}")
        subprocess.run(base_cmd + ["shell", "am", "force-stop", pkg], capture_output=True)
    
    print("[+] 正在重置 Android 全局 HTTP 代理设置...")
    subprocess.run(base_cmd + ["shell", "settings", "delete", "global", "http_proxy"], capture_output=True)
    subprocess.run(base_cmd + ["shell", "settings", "delete", "global", "global_http_proxy_host"], capture_output=True)
    subprocess.run(base_cmd + ["shell", "settings", "delete", "global", "global_http_proxy_port"], capture_output=True)
    print("[✓] Android 客户端冲突清理与代理重置完成！")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Clean Android VPN conflicts via ADB.")
    parser.add_argument("--device", help="ADB Device serial or IP:port (optional)")
    args = parser.parse_args()
    clean_android_vpns(args.device)
