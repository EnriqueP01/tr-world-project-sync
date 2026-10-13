# =======================================================================
#  TR WORLD PROJECT - SYNCHRONISEUR & ANTI-CRASH CLIENT
#  Repository : EnriqueP01/tr-world-project-sync
# =======================================================================

$ErrorActionPreference = 'Stop'
$repo = 'EnriqueP01/tr-world-project-sync'

Write-Host "=======================================================================" -ForegroundColor Cyan
Write-Host "         TR WORLD PROJECT - SYNCHRONISEUR & ANTI-CRASH V1.0            " -ForegroundColor Cyan
Write-Host "=======================================================================" -ForegroundColor Cyan
Write-Host ""

function Find-InstancePath {
    # 1. Dossier courant
    if (Test-Path "mods") { return (Get-Location).Path }
    
    # 2. Dossier parent si on est dans scripts
    if (Test-Path "..\mods") { return (Resolve-Path "..\").Path }
    
    # 3. Chemin standard CurseForge
    $defaultPath = Join-Path $env:USERPROFILE "curseforge\minecraft\Instances\TR world project"
    if (Test-Path (Join-Path $defaultPath "mods")) { return $defaultPath }
    
    # 4. Scanner les instances CurseForge
    $cfRoot = Join-Path $env:USERPROFILE "curseforge\minecraft\Instances"
    if (Test-Path $cfRoot) {
        $candidates = Get-ChildItem -Directory $cfRoot | Where-Object { Test-Path (Join-Path $_.FullName "mods") }
        foreach ($c in $candidates) {
            if (Get-ChildItem (Join-Path $c.FullName "mods") -Filter "*tensura*" -ErrorAction SilentlyContinue) {
                return $c.FullName
            }
        }
        if ($candidates.Count -eq 1) { return $candidates[0].FullName }
    }
    
    return $null
}

$instanceDir = Find-InstancePath
if (-not $instanceDir) {
    Write-Host "[!] Dossier TR World Project non detecte automatiquement." -ForegroundColor Yellow
    Add-Type -AssemblyName System.Windows.Forms
    $fbd = New-Object System.Windows.Forms.FolderBrowserDialog
    $fbd.Description = "Selectionnez le dossier de votre instance TR World Project dans CurseForge"
    if ($fbd.ShowDialog() -eq 'OK' -and (Test-Path (Join-Path $fbd.SelectedPath "mods"))) {
        $instanceDir = $fbd.SelectedPath
    } else {
        Write-Host "[ERREUR] Aucun dossier valide selectionne. Synchronisation annulee." -ForegroundColor Red
        exit 1
    }
}

Write-Host ("[+] Instance detectee : " + $instanceDir) -ForegroundColor Green

$versionFile = Join-Path $instanceDir ".tr_version"
$localVersion = "none"
if (Test-Path $versionFile) {
    $localVersion = (Get-Content $versionFile -Raw).Trim()
}

Write-Host "[*] Verification de la derniere version sur GitHub..." -ForegroundColor Gray
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $rel = Invoke-RestMethod -Uri ("https://api.github.com/repos/" + $repo + "/releases/latest") -Headers @{"User-Agent"="TR-Sync-Client"}
} catch {
    Write-Host ("[!] Impossible de contacter GitHub : " + $_.Exception.Message) -ForegroundColor Yellow
    Write-Host "[*] Le jeu peut etre lance avec vos fichiers actuels." -ForegroundColor Gray
    exit 0
}

$remoteVersion = $rel.tag_name
Write-Host ("[+] Version officielle du serveur : " + $remoteVersion) -ForegroundColor White
Write-Host ("[+] Votre version locale         : " + $localVersion) -ForegroundColor White

if ($localVersion -eq $remoteVersion) {
    Write-Host ""
    Write-Host "-----------------------------------------------------------------------" -ForegroundColor Green
    Write-Host " [OK] Votre jeu est deja a jour avec le serveur ($remoteVersion) !" -ForegroundColor Green
    Write-Host "      Aucun telechargement requis. Vous pouvez jouer sereinement !" -ForegroundColor Green
    Write-Host "-----------------------------------------------------------------------" -ForegroundColor Green
    exit 0
}

Write-Host ""
Write-Host "-----------------------------------------------------------------------" -ForegroundColor Yellow
Write-Host (" [!] Mise a jour detectee : " + $remoteVersion) -ForegroundColor Yellow
Write-Host "-----------------------------------------------------------------------" -ForegroundColor Yellow

$modsFolder = Join-Path $instanceDir "mods"
$currentModCount = (Get-ChildItem $modsFolder -Filter "*.jar" -ErrorAction SilentlyContinue).Count

$chosenAsset = $null
if ($currentModCount -lt 10) {
    Write-Host "[*] Premiere installation detectee. Telechargement du pack complet..." -ForegroundColor Cyan
    $chosenAsset = $rel.assets | Where-Object { $_.name -eq "TR_Full_Pack.zip" }
} else {
    Write-Host "[*] Telechargement du bundle de mise a jour rapide..." -ForegroundColor Cyan
    $chosenAsset = $rel.assets | Where-Object { $_.name -eq "TR_Update_Bundle.zip" }
}

if (-not $chosenAsset) {
    $chosenAsset = $rel.assets[0]
}

$downloadUrl = $chosenAsset.browser_download_url
$tempZip = Join-Path $env:TEMP ("tr_sync_" + [Guid]::NewGuid().ToString() + ".zip")

Write-Host ("[+] Telechargement de " + $chosenAsset.name + " (" + [math]::Round($chosenAsset.size / 1MB, 2) + " MB)...") -ForegroundColor Cyan
$webClient = New-Object System.Net.WebClient
$webClient.Headers.Add("User-Agent", "TR-Sync-Client")
$webClient.DownloadFile($downloadUrl, $tempZip)

Write-Host "[+] Installation des nouveaux fichiers..." -ForegroundColor Cyan
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($tempZip, $instanceDir, $true)
Remove-Item $tempZip -Force -ErrorAction SilentlyContinue

# Nettoyage des vieux mods obsoletes si manifest present
$manifestFile = Join-Path $instanceDir "manifest_sync.json"
if (Test-Path $manifestFile) {
    try {
        $manifest = Get-Content $manifestFile -Raw | ConvertFrom-Json
        if ($manifest.active_mods) {
            $activeSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$manifest.active_mods, [System.StringComparer]::OrdinalIgnoreCase)
            $localJars = Get-ChildItem $modsFolder -Filter "*.jar" -File
            $removed = 0
            foreach ($jar in $localJars) {
                if (-not $activeSet.Contains($jar.Name)) {
                    Remove-Item $jar.FullName -Force -ErrorAction SilentlyContinue
                    $removed++
                }
            }
            if ($removed -gt 0) {
                Write-Host ("[+] Nettoyage : " + $removed + " ancien(s) mod(s) supprime(s) pour eviter les conflits.") -ForegroundColor Gray
            }
        }
    } catch {
        # ignore manifest clean error
    }
    Remove-Item $manifestFile -Force -ErrorAction SilentlyContinue
}

Set-Content -Path $versionFile -Value $remoteVersion -Encoding utf8
Write-Host ""
Write-Host "-----------------------------------------------------------------------" -ForegroundColor Green
Write-Host (" [SUCCES] Synchronisation terminee ! Vous etes en " + $remoteVersion) -ForegroundColor Green
Write-Host "          Tous les patchs et configs serveur sont installes !" -ForegroundColor Green
Write-Host "-----------------------------------------------------------------------" -ForegroundColor Green
