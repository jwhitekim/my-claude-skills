# Replace Git's usr\bin\bash.exe with a fresh copy of itself (identical bytes).
#
# Why: on some Windows PCs, launching this one file takes ~0.45 s every time, before bash
# even starts. The same bytes as sh.exe, or copied to another folder, start in ~0.05 s.
# Not antivirus scanning, prefetch, compatibility shims, file attributes or signatures
# (all checked 2026-09-23). A fresh copy of the file drops whatever Windows attached to the
# old one: 537 ms -> 55 ms, and swapping the old file back made it slow again.
# Claude Code runs every Bash command through this file, so each command pays that delay.
#
# What it does (needs admin - run by fix-slow-bash.sh through a UAC prompt):
#   1) back up bash.exe to -BackupDir
#   2) copy bash.exe -> bash.exe.new in the same folder
#   3) rename bash.exe -> bash.exe.old-<time>  (renaming works even while bash is running)
#   4) rename bash.exe.new -> bash.exe
#   5) time the new file; if it is not faster, put the old one back
# Output goes to -Out (ASCII, key=value lines). Windows PowerShell 5.1 reads a BOM-less
# script as the ANSI code page, so this file stays ASCII.
param(
    [Parameter(Mandatory=$true)][string]$Dir,
    [Parameter(Mandatory=$true)][string]$BackupDir,
    [Parameter(Mandatory=$true)][string]$Out
)
$ErrorActionPreference = 'Stop'
function Med([string]$exe) {
    $ms = @()
    for ($i = 0; $i -lt 9; $i++) { $ms += (Measure-Command { & $exe -c ':' | Out-Null }).TotalMilliseconds }
    $ms = $ms | Sort-Object
    return [int]$ms[4]
}
"start=1" | Out-File -Encoding ascii $Out
try {
    $bash = Join-Path $Dir 'bash.exe'
    if (-not (Test-Path $bash)) { throw "no bash.exe in $Dir" }
    New-Item -ItemType Directory -Force $BackupDir | Out-Null
    Copy-Item $bash (Join-Path $BackupDir 'bash.exe') -Force
    "backup=$BackupDir" | Out-File -Encoding ascii -Append $Out
    $before = Med $bash
    "before_ms=$before" | Out-File -Encoding ascii -Append $Out
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $new = Join-Path $Dir 'bash.exe.new'
    $oldName = "bash.exe.old-$stamp"
    Copy-Item $bash $new -Force
    Rename-Item $bash $oldName
    Rename-Item $new 'bash.exe'
    & $bash -c ':' | Out-Null
    $after = Med $bash
    "after_ms=$after" | Out-File -Encoding ascii -Append $Out
    if ($after -ge $before * 0.7) {
        Remove-Item $bash -Force
        Rename-Item (Join-Path $Dir $oldName) 'bash.exe'
        "result=reverted" | Out-File -Encoding ascii -Append $Out
    } else {
        "result=replaced" | Out-File -Encoding ascii -Append $Out
        "old=$oldName" | Out-File -Encoding ascii -Append $Out
    }
} catch {
    "error=$($_.Exception.Message)" | Out-File -Encoding ascii -Append $Out
    $bash = Join-Path $Dir 'bash.exe'
    $olds = Get-ChildItem (Join-Path $Dir 'bash.exe.old-*') -ErrorAction SilentlyContinue | Sort-Object Name | Select-Object -Last 1
    if (-not (Test-Path $bash) -and $olds) { Rename-Item $olds.FullName 'bash.exe'; "restored=1" | Out-File -Encoding ascii -Append $Out }
}
"end=1" | Out-File -Encoding ascii -Append $Out
