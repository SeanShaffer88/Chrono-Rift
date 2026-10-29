[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$GodotPath
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$engine = (Resolve-Path -LiteralPath $GodotPath).Path
$logs = Join-Path $projectRoot '.godot/verification'
New-Item -ItemType Directory -Path $logs -Force | Out-Null
$version = (& $engine --version | Out-String).Trim()
$requiredVersion = (Get-Content -LiteralPath (Join-Path $projectRoot '.godot-version') -Raw).Trim()
if ($LASTEXITCODE -ne 0 -or $version -notmatch ('^' + [regex]::Escape($requiredVersion) + '\.stable\.')) {
    throw "Project requires Godot $requiredVersion-stable; received '$version'."
}

function Invoke-GodotCheck([string]$Name, [string[]]$EngineArguments, [int]$TimeoutSeconds, [switch]$RequireTestSuccess) {
    $logPath = Join-Path $logs "$Name.log"
    $info = [System.Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $engine
    $info.WorkingDirectory = $projectRoot
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    foreach ($argument in @('--headless', '--path', $projectRoot, '--log-file', $logPath) + $EngineArguments) {
        $info.ArgumentList.Add($argument)
    }
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $info
    try {
        [void]$process.Start()
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            $process.Kill($true)
            $process.WaitForExit()
            throw "$Name timed out after $TimeoutSeconds seconds."
        }
        $output = $stdout.GetAwaiter().GetResult() + $stderr.GetAwaiter().GetResult()
        $output | Set-Content -LiteralPath (Join-Path $logs "$Name.console.log")
        Write-Output $output
        if ($process.ExitCode -ne 0 -or $output -match 'SCRIPT ERROR|Parse Error|FAIL:|Test timed out') {
            throw "$Name failed. See $logs"
        }
        if ($output -match '(?m)^ERROR:') {
            throw "$Name emitted engine errors. See $logs"
        }
        if ($RequireTestSuccess -and $output -notmatch '--- Test Passed Successfully ---') {
            throw "$Name exited without its success marker."
        }
    } finally {
        $process.Dispose()
    }
}

Invoke-GodotCheck 'import' @('--editor', '--quit') 300
$tests = @(Get-ChildItem -LiteralPath (Join-Path $projectRoot 'tests') -Filter 'test_*.gd' |
    Where-Object Name -ne 'test_harness_template.gd' | Sort-Object Name)
if ($tests.Count -eq 0) { throw 'No executable tests found.' }
foreach ($test in $tests) {
    Invoke-GodotCheck $test.BaseName @('-s', $test.FullName) 120 -RequireTestSuccess
}
Write-Output "Verified $($tests.Count) test script(s) using $version. Logs: $logs"
