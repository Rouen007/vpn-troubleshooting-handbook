#!/usr/bin/env bash

# ==============================================================================
# install_macos_desktop.sh
# 一键在 macOS 桌面安装 VPN Doctor（支持 .command 与 .app 双重启动器）
# ==============================================================================

DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_SOURCE="$DIR/macos_vpn_doctor.sh"
DESKTOP_DIR="$HOME/Desktop"

if [ ! -f "$SCRIPT_SOURCE" ]; then
    echo "[-] 未在同级目录找到 macos_vpn_doctor.sh，正在在线下载最新版本..."
    mkdir -p "$DIR"
    curl -fsSL https://raw.githubusercontent.com/Rouen007/vpn-troubleshooting-handbook/main/tools/macos_vpn_doctor.sh -o "$SCRIPT_SOURCE"
fi

chmod +x "$SCRIPT_SOURCE"

echo "================================================="
echo " 🚀 正在安装 VPN Doctor 到您的 macOS 桌面..."
echo "================================================="

# 1. 生成桌面 .command 快捷方式
COMMAND_TARGET="$DESKTOP_DIR/VPN冲突修复工具.command"
cat <<EOF > "$COMMAND_TARGET"
#!/usr/bin/env bash
printf "\033]0;VPN Doctor - macOS 网络与代理冲突修复工具\007"
if [ -f "$SCRIPT_SOURCE" ]; then
    bash "$SCRIPT_SOURCE"
else
    bash <(curl -fsSL https://raw.githubusercontent.com/Rouen007/vpn-troubleshooting-handbook/main/tools/macos_vpn_doctor.sh)
fi
EOF

chmod +x "$COMMAND_TARGET"
echo "[✓] 已生成桌面终端启动器: $COMMAND_TARGET"

# 2. 尝试编译为原生 .app 应用程序
APP_TARGET="$DESKTOP_DIR/VPN冲突修复工具.app"
if command -v osacompile >/dev/null 2>&1; then
    osacompile -e "tell application \"Terminal\" to do script \"bash \\\"$SCRIPT_SOURCE\\\"\"" -o "$APP_TARGET" 2>/dev/null
    if [ -d "$APP_TARGET" ]; then
        echo "[✓] 已生成桌面原生 App 应用程序: $APP_TARGET"
    fi
fi

echo ""
echo "🎉 安装完成！您现在可以直接在桌面双击「VPN冲突修复工具」使用了。"
