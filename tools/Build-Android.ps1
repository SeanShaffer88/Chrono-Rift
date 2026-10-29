[CmdletBinding()]
param(
    [string]$GodotPath,
    [string]$JavaSdkPath,
    [string]$AndroidSdkPath,
    [string]$OutputPath
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$workspace = Split-Path $repo -Parent
if (-not $GodotPath) { $GodotPath = Join-Path $workspace 'work/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' }
if (-not $JavaSdkPath) { $JavaSdkPath = (Get-ChildItem (Join-Path $workspace 'work/jdk17') -Directory | Select-Object -First 1).FullName }
if (-not $AndroidSdkPath) { $AndroidSdkPath = Join-Path $workspace 'work/android-sdk' }
if (-not $OutputPath) { $OutputPath = Join-Path $workspace 'outputs/Chrono-Rift-debug.apk' }
$GodotPath = (Resolve-Path -LiteralPath $GodotPath).Path
$JavaSdkPath = (Resolve-Path -LiteralPath $JavaSdkPath).Path
$AndroidSdkPath = (Resolve-Path -LiteralPath $AndroidSdkPath).Path
$OutputPath = [System.IO.Path]::GetFullPath($OutputPath)
if ([System.IO.Path]::GetExtension($OutputPath) -ne '.apk') { throw 'Output must be an APK.' }
$settingsPath = Join-Path (Split-Path $GodotPath) 'editor_data/editor_settings-4.7.tres'
if (-not (Test-Path -LiteralPath $settingsPath)) { throw 'Use a portable Godot editor with an initialized editor_data directory.' }
$buildTools = Join-Path $AndroidSdkPath 'build-tools/36.0.0'
foreach ($tool in @((Join-Path $JavaSdkPath 'bin/java.exe'), (Join-Path $buildTools 'apksigner.bat'), (Join-Path $buildTools 'zipalign.exe'))) {
    if (-not (Test-Path -LiteralPath $tool)) { throw "Missing required tool: $tool" }
}

# Machine-specific SDK paths belong to portable editor settings, not the project.
$settings = Get-Content -LiteralPath $settingsPath -Raw
foreach ($entry in @(
    @{Key='export/android/java_sdk_path'; Value=$JavaSdkPath},
    @{Key='export/android/android_sdk_path'; Value=$AndroidSdkPath}
)) {
    $line = $entry.Key + ' = "' + $entry.Value.Replace('\', '/') + '"'
    $pattern = '(?m)^' + [regex]::Escape($entry.Key) + ' = .*\r?$'
    if ([regex]::IsMatch($settings, $pattern)) {
        $settings = [regex]::Replace($settings, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($match) $line })
    } else {
        $settings += "`n$line`n"
    }
}
Set-Content -LiteralPath $settingsPath -Value $settings -NoNewline
$previousJava = $env:JAVA_HOME
try {
    $env:JAVA_HOME = $JavaSdkPath
    # Dot sourcing runs the full test suite and shares its timed process/log checker.
    . (Join-Path $PSScriptRoot 'Test-Project.ps1') -GodotPath $GodotPath
    New-Item -ItemType Directory -Path (Split-Path $OutputPath) -Force | Out-Null
    if (Test-Path -LiteralPath $OutputPath) { Remove-Item -LiteralPath $OutputPath }
    Invoke-GodotCheck 'android-export' @('--export-debug', 'Android Debug', $OutputPath) 300
    if (-not (Test-Path -LiteralPath $OutputPath)) { throw 'Export produced no APK.' }
    & (Join-Path $buildTools 'apksigner.bat') verify --verbose $OutputPath
    if ($LASTEXITCODE -ne 0) { throw 'APK signature verification failed.' }
    & (Join-Path $buildTools 'zipalign.exe') -c -P 16 4 $OutputPath
    if ($LASTEXITCODE -ne 0) { throw 'APK 16 KB ZIP alignment verification failed.' }
    Get-FileHash -LiteralPath $OutputPath -Algorithm SHA256
} finally {
    $env:JAVA_HOME = $previousJava
}
