@echo off
setlocal enabledelayedexpansion
title TR World Project - Synchroniseur Anti-Crash
color 0A

echo =======================================================================
echo          TR WORLD PROJECT - SYNCHRONISEUR & ANTI-CRASH V1.0
echo =======================================================================
echo.
echo Verification des mises a jour en cours...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ErrorActionPreference = 'Stop';" ^
    "$repo = 'EnriqueP01/tr-world-project-sync';" ^
    "" ^
    "function Find-InstancePath {" ^
    "    if (Test-Path (Join-Path $PSScriptRoot 'mods')) { return $PSScriptRoot }" ^
    "    $defaultPath = Join-Path $env:USERPROFILE 'curseforge\minecraft\Instances\TR world project';" ^
    "    if (Test-Path (Join-Path $defaultPath 'mods')) { return $defaultPath }" ^
    "    $cfRoot = Join-Path $env:USERPROFILE 'curseforge\minecraft\Instances';" ^
    "    if (Test-Path $cfRoot) {" ^
    "        $candidates = Get-ChildItem -Directory $cfRoot | Where-Object { Test-Path (Join-Path $_.FullName 'mods') };" ^
    "        foreach ($c in $candidates) {" ^
    "            if (Get-ChildItem (Join-Path $c.FullName 'mods') -Filter '*tensura*' -ErrorAction SilentlyContinue) {" ^
    "                return $c.FullName;" ^
    "            }" ^
    "        }" ^
    "        if ($candidates.Count -eq 1) { return $candidates[0].FullName }" ^
    "    }" ^
    "    return $null;" ^
    "}" ^
    "" ^
    "$instanceDir = Find-InstancePath;" ^
    "if (-not $instanceDir) {" ^
    "    Write-Host '[!] Dossier du jeu TR World Project non detecte automatiquement.' -ForegroundColor Yellow;" ^
    "    Add-Type -AssemblyName System.Windows.Forms;" ^
    "    $fbd = New-Object System.Windows.Forms.FolderBrowserDialog;" ^
    "    $fbd.Description = 'Selectionnez le dossier de votre instance TR World Project (dans CurseForge)';" ^
    "    if ($fbd.ShowDialog() -eq 'OK' -and (Test-Path (Join-Path $fbd.SelectedPath 'mods'))) {" ^
    "        $instanceDir = $fbd.SelectedPath;" ^
    "    } else {" ^
    "        Write-Host '[ERREUR] Aucun dossier valide selectionne. Annulation.' -ForegroundColor Red;" ^
    "        exit 1;" ^
    "    }" ^
    "}" ^
    "Write-Host ('[*] Dossier detecte : ' + $instanceDir) -ForegroundColor Cyan;" ^
    "" ^
    "$versionFile = Join-Path $instanceDir '.tr_version';" ^
    "$localVersion = 'none';" ^
    "if (Test-Path $versionFile) { $localVersion = (Get-Content $versionFile -Raw).Trim() }" ^
    "" ^
    "Write-Host '[*] Connexion a GitHub pour verifier la derniere version...' -ForegroundColor Gray;" ^
    "try {" ^
    "    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;" ^
    "    $rel = Invoke-RestMethod -Uri ('https://api.github.com/repos/' + $repo + '/releases/latest') -Headers @{'User-Agent'='TR-Sync-Client'};" ^
    "} catch {" ^
    "    Write-Host ('[!] Impossible de contacter GitHub : ' + $_.Exception.Message) -ForegroundColor Yellow;" ^
    "    Write-Host '[*] Vous pouvez quand meme lancer le jeu avec vos fichiers actuels.' -ForegroundColor Gray;" ^
    "    exit 0;" ^
    "}" ^
    "" ^
    "$remoteVersion = $rel.tag_name;" ^
    "Write-Host ('[*] Version actuelle du serveur : ' + $remoteVersion) -ForegroundColor White;" ^
    "Write-Host ('[*] Votre version locale        : ' + $localVersion) -ForegroundColor White;" ^
    "" ^
    "if ($localVersion -eq $remoteVersion) {" ^
    "    Write-Host '-------------------------------------------------------' -ForegroundColor Green;" ^
    "    Write-Host ' [OK] Votre jeu est 100% a jour avec le serveur !' -ForegroundColor Green;" ^
    "    Write-Host '      Aucun telechargement requis. Bon jeu !' -ForegroundColor Green;" ^
    "    Write-Host '-------------------------------------------------------' -ForegroundColor Green;" ^
    "    exit 0;" ^
    "}" ^
    "" ^
    "Write-Host '-------------------------------------------------------' -ForegroundColor Yellow;" ^
    "Write-Host (' [!] Mise a jour disponible : ' + $remoteVersion) -ForegroundColor Yellow;" ^
    "Write-Host '-------------------------------------------------------' -ForegroundColor Yellow;" ^
    "" ^
    "$modsFolder = Join-Path $instanceDir 'mods';" ^
    "$currentModCount = (Get-ChildItem $modsFolder -Filter '*.jar' -ErrorAction SilentlyContinue).Count;" ^
    "" ^
    "$chosenAsset = $null;" ^
    "if ($currentModCount -lt 10) {" ^
    "    Write-Host '[*] Moins de 10 mods detectes. Telechargement du pack complet...' -ForegroundColor Cyan;" ^
    "    $chosenAsset = $rel.assets | Where-Object { $_.name -eq 'TR_Full_Pack.zip' };" ^
    "} else {" ^
    "    Write-Host '[*] Telechargement du bundle de mise a jour rapide...' -ForegroundColor Cyan;" ^
    "    $chosenAsset = $rel.assets | Where-Object { $_.name -eq 'TR_Update_Bundle.zip' };" ^
    "}" ^
    "if (-not $chosenAsset) { $chosenAsset = $rel.assets[0] }" ^
    "" ^
    "$downloadUrl = $chosenAsset.browser_download_url;" ^
    "$tempZip = Join-Path $env:TEMP ('tr_update_' + [Guid]::NewGuid().ToString() + '.zip');" ^
    "" ^
    "Write-Host ('[*] Telechargement de ' + $chosenAsset.name + ' (' + [math]::Round($chosenAsset.size / 1MB, 2) + ' MB)...') -ForegroundColor Cyan;" ^
    "$webClient = New-Object System.Net.WebClient;" ^
    "$webClient.Headers.Add('User-Agent', 'TR-Sync-Client');" ^
    "$webClient.DownloadFile($downloadUrl, $tempZip);" ^
    "" ^
    "Write-Host '[*] Extraction des fichiers...' -ForegroundColor Cyan;" ^
    "Add-Type -AssemblyName System.IO.Compression.FileSystem;" ^
    "[System.IO.Compression.ZipFile]::ExtractToDirectory($tempZip, $instanceDir, $true);" ^
    "Remove-Item $tempZip -Force -ErrorAction SilentlyContinue;" ^
    "" ^
    "$manifestFile = Join-Path $instanceDir 'manifest_sync.json';" ^
    "if (Test-Path $manifestFile) {" ^
    "    $manifest = Get-Content $manifestFile -Raw | ConvertFrom-Json;" ^
    "    if ($manifest.active_mods) {" ^
    "        $activeSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$manifest.active_mods, [System.StringComparer]::OrdinalIgnoreCase);" ^
    "        $localJars = Get-ChildItem $modsFolder -Filter '*.jar' -File;" ^
    "        $removed = 0;" ^
    "        foreach ($jar in $localJars) {" ^
    "            if (-not $activeSet.Contains($jar.Name)) {" ^
    "                Remove-Item $jar.FullName -Force -ErrorAction SilentlyContinue;" ^
    "                $removed++;" ^
    "            }" ^
    "        }" ^
    "        if ($removed -gt 0) {" ^
    "            Write-Host ('[*] Nettoyage : ' + $removed + ' ancien(s) mod(s) supprime(s) pour eviter tout conflit.') -ForegroundColor Gray;" ^
    "        }" ^
    "    }" ^
    "    Remove-Item $manifestFile -Force -ErrorAction SilentlyContinue;" ^
    "}" ^
    "" ^
    "Set-Content -Path $versionFile -Value $remoteVersion -Encoding utf8;" ^
    "Write-Host '-------------------------------------------------------' -ForegroundColor Green;" ^
    "Write-Host (' [SUCCES] Votre jeu est maintenant a jour en version ' + $remoteVersion + ' !') -ForegroundColor Green;" ^
    "Write-Host '          Tous les correctifs sont installes. Bon jeu !' -ForegroundColor Green;" ^
    "Write-Host '-------------------------------------------------------' -ForegroundColor Green;"

echo.
echo =======================================================================
echo  Operation terminee avec succes ! Vous pouvez lancer CurseForge / Jeu.
echo =======================================================================
echo.
pause
