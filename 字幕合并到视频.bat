@echo off
setlocal enabledelayedexpansion
title 字幕内嵌工具 (基于 ffmpeg)

rem ========================================================
rem 用法:
rem   将"视频文件"和"srt字幕文件"一起选中，拖到本脚本图标上即可。
rem   - 若只拖了视频，会提示输入或拖入字幕文件路径。
rem   - 若只拖了字幕，会提示输入或拖入视频文件路径。
rem   - 若直接双击运行，会依次提示输入两个文件路径。
rem   处理结果会输出到视频文件所在目录。
rem
rem 注意:
rem   - 硬字幕模式要求文件路径中不包含单引号(')、逗号(,)等特殊符号。
rem   - 请确保已安装 ffmpeg 并已添加到系统 PATH 环境变量中。
rem ========================================================

where ffmpeg >nul 2>nul
if errorlevel 1 (
    echo [错误] 未检测到 ffmpeg，请先安装 ffmpeg 并将其添加到系统 PATH 环境变量。
    echo 下载地址: https://ffmpeg.org/download.html
    pause
    exit /b 1
)

set "VIDEO="
set "SRT="

:parse_args
if "%~1"=="" goto :after_parse
if /i "%~x1"==".srt" (
    if "%SRT%"=="" set "SRT=%~1"
) else (
    if "%VIDEO%"=="" set "VIDEO=%~1"
)
shift
goto :parse_args

:after_parse

if "%VIDEO%"=="" (
    echo 未检测到视频文件。
    set /p "VIDEO=请输入视频文件路径（也可将视频文件拖入此窗口后按回车）: "
    set "VIDEO=%VIDEO:"=%"
)

if "%SRT%"=="" (
    echo 未检测到字幕文件。
    set /p "SRT=请输入 SRT 字幕文件路径（也可将字幕文件拖入此窗口后按回车）: "
    set "SRT=%SRT:"=%"
)

if not exist "%VIDEO%" (
    echo [错误] 找不到视频文件: %VIDEO%
    pause
    exit /b 1
)

if not exist "%SRT%" (
    echo [错误] 找不到字幕文件: %SRT%
    pause
    exit /b 1
)

echo.
echo 视频文件: %VIDEO%
echo 字幕文件: %SRT%
echo.

echo 请选择字幕嵌入方式:
echo   [1] 硬字幕 - 将字幕烧录进画面，永久显示，兼容性最好（需要重新编码，速度较慢）
echo   [2] 软字幕 - 将字幕封装为独立轨道，可在播放器中开关/切换（速度快，输出为 mkv）
echo.
choice /c 12 /n /m "请输入选项 (1 或 2): "
set "MODE=%errorlevel%"
echo.

for %%F in ("%VIDEO%") do (
    set "VIDEO_DIR=%%~dpF"
    set "VIDEO_NAME=%%~nF"
    set "VIDEO_EXT=%%~xF"
)

if "%MODE%"=="1" (
    set "OUTPUT=%VIDEO_DIR%%VIDEO_NAME%_硬字幕%VIDEO_EXT%"
    set "SRT_ESC=%SRT:\=/%"
    set "SRT_ESC=!SRT_ESC::=\:!"
    echo 正在生成硬字幕视频，请稍候...
    ffmpeg -y -i "%VIDEO%" -vf "subtitles='!SRT_ESC!':force_style='FontName=Microsoft YaHei,FontSize=20'" -c:a copy "!OUTPUT!"
) else (
    set "OUTPUT=%VIDEO_DIR%%VIDEO_NAME%_软字幕.mkv"
    echo 正在封装软字幕，请稍候...
    ffmpeg -y -i "%VIDEO%" -i "%SRT%" -map 0 -map 1 -c copy -c:s srt "!OUTPUT!"
)

if errorlevel 1 (
    echo.
    echo [失败] 处理过程中出现错误，请检查上方日志。
) else (
    echo.
    echo [完成] 已生成: !OUTPUT!
)

echo.
pause
