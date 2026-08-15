#!/usr/bin/env bash

# ==============================================================================
# VPN Doctor for macOS (全能网络与多 VPN 冲突体检及一键修复工具)
# ==============================================================================
# GitHub: https://github.com/Rouen007/vpn-troubleshooting-handbook
# 兼容客户端：
#   - Clash 系列: Clash Verge (Rev), ClashX, ClashX Pro, Clash Nyanpasu, Mihomo (Clash Meta)
#   - 机场定制专线: AirTCP, 夜煞云 (yeshaCore), Flybird (飞鸟), Kuromis
#   - 通用代理核心: Sing-box, Xray-core, V2Ray, V2rayU, Shadowsocks, Qv2ray, NekoRay
#   - 高级/企业 VPN: Surge, Tailscale, WireGuard, OpenVPN, ProtonVPN, Hysteria, TUIC
# ==============================================================================

# 设置颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# 常见代理/VPN 端口列表
COMMON_PORTS=(
    7890 7891 7892 7893 7895 7897 9090 9097  # Clash / ClashX / Mihomo / Verge
    6152 6153 6170 6171                       # Surge
    1080 1086 1087 10808 10809 10800 1082      # V2Ray / Xray / Shadowsocks / Qv2ray / V2rayU
    2080 2081 2088                            # Sing-box
    9191 50999                                # AirTCP
    53                                        # 本地 DNS (Fake-IP / Dnsmasq)
    51820                                     # WireGuard
)

# 常见代理进程与内核特征库（涵盖通用开源内核与各类定制/专线客户端）
PROXY_PROCESS_PATTERNS=(
    "clash" "clash-meta" "mihomo" "verge-mihomo" "clash-verge" "clash-verge-service" "ClashX" "ClashX Pro"
    "AirTCP" "airtcp" "Flybird" "flybird" "Yesha" "yeshaCore" "yeshayun" "夜煞云" "NekoRay" "V2rayU" "Qv2ray"
    "Surge" "surge" "sing-box" "v2ray" "xray" "v2fly" "shadowsocks" "ss-local" "ssr-local"
    "hysteria" "tuic" "trojan" "trojan-go" "naiveproxy" "juicity"
    "Tailscale" "tailscaled" "wireguard" "openvpn" "ProtonVPN"
    "Karing" "karing" "FlClash" "flclash" "shadowrocket" "v2rayn" "v2rayN"
)

# 清屏辅助
clear_screen() {
    printf "\033c" 2>/dev/null || /usr/bin/clear 2>/dev/null || true
}

# 打印横线
print_line() {
    echo -e "${CYAN}----------------------------------------------------------------------${NC}"
}

# 等待按键
pause_prompt() {
    if [ -t 0 ] && [ "$CLI_MODE" != "1" ]; then
        echo ""
        read -p "按回车键继续..." dummy
    fi
}

# 获取所有网络服务列表
get_network_services() {
    networksetup -listallnetworkservices 2>/dev/null | grep -v '^\*' | grep -v 'An asterisk' | sed '/^$/d'
}

# 获取主 Wi-Fi 设备名称（如 en0）
get_wifi_device() {
    networksetup -listallhardwareports 2>/dev/null | awk '/Hardware Port: Wi-Fi/{getline; print $2}' | head -n 1
}

# 检查单个端口占用
check_port() {
    local port=$1
    lsof -nP -iTCP:"$port" -sTCP:LISTEN 2>/dev/null
}

# 获取当前系统中所有运行的代理相关进程列表 (PID)
find_all_running_proxies() {
    local -a found_pids=()
    for pattern in "${PROXY_PROCESS_PATTERNS[@]}"; do
        local pids=$(pgrep -if "$pattern" 2>/dev/null)
        if [ -n "$pids" ]; then
            for pid in $pids; do
                if [ "$pid" != "$$" ] && [ "$pid" != "$PPID" ]; then
                    found_pids+=("$pid")
                fi
            done
        fi
    done
    echo "${found_pids[@]}" | tr ' ' '\n' | sort -u | grep -v '^$'
}

# 检查是否有活跃的系统代理设置
check_any_proxy_active() {
    local active_found=0
    while IFS= read -r service; do
        [ -z "$service" ] && continue
        local http_info=$(networksetup -getwebproxy "$service" 2>/dev/null)
        local https_info=$(networksetup -getsecurewebproxy "$service" 2>/dev/null)
        local socks_info=$(networksetup -getsocksfirewallproxy "$service" 2>/dev/null)
        local pac_info=$(networksetup -getautoproxyurl "$service" 2>/dev/null)
        if echo "$http_info $https_info $socks_info $pac_info" | grep -q "Enabled: Yes"; then
            active_found=1
            break
        fi
    done < <(get_network_services)
    echo $active_found
}

# 打印实时状态健康看板
print_header_with_status() {
    clear_screen
    echo -e "${BOLD}${CYAN}======================================================================${NC}"
    echo -e "${BOLD}${PURPLE}     🛠️  VPN Doctor - macOS 多 VPN / 机场软件冲突体检修复工具         ${NC}"
    echo -e "${BOLD}${CYAN}======================================================================${NC}"

    local is_proxy_active=$(check_any_proxy_active)
    local running_pids=($(find_all_running_proxies))
    local proxy_count=${#running_pids[@]}
    
    echo -e "${BOLD}[ 📊 系统实时网络状态看板 ]${NC}"
    if [ "$is_proxy_active" -eq 1 ]; then
        echo -e "  • 系统代理: ${RED}🔴 开启中 (可能存在死锁残留)${NC}"
    else
        echo -e "  • 系统代理: ${GREEN}🟢 直连模式 (无代理拦截)${NC}"
    fi

    if [ "$proxy_count" -eq 0 ]; then
        echo -e "  • 代理进程: ${GREEN}🟢 0 个运行中 (环境纯净)${NC}"
    elif [ "$proxy_count" -eq 1 ]; then
        echo -e "  • 代理进程: ${GREEN}🟢 1 个软件在运行${NC}"
    else
        echo -e "  • 代理进程: ${RED}🔴 $proxy_count 个内核在同时运行 (存在冲突争抢风险！)${NC}"
    fi

    local dns_status=$(networksetup -getdnsservers "Wi-Fi" 2>/dev/null | tr '\n' ' ')
    if echo "$dns_status" | grep -qE "127\.0\.0\.1|198\.18\."; then
        echo -e "  • Wi-Fi DNS: ${RED}🔴 Fake-IP / 本地死锁 (${dns_status})${NC}"
    elif echo "$dns_status" | grep -q "There aren't any DNS Servers"; then
        echo -e "  • Wi-Fi DNS: ${GREEN}🟢 自动获取 (DHCP)${NC}"
    else
        echo -e "  • Wi-Fi DNS: ${CYAN}🔵 自定义 (${dns_status})${NC}"
    fi

    print_line
    echo ""
}

# 1. 全面体检函数
run_diagnostic() {
    print_header_with_status
    echo -e "${BOLD}${BLUE}🔍 正在执行深度系统网络与多 VPN 状态体检...${NC}\n"

    local issue_count=0
    local warning_count=0

    # ---------------- 1.1 系统代理残留检测 ----------------
    echo -e "${BOLD}[ 1. 系统代理配置检测 ]${NC}"
    local active_proxies_found=0

    while IFS= read -r service; do
        [ -z "$service" ] && continue
        
        local http_info=$(networksetup -getwebproxy "$service" 2>/dev/null)
        local https_info=$(networksetup -getsecurewebproxy "$service" 2>/dev/null)
        local socks_info=$(networksetup -getsocksfirewallproxy "$service" 2>/dev/null)
        local pac_info=$(networksetup -getautoproxyurl "$service" 2>/dev/null)

        local has_proxy=0
        local proxy_details=""

        if echo "$http_info" | grep -q "Enabled: Yes"; then
            local server=$(echo "$http_info" | grep "Server:" | awk '{print $2}')
            local port=$(echo "$http_info" | grep "Port:" | awk '{print $2}')
            proxy_details+="  - HTTP 代理: ${server}:${port}\n"
            has_proxy=1
        fi

        if echo "$https_info" | grep -q "Enabled: Yes"; then
            local server=$(echo "$https_info" | grep "Server:" | awk '{print $2}')
            local port=$(echo "$https_info" | grep "Port:" | awk '{print $2}')
            proxy_details+="  - HTTPS 代理: ${server}:${port}\n"
            has_proxy=1
        fi

        if echo "$socks_info" | grep -q "Enabled: Yes"; then
            local server=$(echo "$socks_info" | grep "Server:" | awk '{print $2}')
            local port=$(echo "$socks_info" | grep "Port:" | awk '{print $2}')
            proxy_details+="  - SOCKS 代理: ${server}:${port}\n"
            has_proxy=1
        fi

        if echo "$pac_info" | grep -q "Enabled: Yes"; then
            local url=$(echo "$pac_info" | grep "URL:" | awk '{print $2}')
            proxy_details+="  - PAC 自动配置: ${url}\n"
            has_proxy=1
        fi

        if [ $has_proxy -eq 1 ]; then
            active_proxies_found=$((active_proxies_found + 1))
            echo -e "  🌐 网络服务: ${BOLD}${YELLOW}${service}${NC} [已开启代理]"
            echo -e "$proxy_details"
            
            if echo "$proxy_details" | grep -q "127.0.0.1"; then
                local target_port=$(echo "$proxy_details" | grep -o "127.0.0.1:[0-9]*" | head -n 1 | cut -d: -f2)
                if [ -n "$target_port" ]; then
                    local port_open=$(check_port "$target_port")
                    if [ -z "$port_open" ]; then
                        echo -e "    ${RED}⚠️  严重警告: 系统代理指向 127.0.0.1:${target_port}，但该端口无任何软件在运行！${NC}"
                        echo -e "    ${RED}👉 代理软件异常关闭后残留了系统代理，导致所有网页打不开。请执行「一键急救/换梯清场」。${NC}"
                        issue_count=$((issue_count + 1))
                    else
                        echo -e "    ${GREEN}✓ 代理目标端口 ${target_port} 正在运行监听${NC}"
                    fi
                fi
            fi
        else
            echo -e "  🌐 网络服务: ${service} -> ${GREEN}直连 (未开启代理)${NC}"
        fi
    done < <(get_network_services)

    echo ""

    # ---------------- 1.2 DNS 状态与异常检测 ----------------
    echo -e "${BOLD}[ 2. DNS 配置与解析检测 ]${NC}"
    while IFS= read -r service; do
        [ -z "$service" ] && continue
        local dns_servers=$(networksetup -getdnsservers "$service" 2>/dev/null)
        
        if echo "$dns_servers" | grep -q "There aren't any DNS Servers"; then
            echo -e "  📡 ${service} DNS: ${GREEN}自动获取 (DHCP 默认)${NC}"
        else
            local formatted_dns=$(echo "$dns_servers" | tr '\n' ' ')
            if echo "$formatted_dns" | grep -qE "127\.0\.0\.1|198\.18\."; then
                echo -e "  📡 ${service} DNS: ${RED}${formatted_dns} (检测到 Fake-IP / 本地 DNS 残留)${NC}"
                echo -e "    ${RED}⚠️  警告: 如果代理软件已退出，残留的 Fake-IP DNS 会导致无法解析域名。${NC}"
                issue_count=$((issue_count + 1))
            else
                echo -e "  📡 ${service} DNS: ${YELLOW}${formatted_dns}${NC}"
            fi
        fi
    done < <(get_network_services)

    # 测试 DNS 实际解析能力
    echo -n "  🔍 正在测试 DNS 解析 (baidu.com)... "
    local resolved_ip=""
    resolved_ip=$(dscacheutil -q host -a name www.baidu.com 2>/dev/null | grep -E "ip_address:" | head -n 1 | awk '{print $2}')
    if [ -z "$resolved_ip" ]; then
        resolved_ip=$(nslookup www.baidu.com 2>/dev/null | grep -E "Address:" | tail -n 1 | awk '{print $2}')
    fi

    if [ -n "$resolved_ip" ]; then
        echo -e "${GREEN}正常 (${resolved_ip})${NC}"
    else
        echo -e "${RED}无法解析域名 (可能处于离线或 DNS 异常)${NC}"
        issue_count=$((issue_count + 1))
    fi

    echo ""

    # ---------------- 1.3 代理端口占用与冲突检测 ----------------
    echo -e "${BOLD}[ 3. 常见 VPN/代理端口冲突检测 ]${NC}"
    local port_found=0
    for port in "${COMMON_PORTS[@]}"; do
        local result=$(check_port "$port")
        if [ -n "$result" ]; then
            port_found=1
            echo -e "  ⚡ ${BOLD}端口 :$port 处于监听状态${NC}"
            echo "$result" | awk 'NR>1 {printf "     ↳ 进程: \033[1;33m%-16s\033[0m PID: \033[1;36m%-7s\033[0m 用户: %-8s\n", $1, $2, $3}'
        fi
    done

    if [ $port_found -eq 0 ]; then
        echo -e "  🟢 常见代理端口均处于空闲状态，无冲突。"
    fi

    echo ""

    # ---------------- 1.4 运行中的 VPN / 代理进程 ----------------
    echo -e "${BOLD}[ 4. 运行中的代理相关软件与内核进程 ]${NC}"
    local running_pids=($(find_all_running_proxies))

    if [ ${#running_pids[@]} -gt 0 ]; then
        echo -e "  发现以下正在运行的代理进程 (共 ${#running_pids[@]} 个):"
        for pid in "${running_pids[@]}"; do
            local pname=$(ps -p "$pid" -o comm= 2>/dev/null)
            local user=$(ps -p "$pid" -o user= 2>/dev/null)
            printf "  - PID: ${CYAN}%-7s${NC} 用户: ${YELLOW}%-6s${NC} 进程: ${BOLD}%s${NC}\n" "$pid" "$user" "$pname"
        done
        
        if [ ${#running_pids[@]} -gt 2 ]; then
            echo -e "\n  ${RED}🔥 警告: 检测到后台存在多个 VPN / 代理内核同时运行！${NC}"
            echo -e "  ${YELLOW}👉 不同的 VPN（如 Clash、AirTCP、夜煞云、Flybird 等）如果同时争抢 TUN 网卡与 DNS，会导致无法上网。${NC}"
            echo -e "  ${YELLOW}💡 建议在主菜单执行「2. ⚡ 一键换梯清场 / 网络急救」重置环境。${NC}"
            warning_count=$((warning_count + 1))
        fi
    else
        echo -e "  🟢 未检测到主流代理软件后台进程。"
    fi

    echo ""

    # ---------------- 1.5 死锁路由与 TUN 虚拟网卡检测 ----------------
    echo -e "${BOLD}[ 5. 虚拟网卡 (utun) 与路由表检测 ]${NC}"
    local utun_list=$(ifconfig | grep -E "^utun[0-9]+" | cut -d: -f1 | tr '\n' ' ')
    if [ -n "$utun_list" ]; then
        echo -e "  当前活动的虚拟网卡: ${YELLOW}${utun_list}${NC}"
    else
        echo -e "  🟢 无活跃虚拟网卡。"
    fi

    local stuck_routes=$(netstat -nr -f inet 2>/dev/null | grep -E "utun[0-9]+" | grep -E "(128\.0|0\.0\.0|1/8|2/7)" | head -n 3)
    if [ -n "$stuck_routes" ]; then
        echo -e "  ${YELLOW}⚠️  检测到存在指向 utun 虚拟网卡的全局分流路由：${NC}"
        echo "$stuck_routes" | awk '{printf "     ↳ 目标: %-15s 网关: %-15s 网卡: %s\n", $1, $2, $6}'
        if [ ${#running_pids[@]} -eq 0 ]; then
            echo -e "  ${RED}🔥 严重异常: 代理软件已退出，但 utun 拦截路由依然残留！会导致彻底断网。${NC}"
            issue_count=$((issue_count + 1))
        fi
    fi

    echo ""

    # ---------------- 1.6 终端环境变量代理检测 ----------------
    echo -e "${BOLD}[ 6. 终端环境变量代理 (Terminal Proxy) ]${NC}"
    local env_http="${http_proxy:-$HTTP_PROXY}"
    local env_https="${https_proxy:-$HTTPS_PROXY}"
    local env_all="${all_proxy:-$ALL_PROXY}"
    if [ -n "$env_http" ] || [ -n "$env_https" ] || [ -n "$env_all" ]; then
        echo -e "  ${YELLOW}⚠️  当前终端已设置环境变量代理：${NC}"
        [ -n "$env_http" ] && echo -e "  - http_proxy : $env_http"
        [ -n "$env_https" ] && echo -e "  - https_proxy: $env_https"
        [ -n "$env_all" ] && echo -e "  - all_proxy  : $env_all"
    else
        echo -e "  🟢 终端环境变量无多余代理。"
    fi

    echo ""

    # ---------------- 1.7 /etc/hosts 劫持检测 ----------------
    echo -e "${BOLD}[ 7. /etc/hosts 域名劫持排查 ]${NC}"
    local suspicious_hosts=$(grep -v '^[[:space:]]*#' /etc/hosts 2>/dev/null | grep -v 'localhost' | grep -v 'broadcasthost' | sed '/^$/d')
    if [ -n "$suspicious_hosts" ]; then
        echo -e "  ${YELLOW}发现自定义 hosts 解析规则 (请确认是否为代理软件残留)：${NC}"
        echo "$suspicious_hosts" | head -n 5 | awk '{printf "  - %-16s %s\n", $1, $2}'
    else
        echo -e "  🟢 /etc/hosts 纯净，无异常条目。"
    fi

    echo ""
    print_line
    # 诊断总结
    if [ $issue_count -gt 0 ]; then
        echo -e "${BOLD}${RED}❌ 体检发现 $issue_count 个网络异常或残留问题！可能会导致无法正常上网。${NC}"
        echo -e "${BOLD}${YELLOW}👉 建议在主菜单选择「2. ⚡ 一键换梯清场 / 网络急救」进行自动修复。${NC}"
    elif [ $warning_count -gt 0 ]; then
        echo -e "${BOLD}${YELLOW}⚠️  网络配置正常，但存在多个代理进程共存，请留意切换时清场。${NC}"
    else
        echo -e "${BOLD}${GREEN}✅ 系统网络状态健康，无代理死锁或 DNS 异常问题！${NC}"
    fi
    print_line
    pause_prompt
}

# 2. 一键换梯清场 & 急救修复函数（通用版）
run_emergency_fix() {
    print_header_with_status
    echo -e "${BOLD}${YELLOW}⚡ 正在执行通用「一键换梯清场 & 网络急救」...${NC}"
    echo -e "${CYAN}（清除所有代理残留、重置 DNS、清理死锁路由、刷新系统缓存、终止后台冲突进程）${NC}\n"

    # 2.1 彻底终止所有 VPN / 代理进程与 root 内核
    echo -e "${BOLD}[步骤 1/5] 清理所有 VPN / 代理后台进程与 root 守护内核...${NC}"
    local pids_to_kill=($(find_all_running_proxies))

    if [ ${#pids_to_kill[@]} -gt 0 ]; then
        echo -e "  发现 ${#pids_to_kill[@]} 个正在运行的代理相关进程，正在清理..."
        for pid in "${pids_to_kill[@]}"; do
            sudo kill -9 "$pid" 2>/dev/null || kill -9 "$pid" 2>/dev/null
        done
        echo -e "  ${GREEN}✓ 所有冲突代理进程已终止。${NC}"
    else
        echo -e "  ${GREEN}✓ 无需清理的代理进程。${NC}"
    fi

    echo ""

    # 2.2 清除所有网络服务的代理设置
    echo -e "${BOLD}[步骤 2/5] 清空并关闭所有网络接口的代理设置 (恢复直连)...${NC}"
    while IFS= read -r service; do
        [ -z "$service" ] && continue
        echo -n "  - 正在重置 ${service}... "
        networksetup -setwebproxystate "$service" off 2>/dev/null
        networksetup -setsecurewebproxystate "$service" off 2>/dev/null
        networksetup -setsocksfirewallproxystate "$service" off 2>/dev/null
        networksetup -setautoproxystate "$service" off 2>/dev/null
        echo -e "${GREEN}已关闭代理${NC}"
    done < <(get_network_services)

    echo ""

    # 2.3 恢复 DNS 为系统默认 (DHCP)
    echo -e "${BOLD}[步骤 3/5] 重置 DNS 为自动获取 (清除 Fake-IP / 本地死锁 DNS)...${NC}"
    while IFS= read -r service; do
        [ -z "$service" ] && continue
        echo -n "  - 正在重置 ${service} DNS... "
        networksetup -setdnsservers "$service" empty 2>/dev/null
        echo -e "${GREEN}已恢复默认${NC}"
    done < <(get_network_services)

    echo ""

    # 2.4 清理死锁路由表
    echo -e "${BOLD}[步骤 4/5] 清理死锁的 utun 虚拟分流路由...${NC}"
    sudo route -n delete 128.0/1 2>/dev/null || true
    sudo route -n delete 0.0.0.0/1 2>/dev/null || true
    sudo route -n delete 1/8 2>/dev/null || true
    sudo route -n delete 198.18.0.0/15 2>/dev/null || true
    sudo route -n delete 198.18.0.0/16 2>/dev/null || true
    echo -e "  ${GREEN}✓ 异常分流路由已清理${NC}"

    echo ""

    # 2.5 刷新 macOS DNS 缓存
    echo -e "${BOLD}[步骤 5/5] 刷新 macOS 系统 DNS 缓存与 mDNSResponder...${NC}"
    dscacheutil -flushcache 2>/dev/null
    sudo killall -HUP mDNSResponder 2>/dev/null || killall -HUP mDNSResponder 2>/dev/null
    echo -e "  ${GREEN}✓ DNS 缓存已清空并重新初始化${NC}"

    echo ""
    print_line
    echo -e "${BOLD}${GREEN}🎉 清场与急救完成！系统网络已恢复纯净状态。${NC}"
    echo -e "${BOLD}${CYAN}👉 现在您可以直接打开并使用任何 VPN 软件（Clash、AirTCP、夜煞云、Flybird 等），绝不再冲突！${NC}"
    print_line
    echo ""
    echo "正在测试基础网络连通性..."
    if ping -c 2 -t 3 223.5.5.5 >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓ IP 连通性测试成功 (阿里 DNS 223.5.5.5 正常响应)${NC}"
    else
        echo -e "  ${RED}✗ IP 连通性异常，建议在主菜单尝试「7. 📶 Wi-Fi 软重启」${NC}"
    fi

    if curl -I -s --connect-timeout 3 https://www.baidu.com >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓ 网页访问测试成功 (百度正常连接)${NC}"
    else
        echo -e "  ${YELLOW}⚠️ 网页连接稍有延迟，建议稍等几秒或尝试选项 7${NC}"
    fi
    print_line
    pause_prompt
}

# 3. 单独重置所有代理
run_reset_proxy_only() {
    print_header_with_status
    echo -e "${BOLD}${BLUE}🌐 正在重置所有网络接口的代理设置...${NC}\n"
    while IFS= read -r service; do
        [ -z "$service" ] && continue
        echo -n "  - 正在关闭 ${service} 的 HTTP/HTTPS/SOCKS/PAC 代理... "
        networksetup -setwebproxystate "$service" off 2>/dev/null
        networksetup -setsecurewebproxystate "$service" off 2>/dev/null
        networksetup -setsocksfirewallproxystate "$service" off 2>/dev/null
        networksetup -setautoproxystate "$service" off 2>/dev/null
        echo -e "${GREEN}完成${NC}"
    done < <(get_network_services)
    
    echo -e "\n${GREEN}✅ 所有代理已全部关闭并恢复直连模式。${NC}\n"
    pause_prompt
}

# 4. 单独修复与切换 DNS
run_fix_dns_menu() {
    print_header_with_status
    echo -e "${BOLD}${BLUE}📡 DNS 修复与切换${NC}\n"
    echo "请选择要应用的 DNS 方案:"
    echo "  1) 恢复为路由器 DHCP 自动获取 (推荐，默认)"
    echo "  2) 设置为 阿里公共 DNS (223.5.5.5, 223.6.6.6) - 国内速度快"
    echo "  3) 设置为 腾讯 DNSPod (119.29.29.29, 182.254.116.116)"
    echo "  4) 设置为 Cloudflare & Google DNS (1.1.1.1, 8.8.8.8) - 国际防污染"
    echo "  0) 返回上级菜单"
    echo ""
    read -p "请输入选项 [0-4]: " dns_choice

    case "$dns_choice" in
        1)
            while IFS= read -r service; do
                [ -z "$service" ] && continue
                networksetup -setdnsservers "$service" empty 2>/dev/null
            done < <(get_network_services)
            echo -e "\n${GREEN}✓ 已重置为 DHCP 自动获取。${NC}"
            ;;
        2)
            while IFS= read -r service; do
                [ -z "$service" ] && continue
                networksetup -setdnsservers "$service" 223.5.5.5 223.6.6.6 2>/dev/null
            done < <(get_network_services)
            echo -e "\n${GREEN}✓ 已设置为 阿里 DNS (223.5.5.5, 223.6.6.6)。${NC}"
            ;;
        3)
            while IFS= read -r service; do
                [ -z "$service" ] && continue
                networksetup -setdnsservers "$service" 119.29.29.29 182.254.116.116 2>/dev/null
            done < <(get_network_services)
            echo -e "\n${GREEN}✓ 已设置为 腾讯 DNS (119.29.29.29)。${NC}"
            ;;
        4)
            while IFS= read -r service; do
                [ -z "$service" ] && continue
                networksetup -setdnsservers "$service" 1.1.1.1 8.8.8.8 2>/dev/null
            done < <(get_network_services)
            echo -e "\n${GREEN}✓ 已设置为 Cloudflare & Google DNS (1.1.1.1, 8.8.8.8)。${NC}"
            ;;
        0)
            return
            ;;
        *)
            echo -e "\n${RED}无效选项${NC}"
            ;;
    esac

    # 刷新缓存
    dscacheutil -flushcache 2>/dev/null
    sudo killall -HUP mDNSResponder 2>/dev/null || killall -HUP mDNSResponder 2>/dev/null
    echo -e "${GREEN}✓ DNS 缓存已同步刷新。${NC}\n"
    pause_prompt
}

# 5. 强制关闭所有 VPN / 代理软件
run_kill_all_proxies() {
    print_header_with_status
    echo -e "${BOLD}${RED}🚫 强制终止所有 VPN / 代理进程${NC}\n"
    echo "即将扫描并终止系统内运行的所有代理软件与内核..."
    echo ""
    local pids_to_kill=($(find_all_running_proxies))
    if [ ${#pids_to_kill[@]} -eq 0 ]; then
        echo -e "${GREEN}当前系统无运行中的代理进程。${NC}\n"
        pause_prompt
        return
    fi

    echo -e "发现以下 ${#pids_to_kill[@]} 个进程:"
    for pid in "${pids_to_kill[@]}"; do
        local pname=$(ps -p "$pid" -o comm= 2>/dev/null)
        echo -e "  - PID $pid : $pname"
    done
    echo ""
    read -p "确认全部强制关闭？(y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        local count=0
        for pid in "${pids_to_kill[@]}"; do
            sudo kill -9 "$pid" 2>/dev/null || kill -9 "$pid" 2>/dev/null
            count=$((count + 1))
        done
        echo -e "\n${GREEN}✅ 已强制终止 ${count} 个代理相关进程。${NC}"
    else
        echo -e "\n${YELLOW}已取消操作。${NC}"
    fi
    echo ""
    pause_prompt
}

# 6. 网络连通性深度测速与排查
run_connectivity_test() {
    print_header_with_status
    echo -e "${BOLD}${BLUE}📶 网络连通性与节点延迟测试${NC}\n"

    echo "正在测试国内基础连接..."
    echo -n "  - 阿里 DNS (223.5.5.5): "
    local ping_ali=$(ping -c 3 -t 3 223.5.5.5 2>/dev/null | tail -1 | awk '{print $4}' | cut -d/ -f2)
    if [ -n "$ping_ali" ]; then
        echo -e "${GREEN}连通 延迟: ${ping_ali} ms${NC}"
    else
        echo -e "${RED}无法连通${NC}"
    fi

    echo -n "  - 百度 (baidu.com): "
    local http_baidu=$(curl -o /dev/null -s -w "%{http_code} (%{time_total}s)" --connect-timeout 3 https://www.baidu.com)
    if [ -n "$http_baidu" ]; then
        echo -e "${GREEN}HTTP ${http_baidu}${NC}"
    else
        echo -e "${RED}超时或连接失败${NC}"
    fi

    echo ""
    echo "正在测试国际基础连接 (测试代理或直连外网状态)..."
    echo -n "  - Cloudflare (1.1.1.1): "
    local ping_cf=$(ping -c 3 -t 3 1.1.1.1 2>/dev/null | tail -1 | awk '{print $4}' | cut -d/ -f2)
    if [ -n "$ping_cf" ]; then
        echo -e "${GREEN}连通 延迟: ${ping_cf} ms${NC}"
    else
        echo -e "${YELLOW}无法直接 Ping 通 (可能受防火墙限制)${NC}"
    fi

    echo -n "  - GitHub (github.com): "
    local http_gh=$(curl -o /dev/null -s -w "%{http_code} (%{time_total}s)" --connect-timeout 4 https://github.com)
    if [ -n "$http_gh" ]; then
        echo -e "${GREEN}HTTP ${http_gh}${NC}"
    else
        echo -e "${YELLOW}无法直连 (需要开启代理)${NC}"
    fi

    echo -n "  - Google (google.com): "
    local http_gg=$(curl -o /dev/null -s -w "%{http_code} (%{time_total}s)" --connect-timeout 4 https://www.google.com)
    if [ -n "$http_gg" ]; then
        echo -e "${GREEN}HTTP ${http_gg}${NC}"
    else
        echo -e "${YELLOW}无法直连 (需要开启代理)${NC}"
    fi

    echo ""
    print_line
    pause_prompt
}

# 7. Wi-Fi 网卡软重启与 DHCP 重新获取 (终极底层修复)
run_bounce_wifi() {
    print_header_with_status
    echo -e "${BOLD}${BLUE}📶 Wi-Fi 网卡软重启 & DHCP 重新获取${NC}\n"
    local wifi_dev=$(get_wifi_device)
    if [ -z "$wifi_dev" ]; then
        wifi_dev="en0"
    fi
    echo "正在软重启 Wi-Fi 硬件网卡 ($wifi_dev)..."
    echo -n "  - 正在关闭 Wi-Fi... "
    networksetup -setairportpower "$wifi_dev" off 2>/dev/null
    sleep 1.5
    echo -e "${GREEN}已关闭${NC}"

    echo -n "  - 正在重新打开 Wi-Fi 并连接... "
    networksetup -setairportpower "$wifi_dev" on 2>/dev/null
    sleep 2.5
    echo -e "${GREEN}已开启${NC}"

    echo -n "  - 正在更新 DHCP 租约... "
    sudo ipconfig set "$wifi_dev" DHCP 2>/dev/null || true
    echo -e "${GREEN}完成${NC}"

    echo ""
    dscacheutil -flushcache 2>/dev/null
    sudo killall -HUP mDNSResponder 2>/dev/null || killall -HUP mDNSResponder 2>/dev/null

    echo -e "${GREEN}✅ Wi-Fi 物理网卡已完成软重启与重新握手！${NC}\n"
    pause_prompt
}

# 命令行非交互调用支持
if [ "$1" == "--check" ]; then
    CLI_MODE=1
    run_diagnostic
    exit 0
elif [ "$1" == "--fix" ] || [ "$1" == "--clean" ]; then
    CLI_MODE=1
    run_emergency_fix
    exit 0
elif [ "$1" == "--reset-proxy" ]; then
    CLI_MODE=1
    run_reset_proxy_only
    exit 0
elif [ "$1" == "--reset-dns" ]; then
    CLI_MODE=1
    run_fix_dns_menu
    exit 0
elif [ "$1" == "--bounce-wifi" ]; then
    CLI_MODE=1
    run_bounce_wifi
    exit 0
fi

# 主交互循环
while true; do
    print_header_with_status
    echo -e "${BOLD}请选择您需要执行的操作:${NC}\n"
    echo -e "  ${BOLD}${CYAN}1) 🔍 一键全面体检${NC}      (深度扫描网卡代理、DNS死锁、死锁路由、端口争抢)"
    echo -e "  ${BOLD}${GREEN}2) ⚡ 一键换梯清场 / 急救${NC} ${BOLD}${YELLOW}[核心推荐]${NC} (清掉旧内核、清空代理/DNS/路由、秒恢复纯净)"
    echo -e "  ${BOLD}3) 🌐 重置系统代理${NC}      (仅关闭所有网卡的 HTTP/HTTPS/SOCKS/PAC 代理)"
    echo -e "  ${BOLD}4) 📡 修复 & 切换 DNS${NC}   (重置为 DHCP 或切换阿里/腾讯/Google DNS)"
    echo -e "  ${BOLD}5) 🚫 强杀所有代理进程${NC}  (清理后台冲突的 Clash/AirTCP/夜煞云/Flybird 等)"
    echo -e "  ${BOLD}6) 📶 网络连通性测试${NC}    (测试国内/国际站点响应速度与状态)"
    echo -e "  ${BOLD}7) 🔄 Wi-Fi 网卡软重启${NC}   (解决底层网络栈/DHCP卡死，自动开关Wi-Fi)"
    echo -e "  ${BOLD}0) 退出工具${NC}"
    echo ""
    read -p "请输入选项编号 [0-7]: " choice

    case "$choice" in
        1) run_diagnostic ;;
        2) run_emergency_fix ;;
        3) run_reset_proxy_only ;;
        4) run_fix_dns_menu ;;
        5) run_kill_all_proxies ;;
        6) run_connectivity_test ;;
        7) run_bounce_wifi ;;
        0) 
            echo -e "\n感谢使用 VPN Doctor，再见！👋\n"
            exit 0
            ;;
        *)
            echo -e "\n${RED}输入错误，请重新选择！${NC}"
            sleep 1
            ;;
    esac
done
