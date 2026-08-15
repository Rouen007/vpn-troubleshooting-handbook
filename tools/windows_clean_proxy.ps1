# ==============================================================================
# Windows VPN Doctor (PowerShell 全能网络与多 VPN 冲突体检及一键修复工具)
# ==============================================================================
# GitHub: https://github.com/Rouen007/vpn-troubleshooting-handbook
# 兼容客户端：
#   - Clash 系列: Clash Verge (Rev), Clash for Windows, Clash Nyanpasu, Mihomo
#   - 机场定制专线: AirTCP, 夜煞云 (yeshaCore), Flybird (飞鸟), Kuromis
#   - 通用代理: v2rayN, Xray, Sing-box, NekoBox, Karing, FlClash
#   - 企业/通用 VPN: Surge, Tailscale, WireGuard, OpenVPN, ProtonVPN
# ==============================================================================

#Requires -RunAsAdministrator

function Show-Header {
    Clear-Host
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host "     🛠️  Windows VPN Doctor - 全能网络与多 VPN 冲突体检修复工具         " -ForegroundColor Magenta
    Write-Host "======================================================================" -ForegroundColor Cyan
    
    # 快速检查当前代理状态
    $regPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
    $proxyEnable = (Get-ItemProperty -Path $regPath -Name ProxyEnable -ErrorAction SilentlyContinue).ProxyEnable
    $proxyServer = (Get-ItemProperty -Path $regPath -Name ProxyServer -ErrorAction SilentlyContinue).ProxyServer
    
    Write-Host "[ 📊 系统实时网络状态看板 ]" -ForegroundColor White
    if ($proxyEnable -eq 1) {
        Write-Host "  • 系统代理: 🔴 开启中 -> $proxyServer" -ForegroundColor Red
    } else {
        Write-Host "  • 系统代理: 🟢 直连模式 (无代理拦截)" -ForegroundColor Green
    }
    
    # 检查运行中的冲突进程数
    $patterns = @("clash*", "mihomo*", "*verge*", "*yesha*", "*airtcp*", "*flybird*", "v2ray*", "xray*", "sing-box*", "nekobox*", "flclash*", "*karing*", "*shadowrocket*", "*v2rayn*")
    $running = Get-Process | Where-Object { 
        $pname = $_.ProcessName
        $patterns | Where-Object { $pname -like $_ }
    }
    $count = ($running | Measure-Object).Count
    if ($count -gt 1) {
        Write-Host "  • 代理进程: 🔴 $count 个相关内核在后台运行 (存在多开冲突风险！)" -ForegroundColor Red
    } elseif ($count -eq 1) {
        Write-Host "  • 代理进程: 🟢 1 个软件在运行 ($($running[0].ProcessName))" -ForegroundColor Green
    } else {
        Write-Host "  • 代理进程: 🟢 0 个运行中 (环境纯净)" -ForegroundColor Green
    }
    Write-Host "----------------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host ""
}

function Run-Diagnostic {
    Show-Header
    Write-Host "[ 1. 系统代理与 WinHTTP 配置检测 ]" -ForegroundColor White
    $regPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
    $proxyEnable = (Get-ItemProperty -Path $regPath -Name ProxyEnable -ErrorAction SilentlyContinue).ProxyEnable
    $proxyServer = (Get-ItemProperty -Path $regPath -Name ProxyServer -ErrorAction SilentlyContinue).ProxyServer
    $autoConfig = (Get-ItemProperty -Path $regPath -Name AutoConfigURL -ErrorAction SilentlyContinue).AutoConfigURL
    
    if ($proxyEnable -eq 1) {
        Write-Host "  ⚠️  检测到已启用系统代理: $proxyServer" -ForegroundColor Yellow
        $parts = $proxyServer -split ':'
        if ($parts.Length -ge 2) {
            $port = [int]($parts[-1])
            $conn = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
            if (-not $conn) {
                Write-Host "  ❌ 严重警告: 代理指向端口 $port，但该端口无任何软件在监听！所有网页将无法打开。" -ForegroundColor Red
            } else {
                Write-Host "  ✓ 目标代理端口 $port 正在正常监听。" -ForegroundColor Green
            }
        }
    } else {
        Write-Host "  ✓ 系统代理未启用 (直连模式)。" -ForegroundColor Green
    }
    if ($autoConfig) {
        Write-Host "  ⚠️  检测到 PAC 自动配置脚本: $autoConfig" -ForegroundColor Yellow
    }

    Write-Host "`n[ 2. 常用代理端口占用检测 ]" -ForegroundColor White
    $commonPorts = @(7890, 7891, 7892, 7893, 7895, 7897, 1080, 10808, 10809, 9090, 9097, 9191, 50999)
    $portFound = $false
    foreach ($p in $commonPorts) {
        $conns = Get-NetTCPConnection -LocalPort $p -State Listen -ErrorAction SilentlyContinue
        if ($conns) {
            $portFound = $true
            foreach ($c in $conns) {
                $proc = Get-Process -Id $c.OwningProcess -ErrorAction SilentlyContinue
                Write-Host "  ⚡ 端口 :$p 处于监听状态 -> 进程: $($proc.ProcessName) (PID: $($c.OwningProcess))" -ForegroundColor Yellow
            }
        }
    }
    if (-not $portFound) {
        Write-Host "  🟢 常用代理端口均处于空闲状态。" -ForegroundColor Green
    }

    Write-Host "`n[ 3. 后台代理软件与 Windows 服务检测 ]" -ForegroundColor White
    $patterns = @("clash*", "mihomo*", "*verge*", "*yesha*", "*airtcp*", "*flybird*", "v2ray*", "xray*", "sing-box*", "nekobox*", "flclash*", "*karing*", "*shadowrocket*", "*v2rayn*")
    $running = Get-Process | Where-Object { 
        $pname = $_.ProcessName
        $patterns | Where-Object { $pname -like $_ }
    }
    if ($running) {
        Write-Host "  发现以下后台代理进程:"
        foreach ($r in $running) {
            Write-Host "  - PID: $($r.Id)`t 进程: $($r.ProcessName)" -ForegroundColor Cyan
        }
    } else {
        Write-Host "  🟢 未检测到活跃代理进程。" -ForegroundColor Green
    }

    # 检查 Windows 守护服务
    $services = Get-Service -Name "*clash*", "*mihomo*", "*verge*", "*nekobox*" -ErrorAction SilentlyContinue
    if ($services) {
        Write-Host "  发现以下 Windows 代理后台服务:"
        foreach ($s in $services) {
            Write-Host "  - 服务名: $($s.Name)`t 状态: $($s.Status)" -ForegroundColor Yellow
        }
    }

    Write-Host "`n[ 4. 路由表与 Wintun 虚拟网卡检测 ]" -ForegroundColor White
    $wintun = Get-NetAdapter | Where-Object { $_.InterfaceDescription -like "*Wintun*" -or $_.InterfaceDescription -like "*TAP*" }
    if ($wintun) {
        Write-Host "  发现活动虚拟网卡: $($wintun.Name) ($($wintun.Status))" -ForegroundColor Yellow
    } else {
        Write-Host "  🟢 无活跃 Wintun 虚拟网卡。" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "----------------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host "体检完成。按回车键返回主菜单..."
    Read-Host
}

function Run-EmergencyFix {
    Show-Header
    Write-Host "⚡ 正在执行通用「一键换梯清场 & 网络急救」..." -ForegroundColor Yellow
    Write-Host ""

    # 1. 终止所有代理后台进程
    Write-Host "[步骤 1/5] 强制终止所有代理后台进程与内核..." -ForegroundColor White
    $patterns = @("clash*", "mihomo*", "*verge*", "*yesha*", "*airtcp*", "*flybird*", "v2ray*", "xray*", "sing-box*", "nekobox*", "flclash*", "*karing*", "*shadowrocket*", "*v2rayn*")
    $running = Get-Process | Where-Object { 
        $pname = $_.ProcessName
        $patterns | Where-Object { $pname -like $_ }
    }
    if ($running) {
        foreach ($r in $running) {
            Write-Host "  - 正在停止进程: $($r.ProcessName) (PID: $($r.Id))..." -ForegroundColor Yellow
            Stop-Process -Id $r.Id -Force -ErrorAction SilentlyContinue
        }
        Write-Host "  ✓ 进程已全部终止。" -ForegroundColor Green
    } else {
        Write-Host "  ✓ 无需清理的代理进程。" -ForegroundColor Green
    }

    # 2. 停止相关 Windows 守护服务
    Write-Host "`n[步骤 2/5] 停止后台常驻 Windows 代理服务..." -ForegroundColor White
    $services = Get-Service -Name "*clash*", "*mihomo*", "*verge*", "*nekobox*" -ErrorAction SilentlyContinue
    if ($services) {
        foreach ($s in $services) {
            if ($s.Status -eq 'Running') {
                Write-Host "  - 正在停止服务: $($s.Name)..." -ForegroundColor Yellow
                Stop-Service -Name $s.Name -Force -ErrorAction SilentlyContinue
            }
        }
    }
    Write-Host "  ✓ 服务清理完成。" -ForegroundColor Green

    # 3. 重置注册表系统代理
    Write-Host "`n[步骤 3/5] 重置 Windows 注册表系统代理 (恢复直连)..." -ForegroundColor White
    $regPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
    Set-ItemProperty -Path $regPath -Name ProxyEnable -Value 0
    Set-ItemProperty -Path $regPath -Name ProxyServer -Value ""
    Remove-ItemProperty -Path $regPath -Name AutoConfigURL -ErrorAction SilentlyContinue
    
    # 重置 WinHTTP 代理
    netsh winhttp reset proxy | Out-Null
    Write-Host "  ✓ 系统代理已彻底关闭并恢复直连。" -ForegroundColor Green

    # 4. 清理死锁分流路由
    Write-Host "`n[步骤 4/5] 清理死锁的 Wintun 虚拟分流路由..." -ForegroundColor White
    route delete 0.0.0.0 mask 128.0.0.0 2>$null | Out-Null
    route delete 128.0.0.0 mask 128.0.0.0 2>$null | Out-Null
    Write-Host "  ✓ 分流路由已清理。" -ForegroundColor Green

    # 5. 刷新 DNS 缓存与重置 Winsock
    Write-Host "`n[步骤 5/5] 刷新系统 DNS 缓存..." -ForegroundColor White
    Clear-DnsClientCache
    ipconfig /flushdns | Out-Null
    Write-Host "  ✓ DNS 缓存已清空并重新初始化。" -ForegroundColor Green

    Write-Host ""
    Write-Host "----------------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host "🎉 清场与急救完成！系统网络已恢复纯净状态。" -ForegroundColor Green
    Write-Host "👉 现在您可以直接打开并使用任何 VPN 软件（Clash、AirTCP、夜煞云、Flybird 等），绝不再冲突！" -ForegroundColor Cyan
    Write-Host "----------------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host "按回车键返回主菜单..."
    Read-Host
}

# 交互主菜单循环
while ($true) {
    Show-Header
    Write-Host "请选择您需要执行的操作:"
    Write-Host "  1) 🔍 一键全面体检      (深度扫描注册表代理、DNS、端口占用、多开进程)" -ForegroundColor Cyan
    Write-Host "  2) ⚡ 一键换梯清场 / 急救 [核心推荐] (清掉旧内核、清空注册表/DNS/路由、秒恢复)" -ForegroundColor Green
    Write-Host "  3) 🌐 重置系统代理      (仅关闭 Windows 注册表与 WinHTTP 代理)"
    Write-Host "  4) 📡 刷新 DNS 缓存     (执行 Clear-DnsClientCache 与 ipconfig /flushdns)"
    Write-Host "  5) 🚫 强杀所有代理进程  (清理后台冲突的 Clash/AirTCP/夜煞云/Flybird 等)"
    Write-Host "  0) 退出工具"
    Write-Host ""
    $choice = Read-Host "请输入选项编号 [0-5]"

    switch ($choice) {
        "1" { Run-Diagnostic }
        "2" { Run-EmergencyFix }
        "3" {
            Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -Name ProxyEnable -Value 0
            Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -Name ProxyServer -Value ""
            netsh winhttp reset proxy | Out-Null
            Write-Host "`n✓ 系统代理已关闭！" -ForegroundColor Green
            Start-Sleep -Seconds 2
        }
        "4" {
            Clear-DnsClientCache
            ipconfig /flushdns | Out-Null
            Write-Host "`n✓ DNS 缓存已刷新！" -ForegroundColor Green
            Start-Sleep -Seconds 2
        }
        "5" {
            $patterns = @("clash*", "mihomo*", "*verge*", "*yesha*", "*airtcp*", "*flybird*", "v2ray*", "xray*", "sing-box*", "nekobox*", "flclash*", "*karing*", "*shadowrocket*", "*v2rayn*")
            Get-Process | Where-Object { $pname = $_.ProcessName; $patterns | Where-Object { $pname -like $_ } } | Stop-Process -Force -ErrorAction SilentlyContinue
            Write-Host "`n✓ 代理进程已全部终止！" -ForegroundColor Green
            Start-Sleep -Seconds 2
        }
        "0" {
            Write-Host "`n感谢使用 Windows VPN Doctor，再见！👋`n"
            exit
        }
        Default {
            Write-Host "`n输入错误，请重新选择！" -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
}
