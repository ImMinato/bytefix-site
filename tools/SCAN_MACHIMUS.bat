@echo off
setlocal
color 0b
title MACHIMUS SCAN - Recolector de datos
set "SCANBAT=%~f0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$c=[IO.File]::ReadAllText($env:SCANBAT); $i=$c.IndexOf('#PSSTART'+'#'); Invoke-Expression $c.Substring($i)"
echo.
pause
exit /b
#PSSTART#
$ErrorActionPreference = 'SilentlyContinue'
$Out = [Environment]::GetFolderPath('Desktop')
if ($env:SCAN_OUT_DIR) { $Out = $env:SCAN_OUT_DIR }
$Report = Join-Path $Out 'SCAN_MACHIMUS.txt'
$L = New-Object System.Collections.Generic.List[string]
function W([string]$t = '') { [void]$L.Add($t) }
function Row([string]$q, [string]$a) { W ('  ' + $q.PadRight(50) + ': ' + $a) }
function Clean([string]$s) { if ($s) { ($s -replace '\s+', ' ').Trim() } else { '' } }
function YN($b) { if ($b) { 'S' } else { 'N' } }

function Invoke-PingOnce([string]$target, [int]$size, [bool]$df) {
    try {
        $p = New-Object System.Net.NetworkInformation.Ping
        $o = New-Object System.Net.NetworkInformation.PingOptions(64, $df)
        $buf = New-Object byte[] $size
        $r = $p.Send($target, 1500, $buf, $o)
        if ($r.Status -eq 'Success') { return [int]$r.RoundtripTime } else { return -1 }
    } catch { return -1 }
}

Write-Host ''
Write-Host '  MACHIMUS SCAN - recolectando datos del equipo...' -ForegroundColor Cyan
Write-Host ''

# ---------------------------------------------------------------- sistema
Write-Host '  [1/6] Sistema y tipo de equipo'
$os = Get-CimInstance Win32_OperatingSystem
$cs = Get-CimInstance Win32_ComputerSystem
$build = [int]$os.BuildNumber
$isWin11 = ($build -ge 22000)
$osName = Clean $os.Caption
$isHome = ($osName -match 'Home')
$isVM = (([string]$cs.Model) -match 'Virtual|VMware|KVM|QEMU') -or (([string]$cs.Manufacturer) -match 'QEMU|VMware|Xen|innotek')
$ct = @((Get-CimInstance Win32_SystemEnclosure).ChassisTypes)
$bat = @(Get-CimInstance Win32_Battery)
$laptopTypes = @(8, 9, 10, 11, 14, 30, 31, 32)
$isLaptop = ($bat.Count -gt 0) -or (@($ct | Where-Object { $laptopTypes -contains [int]$_ }).Count -gt 0)
$plan = Clean ((powercfg /getactivescheme) -join ' ')

# ---------------------------------------------------------------- cpu
Write-Host '  [2/6] Procesador'
$cpus = @(Get-CimInstance Win32_Processor)
$cpuName = Clean $cpus[0].Name
$cores = [int](($cpus | Measure-Object -Property NumberOfCores -Sum).Sum)
$threads = [int](($cpus | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum)
$l2 = [int]$cpus[0].L2CacheSize
$isAMD = ($cpuName -match 'AMD')
$isIntel = ($cpuName -match 'Intel')
$gen = $null
if ($cpuName -match 'Core\(TM\)\s*i[3579]-(\d{4,5})') {
    $m = $Matches[1]
    if ($m.Length -eq 5) { $gen = [int]$m.Substring(0, 2) }
    elseif ($m.StartsWith('1')) { $gen = [int]$m.Substring(0, 2) }
    else { $gen = [int]$m.Substring(0, 1) }
}
elseif ($cpuName -match 'Core\(TM\)\s*i[3579]\s+CPU\s+\d{3}\b') { $gen = 1 }
elseif ($cpuName -match 'Core\(TM\)2') { $gen = 0 }
$x3d = ($cpuName -match 'X3D')
$hybrid = $false
if ($isIntel) {
    if ($cpuName -match 'Ultra') { $hybrid = $true }
    elseif (($gen -ne $null) -and ($gen -ge 12) -and ($threads -lt (2 * $cores))) { $hybrid = $true }
    elseif (($gen -eq $null) -and ($threads -lt (2 * $cores)) -and ($threads -gt $cores)) { $hybrid = $true }
}
$special = ($x3d -or $hybrid)
$legacy = $false
if ($isIntel -and ($gen -ne $null) -and ($gen -le 4)) { $legacy = $true }
if ($cpuName -match 'Core\(TM\)2|Phenom|FX-\d|Athlon\(tm\) II|Pentium\(R\) D') { $legacy = $true }

# ---------------------------------------------------------------- ram y disco
Write-Host '  [3/6] Memoria y almacenamiento'
$ramGB = [math]::Round(([double]$cs.TotalPhysicalMemory) / 1GB, 1)
if ($ramGB -lt 6.5) { $ramOpt = 1 } elseif ($ramGB -lt 13) { $ramOpt = 2 } else { $ramOpt = 3 }
$mods = @(Get-CimInstance Win32_PhysicalMemory)
$xmpOff = $false
foreach ($mm in $mods) {
    if ($mm.Speed -and $mm.ConfiguredClockSpeed -and ([int]$mm.ConfiguredClockSpeed -lt ([int]$mm.Speed * 0.9))) { $xmpOff = $true }
}
$sysLetter = ([string]$env:SystemDrive).Substring(0, 1)
$pd = $null
try {
    $part = Get-Partition -DriveLetter $sysLetter
    $dn = $part.DiskNumber
    $pd = Get-PhysicalDisk | Where-Object { [string]$_.DeviceId -eq [string]$dn } | Select-Object -First 1
} catch { }
$isSSD = $null
if ($pd) {
    if (($pd.MediaType -eq 'SSD') -or ($pd.BusType -eq 'NVMe')) { $isSSD = $true }
    elseif ($pd.MediaType -eq 'HDD') { $isSSD = $false }
    elseif ($pd.SpindleSpeed -eq 0) { $isSSD = $true }
    elseif (($pd.SpindleSpeed -gt 0) -and ($pd.SpindleSpeed -lt 100000)) { $isSSD = $false }
}
if ($isSSD -eq $null) {
    $dd = @(Get-CimInstance Win32_DiskDrive)
    if (@($dd | Where-Object { $_.Model -match 'SSD|NVMe|Solid' }).Count -gt 0) { $isSSD = $true }
}
$vol = Get-CimInstance Win32_LogicalDisk -Filter ("DeviceID='" + $env:SystemDrive + "'")
$freeGB = $null; $sizeGB = $null
if ($vol) { $freeGB = [math]::Round(([double]$vol.FreeSpace) / 1GB, 0); $sizeGB = [math]::Round(([double]$vol.Size) / 1GB, 0) }

# ---------------------------------------------------------------- red
Write-Host '  [4/6] Red y MTU (tarda unos segundos)'
$ad = $null
$guid = $null
$routes = @(Get-NetRoute -DestinationPrefix '0.0.0.0/0' | Sort-Object { [int]$_.RouteMetric + [int]$_.InterfaceMetric })
foreach ($r in $routes) {
    $cand = Get-NetAdapter -InterfaceIndex $r.InterfaceIndex
    if ($cand -and ($cand.Status -eq 'Up')) { $ad = $cand; break }
}
if ($ad) { $guid = ([string]$ad.InterfaceGuid).ToUpper() }
if (-not $guid) {
    $cfg = Get-CimInstance Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -and $_.DefaultIPGateway } | Select-Object -First 1
    if ($cfg) { $guid = ([string]$cfg.SettingID).ToUpper() }
}
if ($guid -and (-not $guid.StartsWith('{'))) { $guid = '{' + $guid + '}' }
$adDesc = ''; $isWifi = $false; $isVirtualNic = $false
if ($ad) {
    $adDesc = Clean $ad.InterfaceDescription
    $isWifi = (([string]$ad.PhysicalMediaType) -match '802\.11') -or ($adDesc -match 'Wi-?Fi|Wireless|802\.11')
    $isVirtualNic = ([bool]$ad.Virtual) -or ($adDesc -match 'VPN|TAP|WireGuard|TUN|Hyper-V|Virtual')
}
$mtuTarget = $null
foreach ($t in @('8.8.8.8', '1.1.1.1')) {
    if ((Invoke-PingOnce $t 32 $true) -ge 0) { $mtuTarget = $t; break }
}
$pathMtu = $null
$rtts = @()
if ($mtuTarget) {
    if ((Invoke-PingOnce $mtuTarget 1472 $true) -ge 0) { $pathMtu = 1500 }
    else {
        $lo = 32; $hi = 1472
        while (($hi - $lo) -gt 1) {
            $mid = [int](($lo + $hi) / 2)
            if ((Invoke-PingOnce $mtuTarget $mid $true) -ge 0) { $lo = $mid } else { $hi = $mid }
        }
        $pathMtu = $lo + 28
    }
    foreach ($i in 1..8) {
        $x = Invoke-PingOnce $mtuTarget 32 $false
        if ($x -ge 0) { $rtts += $x }
    }
}
$rttAvg = $null; $rttJit = $null
if ($rtts.Count -gt 0) {
    $rttAvg = [math]::Round(($rtts | Measure-Object -Average).Average, 0)
    $rttJit = ($rtts | Measure-Object -Maximum).Maximum - ($rtts | Measure-Object -Minimum).Minimum
}

# ---------------------------------------------------------------- gpu
Write-Host '  [5/6] Placa de video'
$gpus = @(Get-CimInstance Win32_VideoController | Where-Object { $_.PNPDeviceID -like 'PCI\*' })
$dgpu = $gpus | Where-Object { $_.Name -match 'NVIDIA|GeForce|Radeon (RX|R[579]|HD|Pro|VII)|Arc' } | Select-Object -First 1
if ($dgpu) { $gpu = $dgpu } else { $gpu = $gpus | Select-Object -First 1 }
$gpuName = Clean $gpu.Name
$gpuId = [string]$gpu.PNPDeviceID
$hagsOk = $false
if ($gpuName -match 'NVIDIA|GeForce') {
    if ($gpuName -match 'RTX|GTX\s*1[0-9]{3}|GT\s*10[0-9]{2}') { $hagsOk = $true }
}
elseif ($gpuName -match 'Radeon RX\s*(5|6|7|9)[0-9]{3}') { $hagsOk = $true }
$msiNow = $null
if ($gpuId) {
    $msiPath = 'HKLM:\SYSTEM\CurrentControlSet\Enum\' + $gpuId + '\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties'
    $msiNow = (Get-ItemProperty -LiteralPath $msiPath -Name MSISupported).MSISupported
}
$hagsNow = (Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers').HwSchMode
$hz = [int]$gpu.CurrentRefreshRate

# ---------------------------------------------------------------- seguridad (vbs)
Write-Host '  [6/6] Seguridad de Windows'
$dg = Get-CimInstance -Namespace 'root\Microsoft\Windows\DeviceGuard' -ClassName Win32_DeviceGuard
$vbs = [int]$dg.VirtualizationBasedSecurityStatus
$hvci = (@($dg.SecurityServicesRunning) -contains 2)

# ================================================================ REPORTE
W '=================================================================================================='
W '  MACHIMUS SCAN  |  datos del equipo para los generadores'
W ('  Fecha: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm') + '   |   Solo datos de hardware y configuracion, sin datos personales')
W '=================================================================================================='
W ''
W '[1] RESPUESTAS PARA EL GENERADOR   (en el orden en que las pregunta)'
W '--------------------------------------------------------------------------------------------------'
if ($isLaptop) { $aPc = '2   (Notebook)' } else { $aPc = '1   (PC de escritorio)' }
if ($x3d) { $aSp = 'S   (Ryzen X3D)' } elseif ($hybrid) { $aSp = 'S   (Intel hibrido, P-cores y E-cores)' } else { $aSp = 'N' }
if ($pathMtu -ge 1500) { $aMtu = '(dejar VACIO: el camino soporta 1500)' }
elseif ($pathMtu) { $aMtu = '(dejar VACIO. Medido: ' + [string]$pathMtu + '; solo usarlo si el cliente tiene PPPoE o VPN)' }
else { $aMtu = '(dejar VACIO: no se pudo medir)' }
if ($legacy) { $aSpectre = '1 o 2   (CPU de generacion vieja: es donde mas se nota; decidir segun el uso de la PC)' } else { $aSpectre = '1   (mantener)' }
if ($hagsOk) { $aHags = 'S   (GPU compatible)' } else { $aHags = 'N   (GPU vieja o no identificada)' }
if ($gpuId) { $aGpu = $gpuId } else { $aGpu = '(vacio: no se detecto GPU PCI)' }
if ($isSSD -eq $true) { $aDisk = '1   (SSD / NVMe)' } elseif ($isSSD -eq $false) { $aDisk = '2   (HDD)' } else { $aDisk = '?   (no se pudo determinar, confirmar a mano)' }
if ($l2 -gt 0) { $aL2 = [string]$l2 } else { $aL2 = '(vacio: no se pudo leer)' }
if ($guid) { $aGuid = $guid } else { $aGuid = '(no se detecto: copiar SettingID a mano)' }
if ($isWin11) { $aWin = '2   (Windows 11)' } else { $aWin = '1   (Windows 10 o anterior)' }
Row 'Tipo de equipo (1 PC / 2 Notebook)' $aPc
Row 'CPU especial? Ryzen X3D / Intel hibrido (S/N)' $aSp
Row 'GUID de la placa de red' $aGuid
Row 'MTU' $aMtu
Row 'Nucleos fisicos' ([string]$cores)
Row 'Hilos logicos' ([string]$threads)
Row 'Spectre/Meltdown (1 mantener / 2 desactivar)' $aSpectre
Row 'El CPU es AMD? (S/N, solo si elegis desactivar)' (YN $isAMD)
Row 'Activar HAGS? (S/N)' $aHags
Row 'ID de la GPU (PNPDeviceID)' $aGpu
Row 'Cache L2 en KB' $aL2
if ($ramGB -gt 0) { $aRam = [string]$ramOpt + '   (' + $ramGB + ' GB reportados por Windows)' } else { $aRam = '?   (no se pudo leer la RAM, confirmar a mano)' }
Row 'RAM (1 low / 2 mid / 3 high)' $aRam
Row 'Disco (1 SSD / 2 HDD)' $aDisk
Row 'Debloat de apps (S/N)' 'decision del tecnico'
Row 'Version de Windows (solo Warlord: 1=10 / 2=11)' $aWin
W ''
W '[2] ALERTAS Y RECOMENDACIONES'
W '--------------------------------------------------------------------------------------------------'
$n = 0
function Alert([string]$t) { $script:n++; W ('  * ' + $t) }
if ($isVM) { Alert 'Es una maquina virtual: los resultados de hardware no representan un equipo fisico.' }
if ($isLaptop) { Alert 'Notebook: no se cambia el plan de energia (bateria). Los ajustes agresivos conviene probarlos conectada a la corriente.' }
if ($special) { Alert 'CPU especial: no se cambia el plan de energia ni el core parking para no interferir con el scheduler del CPU.' }
if ($legacy) { Alert ('CPU de generacion vieja (' + $cpuName + '): las mitigaciones Spectre/Meltdown cuestan mas rendimiento aca. Si se desactivan, informar el riesgo de seguridad al cliente.') }
if ($isWifi) { Alert 'La conexion es por Wi-Fi: el ping y el jitter dependen mas del enlace inalambrico que de cualquier ajuste. Recomendar cable Ethernet.' }
if ($isVirtualNic) { Alert 'La ruta por defecto sale por un adaptador virtual o VPN: el GUID puede no ser el de la placa fisica. Verificar antes de generar.' }
if (-not $guid) { Alert 'No se detecto el GUID de red automaticamente: usar SettingID de Get-CimInstance Win32_NetworkAdapterConfiguration.' }
if ($xmpOff) { Alert 'La RAM trabaja por debajo de su velocidad nominal: probable XMP/EXPO desactivado en la BIOS. Activarlo da mas que cualquier ajuste de registro.' }
if (($mods.Count -eq 1) -and ($ramGB -ge 7)) { Alert 'Un solo modulo de RAM: funciona en single channel. Agregar un segundo modulo igual mejora el rendimiento.' }
if ($isSSD -eq $false) { Alert 'El disco de sistema es un HDD: pasar a SSD mejora mas que cualquier ajuste de registro.' }
if ($freeGB -ne $null -and $sizeGB -gt 0 -and (($freeGB -lt 20) -or (($freeGB / $sizeGB) -lt 0.15))) { Alert ('Poco espacio libre en ' + $env:SystemDrive + ' (' + $freeGB + ' GB de ' + $sizeGB + ' GB). Liberar espacio antes de optimizar.') }
if ($hz -gt 0 -and $hz -le 60) { Alert ('El monitor esta a ' + $hz + ' Hz: verificar en Configuracion > Pantalla si soporta una frecuencia mayor.') }
if ($msiNow -eq 1) { Alert 'La GPU ya tiene MSI activado: el ajuste de MSI del generador no cambia nada en este equipo.' }
if ($hagsNow -eq 2) { Alert 'HAGS ya esta activado en este equipo.' }
if (($vbs -eq 2) -or $hvci) { Alert 'VBS / Integridad de memoria activos: tienen costo de rendimiento en algunas PCs. Desactivarlos baja la seguridad: decision del tecnico, informar al cliente.' }
if ($isHome) { Alert 'Windows Home: la telemetria no baja del nivel minimo que permite la edicion, aunque se apliquen las politicas.' }
if (-not $isWin11 -and $build -gt 0 -and $osName -notmatch 'LTSC|LTSB|IoT') { Alert 'Windows 10: sin actualizaciones de seguridad gratuitas desde octubre de 2025 salvo ESU. Conviene avisar al cliente.' }
if ($n -eq 0) { W '  (sin alertas)' }
W ''
W '[3] DATOS TECNICOS'
W '--------------------------------------------------------------------------------------------------'
W ('  Windows        : ' + $osName + '  (build ' + $build + ')')
W ('  Plan de energia: ' + $plan)
W ('  CPU            : ' + $cpuName)
if ($gen -ne $null) { W ('                   generacion Intel detectada: ' + $gen) }
W ('                   nucleos ' + $cores + ' / hilos ' + $threads + ' / L2 reportada ' + $l2 + ' KB (puede ser el total, no por nucleo)')
W ('  RAM            : ' + $ramGB + ' GB, ' + $mods.Count + ' modulo(s)')
foreach ($mm in $mods) { W ('                   ' + [math]::Round(([double]$mm.Capacity) / 1GB, 0) + ' GB, nominal ' + $mm.Speed + ' / configurada ' + $mm.ConfiguredClockSpeed) }
if ($pd) { W ('  Disco sistema  : ' + (Clean $pd.FriendlyName) + ' | tipo ' + $pd.MediaType + ' | bus ' + $pd.BusType + ' | giro ' + $pd.SpindleSpeed) }
if ($freeGB -ne $null) { W ('  Espacio libre  : ' + $freeGB + ' GB de ' + $sizeGB + ' GB en ' + $env:SystemDrive) }
foreach ($g in $gpus) { W ('  GPU            : ' + (Clean $g.Name) + ' | driver ' + $g.DriverVersion + ' | ' + $g.CurrentRefreshRate + ' Hz') ; W ('                   ' + $g.PNPDeviceID) }
if ($msiNow -ne $null) { W ('  MSI actual GPU : ' + $msiNow) } else { W '  MSI actual GPU : sin valor (usa el default del driver)' }
if ($hagsNow -ne $null) { W ('  HAGS actual    : HwSchMode=' + $hagsNow) } else { W '  HAGS actual    : sin valor (default de Windows)' }
W ('  VBS            : estado ' + $vbs + ' (0 apagado, 1 habilitado sin correr, 2 corriendo) | HVCI: ' + (YN $hvci))
if ($ad) { W ('  Adaptador      : ' + $ad.Name + ' | ' + $adDesc + ' | ' + $ad.LinkSpeed + ' | medio ' + $ad.PhysicalMediaType) }
if ($guid) { W ('  GUID           : ' + $guid) }
if ($pathMtu) { W ('  MTU del camino : ' + $pathMtu + '  (medido contra ' + $mtuTarget + ')') } else { W '  MTU del camino : no medido (ICMP bloqueado o sin conexion)' }
if ($rttAvg -ne $null) { W ('  Latencia       : ' + $rttAvg + ' ms promedio hacia ' + $mtuTarget + ', variacion ' + $rttJit + ' ms (8 pings)') }
W ''
W '[4] SOLO PARA EL MODULO TCP DEL WARLORD (completar a mano con Speedtest)'
W '--------------------------------------------------------------------------------------------------'
W '  Bajada (Mbps): ________   Subida (Mbps): ________   Ping (ms): ________'
W '  Ejecutar el test con todos los programas cerrados. Los generadores de Tier I y Tier II no usan estos datos.'
W ''

$L | Out-File -FilePath $Report -Encoding UTF8
Write-Host ''
Write-Host ('  Listo. Reporte guardado en: ' + $Report) -ForegroundColor Green
Write-Host '  Envialo al tecnico o usalo para completar el generador.'
Write-Host ''
if (-not $env:SCAN_NO_OPEN) { Start-Process notepad.exe -ArgumentList ('"' + $Report + '"') }
