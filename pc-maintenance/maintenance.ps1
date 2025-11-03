# ===============================================
# Author: Gabriel Peterossi Maricato and IA
# PowerShell PC Maintenance Script
# Clean, Speed Up, and Protect Privacy
# ===============================================

Write-Host "Starting system maintenance and privacy cleanup..." -ForegroundColor Cyan
Start-Sleep -Seconds 2

# --- Function to safely remove files ---
function Safe-Remove($path) {
    if (Test-Path $path) {
        try {
            Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "Removed: $path"
        } catch {
            Write-Host "Failed to remove: $path" -ForegroundColor Yellow
        }
    }
}

# --- Clear Temp Files ---
Write-Host "`nClearing Temporary Files..." -ForegroundColor Green
Safe-Remove "$env:TEMP\*"
Safe-Remove "C:\Windows\Temp\*"

# --- Clear Prefetch ---
Write-Host "Clearing Prefetch Data..." -ForegroundColor Green
Safe-Remove "C:\Windows\Prefetch\*"

# --- Clear Windows Update Cache ---
Write-Host "Clearing Windows Update Cache..." -ForegroundColor Green
Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
Safe-Remove "C:\Windows\SoftwareDistribution\Download\*"
Start-Service wuauserv -ErrorAction SilentlyContinue

# --- Clear Event Logs ---
#Write-Host "Clearing Event Logs..." -ForegroundColor Green
#wevtutil el | ForEach-Object { wevtutil cl $_ } | Out-Null

#wevtutil sl Microsoft-Windows-LiveId/Analytic /e:true
#wevtutil cl Microsoft-Windows-LiveId/Analytic
#wevtutil sl Microsoft-Windows-LiveId/Analytic /e:false


# --- Clear DNS Cache ---
Write-Host "Flushing DNS Cache..." -ForegroundColor Green
ipconfig /flushdns | Out-Null

# --- Clear Clipboard ---
Write-Host "Clearing Clipboard..." -ForegroundColor Green
cmd /c "echo off | clip"

# --- Optional: Disable Telemetry and Data Collection ---
Write-Host "`nDisabling Windows Telemetry (optional)..." -ForegroundColor Yellow
try {
    Set-Service "DiagTrack" -StartupType Disabled -ErrorAction SilentlyContinue
    Stop-Service "DiagTrack" -Force -ErrorAction SilentlyContinue
    Set-Service "dmwappushsvc" -StartupType Disabled -ErrorAction SilentlyContinue
    Stop-Service "dmwappushsvc" -Force -ErrorAction SilentlyContinue

    # Registry tweaks for privacy
    New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0 -PropertyType DWord -Force | Out-Null
    Write-Host "Telemetry services disabled."
} catch {
    Write-Host "Failed to modify telemetry settings." -ForegroundColor Red
}

# --- Clear Browser Caches (Edge, Chrome, Firefox if present) ---
Write-Host "`nClearing Browser Caches..." -ForegroundColor Green
$browserPaths = @(
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache\*",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache\*",
    "$env:APPDATA\Mozilla\Firefox\Profiles\*\cache2\*"
)
foreach ($path in $browserPaths) { Safe-Remove $path }

# --- Defragment (for HDDs only) ---
Write-Host "`nChecking for HDD drives..." -ForegroundColor Green
$drives = Get-WmiObject Win32_Volume | Where-Object { $_.DriveType -eq 3 -and $_.FileSystem -eq "NTFS" }
foreach ($drive in $drives) {
    Write-Host "Optimizing drive $($drive.DriveLetter)..."
    defrag $drive.DriveLetter /O /U | Out-Null
}

# --- System Health Summary ---
Write-Host "`nSystem Cleanup Completed!" -ForegroundColor Cyan
Write-Host "Free disk space after cleanup:" -ForegroundColor White
Get-PSDrive C | Select-Object Used, Free

Write-Host "`nMaintenance complete. Recommended to restart your system." -ForegroundColor Cyan
