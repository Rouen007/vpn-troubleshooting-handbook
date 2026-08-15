@echo off
:: Windows VPN Doctor Launcher (双击以管理员身份运行)
chcp 65001 >nul
title Windows VPN Doctor - 网络与代理冲突修复工具

:: 请求管理员权限
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [!] 正在请求管理员权限以修复系统网络配置与路由表...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: 启动 PowerShell 修复脚本
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0windows_clean_proxy.ps1"
pause
