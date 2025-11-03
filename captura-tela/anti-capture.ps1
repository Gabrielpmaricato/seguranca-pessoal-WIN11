<#
.SYNOPSIS
Criado por Gabriel Peterossi Maricato e IA
Script em tempo real para bloquear capturas de tela indesejadas.

.DESCRIPTION
- Monitora processos de captura de tela (Snipping Tool, ShareX, Greenshot, etc.).
- Encerra automaticamente processos suspeitos.
- Bloqueia a tecla PrintScreen via registro (cria a chave se necessário).
- Registra atividade no console.
#>

Write-Host "####### [CRIADO POR GABRIEL PETEROSSI MARICATO E IA] #######" -ForegroundColor Yellow
Write-Host "[Script em tempo real para bloquear capturas de tela indesejadas] `n" -ForegroundColor Yellow


# Lista de processos de captura de tela conhecidos
$screenCaptureProcesses = @("SnippingTool","SnipAndSketch","Greenshot","ShareX","Lightshot")

# Caminho do registro
$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"

# Cria a chave se não existir
if (-not (Test-Path $regPath)) {
    New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies" -Name "Explorer" -Force | Out-Null
}

# Bloqueia a tecla PrintScreen
New-ItemProperty -Path $regPath -Name "NoPrintScreen" -PropertyType DWord -Value 1 -Force
Write-Host "PrintScreen desativado. Reinicie o Windows Explorer ou faça logoff para aplicar." -ForegroundColor Cyan

# Mantém controle de PIDs já encerrados
$processedPIDs = @{}

Write-Host "Iniciando monitoramento contínuo de processos de captura de tela..." -ForegroundColor Cyan

# Loop infinito para monitoramento em tempo real
while ($true) {
    foreach ($procName in $screenCaptureProcesses) {
        # Localiza processos em execução
        $procList = Get-Process -Name $procName -ErrorAction SilentlyContinue

        foreach ($proc in $procList) {
            if (-not $processedPIDs.ContainsKey($proc.Id)) {
                try {
                    Write-Host "$(Get-Date -Format 'HH:mm:ss') - Encerrando processo suspeito: $($proc.ProcessName) (PID $($proc.Id))" -ForegroundColor Yellow
                    Stop-Process -Id $proc.Id -Force
                    $processedPIDs[$proc.Id] = $true
                } catch {
                    Write-Host "$(Get-Date -Format 'HH:mm:ss') - Não foi possível encerrar o processo $($proc.ProcessName) (PID $($proc.Id))" -ForegroundColor Red
                }
            }
        }
    }
    Start-Sleep -Seconds 5  # Checa a cada 5 segundos
}
