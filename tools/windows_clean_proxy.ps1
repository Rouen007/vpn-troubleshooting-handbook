# windows_clean_proxy.ps1
# 一键清理 Windows 代理占用、杀死冲突进程并重置系统代理注册表

Write-Host "=================================================" -ForegroundColor Cyan
Write-Host " 🧹 Windows VPN / 代理冲突一键清理与网络重置工具" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

# 1. 检查并清理常用代理端口占用 (7890, 7897, 10808, 9090)
$ports = @(7890, 7897, 10808, 9090)
foreach ($port in $ports) {
    $connections = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
    if ($connections) {
        foreach ($conn in $connections) {
            $pidToKill = $conn.OwningProcess
            if ($pidToKill -gt 0) {
                Write-Host "[-] 发现端口 $port 被 PID $pidToKill 占用，正在释放..." -ForegroundColor Yellow
                Stop-Process -Id $pidToKill -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

# 2. 杀死常见的冲突代理进程
$procNames = @("clash", "mihomo", "v2ray", "xray", "sing-box", "flclash", "karing")
foreach ($name in $procNames) {
    $procs = Get-Process -Name $name -ErrorAction SilentlyContinue
    if ($procs) {
        Write-Host "[-] 正在停止冲突进程: $name ..." -ForegroundColor Yellow
        $procs | Stop-Process -Force -ErrorAction SilentlyContinue
    }
}

# 3. 重置系统代理设置
Write-Host "[+] 正在重置 Windows Internet Settings 系统代理注册表..." -ForegroundColor Green
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -Name ProxyEnable -Value 0
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -Name ProxyServer -Value ""

# 4. 刷新 DNS
Write-Host "[+] 正在刷新系统 DNS 缓存..." -ForegroundColor Green
Clear-DnsClientCache

Write-Host "`n[✓] 清理与重置完毕！网络连接已恢复正常。" -ForegroundColor Green
