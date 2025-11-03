<#
Script criado por Gabriel Peterossi Maricato e IA
Validate-MotherboardHardware.ps1
Coleta e valida informações de hardware relacionadas à placa-mãe (Windows).
Uso: Execute em PowerShell (Admin):
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
    .\Validate-MotherboardHardware.ps1
#>

Write-Host "####### #######" -ForegroundColor Yellow

Write-Host "####### [SCRIPT CRIADO POR GABRIEL PETEROSSI MARICATO E IA] #######" -ForegroundColor Yellow
Write-Host "####### [Coleta e valida informacoes de hardware relacionadas a placa-mae (Windows 11)] #######" -ForegroundColor Yellow

# --- checa se rodando como Administrador ---
If (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "Execute este script como Administrador."
    Exit 1
}

$timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
$outdir = "$env:USERPROFILE\Desktop\hw_validation_$timestamp"
New-Item -Path $outdir -ItemType Directory -Force | Out-Null

Write-Host "`n=== VALIDANDO HARDWARE DA PLACA-MAE (Windows) ===`n" -ForegroundColor Cyan

# 1) Informações da baseboard e BIOS
Write-Host "Coletando BaseBoard e BIOS..." -ForegroundColor Yellow
$baseboard = Get-WmiObject -Class Win32_BaseBoard -ErrorAction SilentlyContinue
$bios = Get-WmiObject -Class Win32_BIOS -ErrorAction SilentlyContinue
$system = Get-WmiObject -Class Win32_ComputerSystem -ErrorAction SilentlyContinue

@{
    Timestamp = $timestamp
    Manufacturer = $baseboard.Manufacturer
    Product = $baseboard.Product
    SerialNumber = $baseboard.SerialNumber
    BIOS_Manufacturer = $bios.Manufacturer
    BIOS_Version = $bios.SMBIOSBIOSVersion
    BIOS_ReleaseDate = $bios.ReleaseDate
    System_Model = $system.Model
    System_Manufacturer = $system.Manufacturer
} | Out-File -FilePath (Join-Path $outdir "baseboard_bios.txt")

# 2) CPU
Write-Host "Coletando CPU..." -ForegroundColor Yellow
Get-WmiObject Win32_Processor | Select-Object Name, Manufacturer, MaxClockSpeed, NumberOfCores, NumberOfLogicalProcessors | Out-File (Join-Path $outdir "cpu.txt")

# 3) Memoria fisica (DIMMs)
Write-Host "Coletando memoria fisica (DIMMs)..." -ForegroundColor Yellow
Get-WmiObject Win32_PhysicalMemory | Select-Object BankLabel, Capacity, Speed, Manufacturer, PartNumber, SerialNumber | Format-Table | Out-File (Join-Path $outdir "memory_raw.txt")
# resumo
(Get-WmiObject Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum | ForEach-Object {
    $totalBytes = $_
    $totalGB = [math]::Round($totalBytes/1GB,2)
    "Total RAM (bytes): $totalBytes"  | Out-File -Append (Join-Path $outdir "memory_summary.txt")
    "Total RAM (GB): $totalGB"        | Out-File -Append (Join-Path $outdir "memory_summary.txt")
}

# 4) Discos e SMART (tentativa via WMI + MSStorageDriver)
Write-Host "Coletando discos e checando SMART (quando disponivel)..." -ForegroundColor Yellow
Get-WmiObject Win32_DiskDrive | Select-Object Model, InterfaceType, Size, SerialNumber | Out-File (Join-Path $outdir "disks.txt")

# Tentativa de consulta SMART via WMI (classe MSStorageDriver_FailurePredictStatus)
try {
    $smart = Get-WmiObject -Namespace root\WMI -Class MSStorageDriver_FailurePredictStatus -ErrorAction Stop
    $smart | Select InstanceName, PredictFailure, VendorSpecific | Out-File (Join-Path $outdir "smart_wmi.txt")
} catch {
    "SMART via WMI não disponivel / acesso negado: $_" | Out-File (Join-Path $outdir "smart_wmi.txt")
}

# 5) Dispositivos PCI/PNP/Drivers
Write-Host "Listando dispositivos PnP / PCI / USB..." -ForegroundColor Yellow
Get-WmiObject Win32_PnPEntity | Select-Object Name, PNPDeviceID, Manufacturer, Service, Status | Out-File (Join-Path $outdir "pnp_entities.txt")
Get-PnpDevice | Select-Object InstanceId, Class, FriendlyName, Status | Out-File (Join-Path $outdir "pnp_device_list.txt")

# 6) Interfaces de rede (para checar se existem adaptadores inesperados)
Write-Host "Coletando interfaces de rede..." -ForegroundColor Yellow
Get-NetAdapter | Select-Object Name, InterfaceDescription, Status, MacAddress, LinkSpeed | Out-File (Join-Path $outdir "net_adapters.txt")

# 7) Temperaturas e sensores (tentativa via WMI - muitas placas não expõem)
Write-Host "Coletando sensores de temperatura (WMI - disponibilidade variavel)..." -ForegroundColor Yellow
try {
    Get-WmiObject MSAcpi_ThermalZoneTemperature -Namespace "root/wmi" -ErrorAction Stop | Select-Object InstanceName, CurrentTemperature | Out-File (Join-Path $outdir "temperatures_wmi.txt")
} catch {
    "MSAcpi_ThermalZoneTemperature não disponivel ou sem permissão." | Out-File (Join-Path $outdir "temperatures_wmi.txt")
}

# 8) Logs recentes do sistema (Event Viewer - System)
Write-Host "Extraindo ultimos eventos do System log (ultimas 200 entradas)..." -ForegroundColor Yellow
Get-WinEvent -LogName System -MaxEvents 200 | Select-Object TimeCreated, LevelDisplayName, ProviderName, Id, Message | Out-File (Join-Path $outdir "system_events_last200.txt")

# 9) Validações simples (checagens rapidas)
$checks = @()
# BIOS data plausibility
if ($bios.ReleaseDate) {
    $checks += "BIOS release date: $($bios.ReleaseDate)"
} else {
    $checks += "BIOS release date: N/A"
}
# Memoria detectada
$totalRAM_GB = [math]::Round(((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1GB),2)
$checks += "Total RAM reported by OS: $totalRAM_GB GB"

# Dispositivo AllJoyn check (exemplo de serviço que às vezes aparece)
$aj = Get-Service -Name AJRouter -ErrorAction SilentlyContinue
if ($aj) {
    $checks += "AllJoyn Router service present: $($aj.Status) (StartupType=$($aj.StartType))"
} else {
    $checks += "AllJoyn Router service: não instalado"
}

$checks | Out-File (Join-Path $outdir "quick_checks.txt")

Write-Host "`nRelatorio gerado em: $outdir" -ForegroundColor Green
Write-Host "Arquivos principais:" -ForegroundColor Cyan
Get-ChildItem -Path $outdir | Select-Object Name, Length | Format-Table

Start $outdir

Write-Host "`nScript concluido."
