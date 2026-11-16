# ============================================================
# INSTALADOR AUTOMATICO DE DEPENDENCIAS
# Para o Monitor PDF -> JPG (Magick.NET + Ghostscript)
# ============================================================

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "    CONFIGURANDO AMBIENTE PARA CONVERSAO DE PDF -> JPG     " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Habilitar TLS 1.2 (obrigatorio para baixar de repositorios HTTPS modernos)
Write-Host "[1/6] Habilitando TLS 1.2 no PowerShell..." -ForegroundColor Yellow
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
Write-Host "      TLS 1.2 configurado com sucesso." -ForegroundColor Green


# 2. Instalar o provedor NuGet se nao existir
Write-Host "`n[2/6] Verificando Provedor NuGet..." -ForegroundColor Yellow
$nugetProvider = Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue
if (!$nugetProvider) {
    Write-Host "      Instalando PackageProvider NuGet..." -ForegroundColor Gray
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser | Out-Null
    Write-Host "      Provedor NuGet instalado com sucesso!" -ForegroundColor Green
} else {
    Write-Host "      Provedor NuGet ja instalado (versao $($nugetProvider.Version))." -ForegroundColor Green
}


# 3. Registrar o repositorio nuget.org se nao existir
Write-Host "`n[3/6] Verificando origem de pacotes 'nuget.org'..." -ForegroundColor Yellow
$nugetSrc = Get-PackageSource -Name nuget.org -ProviderName NuGet -ErrorAction SilentlyContinue
if (!$nugetSrc) {
    Write-Host "      Registrando nuget.org..." -ForegroundColor Gray
    Register-PackageSource -Name nuget.org -Location https://www.nuget.org/api/v2 -ProviderName NuGet -Trusted -Force | Out-Null
    Write-Host "      nuget.org registrado com sucesso!" -ForegroundColor Green
} else {
    Write-Host "      Origem nuget.org ja cadastrada." -ForegroundColor Green
}


# 4. Instalar Magick.NET-Q16-AnyCPU
Write-Host "`n[4/6] Verificando instalacao do Magick.NET..." -ForegroundColor Yellow
$BaseNuget = "$env:LOCALAPPDATA\PackageManagement\NuGet\Packages"
$magickInstalled = Get-ChildItem -Path $BaseNuget -Recurse -Filter "Magick.NET-Q16-AnyCPU.dll" -ErrorAction SilentlyContinue

if (!$magickInstalled) {
    Write-Host "      Baixando e instalando Magick.NET-Q16-AnyCPU via NuGet..." -ForegroundColor Gray
    Install-Package Magick.NET-Q16-AnyCPU -ProviderName NuGet -Scope CurrentUser -Force | Out-Null
    Write-Host "      Magick.NET instalado com sucesso!" -ForegroundColor Green
} else {
    Write-Host "      Magick.NET ja instalado." -ForegroundColor Green
}


# 5. Instalar / Configurar Ghostscript (obrigatorio para renderizar PDFs)
Write-Host "`n[5/6] Verificando Ghostscript..." -ForegroundColor Yellow

function Test-GSInstalled {
    if (Get-Command "gswin64c.exe", "gswin32c.exe" -ErrorAction SilentlyContinue) { return $true }
    if (Test-Path "$env:LOCALAPPDATA\Ghostscript\bin\gswin64c.exe") { return $true }
    if (Get-ChildItem -Path "C:\Program Files\gs" -Recurse -Filter "gswin*c.exe" -ErrorAction SilentlyContinue) { return $true }
    if (Get-ChildItem -Path "C:\Program Files (x86)\gs" -Recurse -Filter "gswin*c.exe" -ErrorAction SilentlyContinue) { return $true }
    return $false
}

if (!(Test-GSInstalled)) {
    Write-Host "      Ghostscript nao encontrado. Iniciando configuracao automatica..." -ForegroundColor Gray

    # Verificar ou instalar 7-Zip para descompactar
    $sevenZipPath = "C:\Program Files\7-Zip\7z.exe"
    if (!(Test-Path $sevenZipPath) -and (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        Write-Host "      Instalando 7-Zip via winget para extracao..." -ForegroundColor Gray
        winget install -e --id 7zip.7zip --accept-source-agreements --accept-package-agreements --silent | Out-Null
    }

    $gsUrl = "https://github.com/ArtifexSoftware/ghostpdl-downloads/releases/download/gs10080/gs10080w64.exe"
    $gsDest = "$env:TEMP\gs_installer.exe"
    Write-Host "      Baixando Ghostscript oficial ($gsUrl)..." -ForegroundColor Gray
    Invoke-WebRequest -Uri $gsUrl -OutFile $gsDest -UseBasicParsing

    $gsTargetDir = "$env:LOCALAPPDATA\Ghostscript"
    if (!(Test-Path $gsTargetDir)) {
        New-Item -ItemType Directory -Path $gsTargetDir -Force | Out-Null
    }

    if (Test-Path $sevenZipPath) {
        Write-Host "      Descompactando Ghostscript para $gsTargetDir..." -ForegroundColor Gray
        & $sevenZipPath x -y "-o$gsTargetDir" $gsDest | Out-Null
    } else {
        Write-Host "      Executando instalador do Ghostscript. Siga os passos na tela caso abra a janela..." -ForegroundColor Yellow
        Start-Process -FilePath $gsDest -Wait
    }

    # Adicionar bin ao PATH de usuario se estiver em LocalAppData
    $gsBin = "$env:LOCALAPPDATA\Ghostscript\bin"
    if (Test-Path $gsBin) {
        $curUserPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
        if ($curUserPath -notlike "*$gsBin*") {
            [System.Environment]::SetEnvironmentVariable("PATH", "$curUserPath;$gsBin", "User")
        }
        $env:PATH = "$gsBin;$env:PATH"
    }

    Write-Host "      Ghostscript configurado com sucesso!" -ForegroundColor Green
} else {
    Write-Host "      Ghostscript ja instalado e detectado no sistema." -ForegroundColor Green
}


# 6. Criar pastas C:\PDF e C:\JPG
Write-Host "`n[6/6] Verificando pastas C:\PDF e C:\JPG..." -ForegroundColor Yellow
if (!(Test-Path "C:\PDF")) {
    New-Item -ItemType Directory -Path "C:\PDF" -Force | Out-Null
    Write-Host "      Pasta C:\PDF criada." -ForegroundColor Green
} else {
    Write-Host "      Pasta C:\PDF ja existe." -ForegroundColor Green
}

if (!(Test-Path "C:\JPG")) {
    New-Item -ItemType Directory -Path "C:\JPG" -Force | Out-Null
    Write-Host "      Pasta C:\JPG criada." -ForegroundColor Green
} else {
    Write-Host "      Pasta C:\JPG ja existe." -ForegroundColor Green
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "   TODAS AS DEPENDENCIAS FORAM INSTALADAS COM SUCESSO!     " -ForegroundColor Green
Write-Host "   Voce ja pode executar o monitor_pdf_jpg.ps1             " -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
