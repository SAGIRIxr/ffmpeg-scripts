@echo off
setlocal enabledelayedexpansion
title 字幕内嵌工具 (基于 ffmpeg)

rem ========================================================
rem 用法:
rem   将"视频文件"和"一个或多个 srt 字幕文件"一起选中，拖到本脚本图标上。
rem   - 拖入几条字幕，软字幕模式就会封进几条（各自独立成轨、可切换）。
rem   - 若只拖了视频，会提示输入或拖入一条字幕文件路径。
rem   - 若只拖了字幕，会提示输入或拖入视频文件路径。
rem   - 若直接双击运行，会依次提示输入文件路径。
rem   处理结果会输出到视频文件所在目录。
rem
rem 功能:
rem   - 软字幕封装时会自动识别每条字幕的语言并写入轨道语言标记
rem     （如简体中文标记为 Chinese Simplified）。
rem   - 无法自动识别时，会提示手动选择语言，不会留下 unknown。
rem   - 硬字幕模式只能烧录一条字幕到画面；多条时会让你选择其中一条。
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
set /a SRTCOUNT=0

:parse_args
if "%~1"=="" goto :after_parse
if /i "%~x1"==".srt" (
    set /a SRTCOUNT+=1
    set "SRT_!SRTCOUNT!=%~1"
) else (
    if not defined VIDEO set "VIDEO=%~1"
)
shift
goto :parse_args

:after_parse

if not defined VIDEO call :ask_video
if %SRTCOUNT%==0 call :ask_sub

if not exist "%VIDEO%" (
    echo [错误] 找不到视频文件: %VIDEO%
    pause
    exit /b 1
)

for /L %%i in (1,1,%SRTCOUNT%) do (
    if not exist "!SRT_%%i!" (
        echo [错误] 找不到字幕文件: !SRT_%%i!
        pause
        exit /b 1
    )
)

echo.
echo 视频文件: %VIDEO%
echo 字幕文件（共 %SRTCOUNT% 条）:
for /L %%i in (1,1,%SRTCOUNT%) do call echo   %%i. %%SRT_%%i%%
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

if "%MODE%"=="1" goto :do_hard
goto :do_soft


rem ========================================================
rem 硬字幕：烧录一条字幕到画面
rem ========================================================
:do_hard
set "BURN=!SRT_1!"
if %SRTCOUNT% GTR 1 call :pick_burn
set "OUTPUT=%VIDEO_DIR%%VIDEO_NAME%_硬字幕%VIDEO_EXT%"
set "SRT_ESC=!BURN:\=/!"
set "SRT_ESC=!SRT_ESC::=\:!"
echo 正在生成硬字幕视频，请稍候...
ffmpeg -y -i "%VIDEO%" -vf "subtitles='!SRT_ESC!':force_style='FontName=Microsoft YaHei,FontSize=20'" -c:a copy "!OUTPUT!"
goto :after_run


rem ========================================================
rem 软字幕：把所有字幕逐条封装为独立轨道
rem ========================================================
:do_soft
set "OUTPUT=%VIDEO_DIR%%VIDEO_NAME%_软字幕.mkv"
set "INPUTS="
set "MAPS=-map 0"
set "METAS="
set /a SUBIDX=0
for /L %%i in (1,1,%SRTCOUNT%) do (
    set "CUR=!SRT_%%i!"
    echo.
    echo 字幕 %%i: !CUR!
    call :detect_lang "!CUR!"
    set INPUTS=!INPUTS! -i "!CUR!"
    set MAPS=!MAPS! -map %%i
    set METAS=!METAS! -metadata:s:s:!SUBIDX! language=!LANGCODE! -metadata:s:s:!SUBIDX! "title=!LANGTITLE!"
    set /a SUBIDX+=1
)
echo.
echo 正在封装 %SRTCOUNT% 条软字幕，请稍候...
ffmpeg -y -i "%VIDEO%" !INPUTS! !MAPS! -c copy -c:s srt !METAS! "!OUTPUT!"
goto :after_run


:after_run
if errorlevel 1 (
    echo.
    echo [失败] 处理过程中出现错误，请检查上方日志。
) else (
    echo.
    echo [完成] 已生成: !OUTPUT!
)
echo.
pause
exit /b 0


rem ========================================================
rem 子程序：提示输入视频
rem ========================================================
:ask_video
echo 未检测到视频文件。
set /p "VIDEO=请输入视频文件路径（也可将视频文件拖入此窗口后按回车）: "
set "VIDEO=%VIDEO:"=%"
goto :eof


rem ========================================================
rem 子程序：提示输入一条字幕
rem ========================================================
:ask_sub
echo 未检测到字幕文件。
set /p "S=请输入 SRT 字幕文件路径（也可将字幕文件拖入此窗口后按回车）: "
set "S=%S:"=%"
set "SRT_1=%S%"
set /a SRTCOUNT=1
goto :eof


rem ========================================================
rem 子程序：硬字幕模式下选择要烧录的一条字幕
rem ========================================================
:pick_burn
echo 硬字幕模式只能将一条字幕烧录进画面，检测到 %SRTCOUNT% 条字幕:
for /L %%i in (1,1,%SRTCOUNT%) do call echo   [%%i] %%SRT_%%i%%
set /p "PICK=请选择要烧录的字幕序号 (1-%SRTCOUNT%): "
set "BURN=!SRT_%PICK%!"
if not defined BURN set "BURN=!SRT_1!"
goto :eof


rem ========================================================
rem 子程序：识别字幕语言，设置 LANGCODE / LANGTITLE
rem   参数 %1 = 字幕文件路径
rem ========================================================
:detect_lang
set "LANGCODE="
set "LANGTITLE="
set "SRTFILE=%~1"
set "DETECTOUT=%TEMP%\sublang_detect.txt"
if exist "%DETECTOUT%" del "%DETECTOUT%" >nul 2>nul
echo 正在识别字幕语言...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='SilentlyContinue'; $p=$env:SRTFILE; $o=$env:DETECTOUT; $bytes=[System.IO.File]::ReadAllBytes($p); $t=''; try { $u=New-Object System.Text.UTF8Encoding($false,$true); $t=$u.GetString($bytes) } catch { $t=[System.Text.Encoding]::GetEncoding(936).GetString($bytes) }; $kana=0;$hang=0;$cjk=0;$lat=0;$simp=0;$trad=0; $S=@(0x56FD,0x8FD9,0x4EEC,0x6765,0x65F6,0x4F1A,0x4E2A,0x8BF4,0x5BF9,0x5B66,0x5B9E,0x73B0,0x53D1,0x7ECF,0x8FC7,0x8FD8,0x5E94,0x5F53,0x8FDB,0x6837,0x5173,0x70B9,0x89C1,0x8BA9,0x8FB9,0x4E1C,0x8F66,0x4E66,0x957F,0x95E8,0x95EE,0x95F4,0x9A6C,0x98CE,0x98DE,0x9F99,0x7231,0x89C9,0x4E60,0x5199); $T=@(0x570B,0x9019,0x5011,0x4F86,0x6642,0x6703,0x500B,0x8AAA,0x5C0D,0x5B78,0x5BE6,0x73FE,0x767C,0x7D93,0x904E,0x9084,0x61C9,0x7576,0x9032,0x6A23,0x95DC,0x9EDE,0x898B,0x8B93,0x908A,0x6771,0x8ECA,0x66F8,0x9577,0x9580,0x554F,0x9593,0x99AC,0x98A8,0x98DB,0x9F8D,0x611B,0x89BA,0x7FD2,0x5BEB); foreach($ch in $t.ToCharArray()){ $c=[int][char]$ch; if($c -ge 0x3040 -and $c -le 0x30FF){$kana++} elseif(($c -ge 0xAC00 -and $c -le 0xD7A3) -or ($c -ge 0x1100 -and $c -le 0x11FF)){$hang++} elseif(($c -ge 0x4E00 -and $c -le 0x9FFF) -or ($c -ge 0x3400 -and $c -le 0x4DBF)){$cjk++; if($S -contains $c){$simp++}; if($T -contains $c){$trad++}} elseif(($c -ge 0x41 -and $c -le 0x5A) -or ($c -ge 0x61 -and $c -le 0x7A)){$lat++} }; $r='unknown'; if($hang -gt 0){$r='kor'} elseif($kana -gt 0){$r='jpn'} elseif($cjk -gt 0){ if($trad -gt $simp){$r='zht'} elseif($simp -gt $trad){$r='zhs'} else{$r='zhx'} } elseif($lat -gt 0){$r='eng'}; Set-Content -LiteralPath $o -Value $r -Encoding ASCII -NoNewline" >nul 2>nul
set "DETECT=unknown"
if exist "%DETECTOUT%" set /p DETECT=<"%DETECTOUT%"
if exist "%DETECTOUT%" del "%DETECTOUT%" >nul 2>nul
if /i "!DETECT!"=="zhs" ( set "LANGCODE=chi" & set "LANGTITLE=Chinese Simplified" & echo 已识别: 简体中文 [Chinese Simplified] )
if /i "!DETECT!"=="zht" ( set "LANGCODE=chi" & set "LANGTITLE=Chinese Traditional" & echo 已识别: 繁体中文 [Chinese Traditional] )
if /i "!DETECT!"=="jpn" ( set "LANGCODE=jpn" & set "LANGTITLE=Japanese" & echo 已识别: 日语 [Japanese] )
if /i "!DETECT!"=="kor" ( set "LANGCODE=kor" & set "LANGTITLE=Korean" & echo 已识别: 韩语 [Korean] )
if /i "!DETECT!"=="eng" ( set "LANGCODE=eng" & set "LANGTITLE=English" & echo 已识别: 英语 [English] )
if /i "!DETECT!"=="zhx" ( echo 检测到中文，但无法判断简繁，请手动选择。& call :pick_cn )
if "!LANGCODE!"=="" ( echo 无法自动识别字幕语言，请手动选择。& call :manual_lang )
if "!LANGCODE!"=="" ( set "LANGCODE=und" & set "LANGTITLE=Undetermined" )
goto :eof


rem ========================================================
rem 子程序：中文简繁手动选择
rem ========================================================
:pick_cn
choice /c 12 /n /m "请选择 [1]简体中文 [2]繁体中文: "
set "C=!errorlevel!"
if "!C!"=="1" ( set "LANGCODE=chi" & set "LANGTITLE=Chinese Simplified" )
if "!C!"=="2" ( set "LANGCODE=chi" & set "LANGTITLE=Chinese Traditional" )
goto :eof


rem ========================================================
rem 子程序：手动选择语言
rem ========================================================
:manual_lang
echo.
echo 请手动选择字幕语言:
echo   [1] 简体中文 Chinese Simplified
echo   [2] 繁体中文 Chinese Traditional
echo   [3] 英语 English
echo   [4] 日语 Japanese
echo   [5] 韩语 Korean
echo   [6] 其他（手动输入语言代码与名称）
choice /c 123456 /n /m "请输入选项 (1-6): "
set "C=!errorlevel!"
if "!C!"=="1" ( set "LANGCODE=chi" & set "LANGTITLE=Chinese Simplified" )
if "!C!"=="2" ( set "LANGCODE=chi" & set "LANGTITLE=Chinese Traditional" )
if "!C!"=="3" ( set "LANGCODE=eng" & set "LANGTITLE=English" )
if "!C!"=="4" ( set "LANGCODE=jpn" & set "LANGTITLE=Japanese" )
if "!C!"=="5" ( set "LANGCODE=kor" & set "LANGTITLE=Korean" )
if "!C!"=="6" (
    set /p "LANGCODE=请输入 ISO 639-2 语言代码（如 fre/ger/spa/rus）: "
    set /p "LANGTITLE=请输入语言名称（如 French）: "
)
goto :eof
