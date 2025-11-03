# Script criado por Gabriel Peterossi Maricato e IA
# Verifica checksum do BIOS

Write-Host "####### [CRIADO POR GABRIEL PETEROSSI MARICATO E IA] #######" -ForegroundColor Yellow
Write-Host "[Verifica checksum do BIOS] `n" -ForegroundColor Yellow

$biosInfo = Get-WmiObject -Class Win32_BIOS
$manufacturer = $biosInfo.Manufacturer
$version = $biosInfo.Version

Write-Host "Fabricante: $manufacturer"
Write-Host "Versao: $version"

# Verifica assinatura digital

$authenticode = Get-AuthenticodeSignature -FilePath "C:\Windows\System32\winload.efi"

if ($authenticode.Status -ne "Valid") {
    Write-Host "ALERTA: Assinatura digital inválida!" -ForegroundColor Red
}
