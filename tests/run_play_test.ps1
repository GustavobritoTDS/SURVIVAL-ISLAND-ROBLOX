# Teste de ponta a ponta em modo Play no Roblox Studio (Windows).
# Abre o place de teste, pressiona F5, espera o relatório do harness no log do Studio e fecha.
# Uso: powershell -ExecutionPolicy Bypass -File tests/run_play_test.ps1
param([int]$TimeoutSec = 240)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$env:Path = "$env:USERPROFILE\.rokit\bin;$env:Path"
Set-Location $root
rojo build test.project.json -o build/SurvivalIslandTest.rbxlx | Out-Null

$studio = Get-ChildItem "$env:LOCALAPPDATA\Roblox\Versions" -Recurse -Filter RobloxStudioBeta.exe | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$logDir = "$env:LOCALAPPDATA\Roblox\logs"
$start = Get-Date
$place = (Resolve-Path build/SurvivalIslandTest.rbxlx).Path
$proc = Start-Process -FilePath $studio.FullName -ArgumentList "`"$place`"" -PassThru

Add-Type @"
using System; using System.Runtime.InteropServices;
public class Win { [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h); [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
[DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y); [DllImport("user32.dll")] public static extern void mouse_event(int f, int dx, int dy, int d, int e); }
"@
# Posição do botão Play (▶) com o Studio maximizado em 1366x768; ajuste se a tela for diferente
$PlayX = 186; $PlayY = 68
$wshell = New-Object -ComObject WScript.Shell

function Get-StudioLog {
    Get-ChildItem $logDir -Filter "*Studio*.log" | Where-Object { $_.LastWriteTime -ge $start } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

# Espera o Studio carregar o place (aparece no log)
$loaded = $false
for ($i = 0; $i -lt 90; $i++) {
    Start-Sleep -Seconds 2
    $log = Get-StudioLog
    if ($log -and (Select-String -Path $log.FullName -Pattern "SurvivalIslandTest|DataModel Loading|Ribbon" -Quiet)) { $loaded = $true; break }
}
Start-Sleep -Seconds 12

$pressed = $false
for ($try = 0; $try -lt 4 -and -not $pressed; $try++) {
    $proc.Refresh()
    $h = $proc.MainWindowHandle
    if ($h -ne [IntPtr]::Zero) {
        [Win]::ShowWindow($h, 3) | Out-Null
        [Win]::SetForegroundWindow($h) | Out-Null
        Start-Sleep -Milliseconds 800
        [Win]::SetCursorPos($PlayX, $PlayY) | Out-Null
        Start-Sleep -Milliseconds 150
        [Win]::mouse_event(0x0002, 0, 0, 0, 0); Start-Sleep -Milliseconds 60; [Win]::mouse_event(0x0004, 0, 0, 0, 0)
        $pressed = $true
    } else { Start-Sleep -Seconds 5 }
}
Write-Output "Studio carregado: $loaded / F5 enviado: $pressed"

$report = $null
$deadline = (Get-Date).AddSeconds($TimeoutSec)
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 3
    $log = Get-StudioLog
    if ($log) {
        $text = Get-Content $log.FullName -Raw -ErrorAction SilentlyContinue
        if ($text -match "Erros no log do servidor") { $report = $log; break }
    }
}

$logs = Get-ChildItem $logDir -Filter "*.log" | Where-Object { $_.LastWriteTime -ge $start }
foreach ($l in $logs) {
    Select-String -Path $l.FullName -Pattern "CreatorOutput" | ForEach-Object {
        $line = $_.Line -replace '^.*?\[FLog::CreatorOutput\]\s*', ''
        if ($line -match "e2e|PASSOU|FALHOU|erro|Error|Survival Island|WorldService|Resource\]|Data\]|Main\]|Cliente|Fx\]") { $line }
    }
}
if (-not $report) { Write-Output "TIMEOUT: relatório não encontrado" }

# Encerra o Studio sem salvar
Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue

