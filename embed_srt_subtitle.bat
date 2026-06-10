@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
title SRT 字幕内嵌工具 (基于 ffmpeg)

rem ========================================================
rem 用法:
rem   将一个或多个视频文件拖到本脚本图标上即可运行。
rem   脚本会自动查找与视频同名的 .srt 字幕文件并嵌入。
rem   例如: movie.mp4 会自动匹配同目录下的 movie.srt
rem
rem 注意:
rem   - 硬字幕模式要求视频/字幕路径中不包含单引号(')、逗号(,)等特殊符号。
rem   - 请确保已安装 ffmpeg 并已添加到系统 PATH 环境变量中。
rem ========================================================

where ffmpeg >nul 2>nul
if errorlevel 1 (
    echo [错误] 未检测到 ffmpeg，请先安装 ffmpeg 并将其添加到系统 PATH 环境变量。
    echo 下载地址: https://ffmpeg.org/download.html
    pause
    exit /b 1
)

if "%~1"=="" (
    echo 用法: 将一个或多个视频文件拖到本脚本图标上运行。
    echo 脚本会自动查找同名的 .srt 字幕文件并嵌入到视频中。
    echo.
    pause
    exit /b 0
)

echo 请选择字幕嵌入方式:
echo   [1] 硬字幕 - 将字幕烧录进画面，永久显示，兼容性最好（需要重新编码，速度较慢）
echo   [2] 软字幕 - 将字幕封装为独立轨道，可在播放器中开关/切换（速度快，输出为 mkv）
echo.
choice /c 12 /n /m "请输入选项 (1 或 2): "
set "MODE=%errorlevel%"
echo.

:loop
if "%~1"=="" goto :done

set "VIDEO=%~1"
set "VIDEO_DIR=%~dp1"
set "VIDEO_NAME=%~n1"
set "VIDEO_EXT=%~x1"
set "SRT=%VIDEO_DIR%%VIDEO_NAME%.srt"

echo ============================================
echo 正在处理: %VIDEO_NAME%%VIDEO_EXT%

if not exist "%SRT%" (
    echo [跳过] 未找到匹配的字幕文件: %SRT%
    echo.
    shift
    goto :loop
)

if "%MODE%"=="1" (
    set "OUTPUT=%VIDEO_DIR%%VIDEO_NAME%_硬字幕%VIDEO_EXT%"
    set "SRT_ESC=%SRT:\=/%"
    set "SRT_ESC=!SRT_ESC::=\:!"
    ffmpeg -y -i "%VIDEO%" -vf "subtitles='!SRT_ESC!':force_style='FontName=Microsoft YaHei,FontSize=20'" -c:a copy "!OUTPUT!"
) else (
    set "OUTPUT=%VIDEO_DIR%%VIDEO_NAME%_软字幕.mkv"
    ffmpeg -y -i "%VIDEO%" -i "%SRT%" -map 0 -map 1 -c copy -c:s srt "!OUTPUT!"
)

if errorlevel 1 (
    echo [失败] %VIDEO_NAME%%VIDEO_EXT% 处理出错，请检查上方日志。
) else (
    echo [完成] 已生成: !OUTPUT!
)
echo.

shift
goto :loop

:done
echo ============================================
echo 全部任务处理完成。
pause
