# ============================================================
# MONITOR AUTOMATICO PDF -> JPG
# Magick.NET + FileSystemWatcher + Ghostscript
# ============================================================

# Garante definicao correta do diretorio do script
if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
    if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        $PSScriptRoot = (Get-Location).Path
    }
}

$PastaEntrada = "C:\PDF"
$PastaSaida   = "C:\JPG"

# Registro para impedir processamento duplicado
$Registro = Join-Path $PSScriptRoot "processados.txt"

# Qualidade do JPG
$QualidadeJPG = 90

# Resolucao do PDF (DPI)
$DPI = 200


# ============================================================
# CRIAR PASTAS SE NAO EXISTIREM
# ============================================================

if (!(Test-Path $PastaEntrada)) {
    New-Item -ItemType Directory -Path $PastaEntrada -Force | Out-Null
}

if (!(Test-Path $PastaSaida)) {
    New-Item -ItemType Directory -Path $PastaSaida -Force | Out-Null
}


# ============================================================
# CONFIGURAR GHOSTSCRIPT NO PATH (REQUISITO PARA O MAGICK.NET LER PDF)
# ============================================================

function Ensure-Ghostscript {
    # 1. Verifica se gswin64c.exe ou gswin32c.exe ja esta acessivel
    $gsCmd = Get-Command "gswin64c.exe", "gswin32c.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($gsCmd) {
        return $true
    }

    # 2. Procura em diretorios comuns de instalacao
    $CandidatosGS = @(
        "$env:LOCALAPPDATA\Ghostscript\bin",
        "$env:ProgramFiles\gs",
        "${env:ProgramFiles(x86)}\gs"
    )

    foreach ($dir in $CandidatosGS) {
        if ($dir -and (Test-Path $dir)) {
            $gsExe = Get-ChildItem -Path $dir -Recurse -Filter "gswin*c.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($gsExe) {
                $gsBinDir = $gsExe.DirectoryName
                $env:PATH = "$gsBinDir;$env:PATH"
                return $true
            }
        }
    }

    return $false
}

if (!(Ensure-Ghostscript)) {
    Write-Host ""
    Write-Host "AVISO / ERRO: Ghostscript nao foi encontrado no sistema!" -ForegroundColor Red
    Write-Host "O Magick.NET necessita do Ghostscript para conseguir renderizar PDFs."
    Write-Host "Instale o Ghostscript ou execute o script 'instalar_dependencias.ps1'."
    Write-Host ""
    Read-Host "Pressione ENTER para tentar continuar ou sair"
}


# ============================================================
# LOCALIZAR E CARREGAR MAGICK.NET E DEPENDENCIAS NATIVAS
# ============================================================

$Base = "$env:LOCALAPPDATA\PackageManagement\NuGet\Packages"

$Core = Get-ChildItem $Base -Recurse -Filter "Magick.NET.Core.dll" -ErrorAction SilentlyContinue |
    Where-Object FullName -Match "netstandard20" |
    Select-Object -First 1

$Magick = Get-ChildItem $Base -Recurse -Filter "Magick.NET-Q16-AnyCPU.dll" -ErrorAction SilentlyContinue |
    Where-Object FullName -Match "netstandard20" |
    Select-Object -First 1

if (!$Core -or !$Magick) {
    Write-Host ""
    Write-Host "ERRO: Bibliotecas Magick.NET nao encontradas!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Execute o script de instalacao 'instalar_dependencias.ps1' ou use:"
    Write-Host "Install-Package Magick.NET-Q16-AnyCPU -ProviderName NuGet -Scope CurrentUser"
    Write-Host ""
    Read-Host "Pressione ENTER para sair"
    exit
}

# Configura o caminho das DLLs nativas (C++) no PATH do processo
$Arch = if ([System.Environment]::Is64BitProcess) { "win-x64" } else { "win-x86" }
$NativeDir = Get-ChildItem -Path $Base -Recurse -Directory -Filter $Arch -ErrorAction SilentlyContinue |
    Where-Object { Test-Path (Join-Path $_.FullName "native") } |
    Select-Object -First 1

if ($NativeDir) {
    $NativePath = Join-Path $NativeDir.FullName "native"
    $env:PATH = "$NativePath;$env:PATH"
}

try {
    Add-Type -Path $Core.FullName -ErrorAction Stop
    Add-Type -Path $Magick.FullName -ErrorAction Stop
    Write-Host "MAGICK.NET CARREGADO COM SUCESSO!" -ForegroundColor Green
}
catch {
    Write-Host "ERRO AO CARREGAR MAGICK.NET:" -ForegroundColor Red
    Write-Host $_.Exception.ToString()
    Read-Host "Pressione ENTER para sair"
    exit
}


# ============================================================
# ESPERAR O PDF TERMINAR DE SER COPIADO (LIBERAR LOCK)
# ============================================================

function Wait-ArquivoPronto {
    param(
        [string]$Arquivo
    )

    $Tentativas = 0
    $TamanhoAnterior = -1

    while ($Tentativas -lt 60) {
        try {
            if (!(Test-Path $Arquivo)) {
                Start-Sleep -Milliseconds 500
                $Tentativas++
                continue
            }

            $Info = Get-Item $Arquivo
            $TamanhoAtual = $Info.Length

            $Stream = [System.IO.File]::Open(
                $Arquivo,
                [System.IO.FileMode]::Open,
                [System.IO.FileAccess]::Read,
                [System.IO.FileShare]::None
            )
            $Stream.Close()

            # Confirma que o tamanho parou de mudar
            if ($TamanhoAtual -gt 0 -and $TamanhoAtual -eq $TamanhoAnterior) {
                return $true
            }

            $TamanhoAnterior = $TamanhoAtual
        }
        catch {
            # Arquivo ainda esta sendo copiado ou aberto por outro processo
        }

        Start-Sleep -Milliseconds 500
        $Tentativas++
    }

    return $false
}


# ============================================================
# VERIFICAR SE JA FOI PROCESSADO
# ============================================================

function Test-JaProcessado {
    param(
        [string]$Arquivo
    )

    if (!(Test-Path $Registro)) {
        return $false
    }

    $Lista = Get-Content $Registro -ErrorAction SilentlyContinue
    return ($Lista -contains $Arquivo)
}


# ============================================================
# CONVERTER PDF PARA JPG
# ============================================================

function Converter-PDF {
    param(
        [string]$ArquivoPDF
    )

    if (!(Test-Path $ArquivoPDF)) {
        return
    }

    if ([System.IO.Path]::GetExtension($ArquivoPDF).ToLower() -ne ".pdf") {
        return
    }

    # Evita converter novamente
    if (Test-JaProcessado $ArquivoPDF) {
        Write-Host "IGNORADO: arquivo ja processado previamente." -ForegroundColor DarkYellow
        Write-Host $ArquivoPDF
        return
    }

    Write-Host ""
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "NOVO PDF DETECTADO: $ArquivoPDF" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan

    # Espera terminar de copiar
    Write-Host "Aguardando liberacao do arquivo..."
    if (!(Wait-ArquivoPronto $ArquivoPDF)) {
        Write-Host "ERRO: arquivo permaneceu bloqueado ou incompleto." -ForegroundColor Red
        return
    }

    $Imagens = $null
    try {
        Write-Host "Convertendo para JPG..."

        # Configuracao de leitura
        $Settings = New-Object ImageMagick.MagickReadSettings
        $Settings.Density = New-Object ImageMagick.Density($DPI, $DPI)

        # Carregar PDF
        $Imagens = New-Object ImageMagick.MagickImageCollection
        $Imagens.Read($ArquivoPDF, $Settings)

        $NomeBase = [System.IO.Path]::GetFileNameWithoutExtension($ArquivoPDF)
        $TotalPaginas = $Imagens.Count
        Write-Host "Paginas encontradas: $TotalPaginas" -ForegroundColor Green

        # Converter cada pagina
        for ($i = 0; $i -lt $TotalPaginas; $i++) {
            $Imagem = $Imagens[$i]
            $Imagem.Format = [ImageMagick.MagickFormat]::Jpg
            $Imagem.Quality = $QualidadeJPG

            if ($TotalPaginas -eq 1) {
                $NomeSaida = "$NomeBase.jpg"
            }
            else {
                $NumeroPagina = $i + 1
                $NomeSaida = "${NomeBase}_pagina_${NumeroPagina}.jpg"
            }

            $Destino = Join-Path $PastaSaida $NomeSaida
            $Imagem.Write($Destino)

            Write-Host "JPG criado: $Destino" -ForegroundColor Green
        }

        # Registrar PDF como processado
        Add-Content -Path $Registro -Value $ArquivoPDF

        Write-Host ""
        Write-Host "CONVERSAO CONCLUIDA COM SUCESSO!" -ForegroundColor Green
        Write-Host "Aguardando proximo PDF..."
        Write-Host ""
    }
    catch {
        Write-Host ""
        Write-Host "============================================" -ForegroundColor Red
        Write-Host "ERRO NA CONVERSAO: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "============================================" -ForegroundColor Red
        Write-Host ""
    }
    finally {
        if ($Imagens) {
            $Imagens.Dispose()
        }
    }
}


# ============================================================
# PROCESSAR ARQUIVOS QUE JA ESTEJAM NA PASTA AO INICIAR
# ============================================================

Write-Host "Verificando se existem arquivos pendentes em $PastaEntrada..."
$ArquivosIniciais = Get-ChildItem -Path $PastaEntrada -Filter "*.pdf" -File -ErrorAction SilentlyContinue
if ($ArquivosIniciais) {
    foreach ($arq in $ArquivosIniciais) {
        Converter-PDF $arq.FullName
    }
}


# ============================================================
# CONFIGURAR FILESYSTEMWATCHER (CREATED E RENAMED)
# ============================================================

$Watcher = New-Object System.IO.FileSystemWatcher
$Watcher.Path = $PastaEntrada
$Watcher.Filter = "*.pdf"
$Watcher.IncludeSubdirectories = $false
$Watcher.NotifyFilter = [System.IO.NotifyFilters]::FileName -bor [System.IO.NotifyFilters]::LastWrite
$Watcher.EnableRaisingEvents = $true

$Action = {
    $ArquivoNovo = $Event.SourceEventArgs.FullPath
    Start-Sleep -Milliseconds 500
    Converter-PDF $ArquivoNovo
}

Register-ObjectEvent `
    -InputObject $Watcher `
    -EventName Created `
    -SourceIdentifier "MonitorNovoPDF_Created" `
    -Action $Action | Out-Null

Register-ObjectEvent `
    -InputObject $Watcher `
    -EventName Renamed `
    -SourceIdentifier "MonitorNovoPDF_Renamed" `
    -Action $Action | Out-Null


# ============================================================
# TELA INICIAL DO MONITOR
# ============================================================

Clear-Host
Write-Host "============================================" -ForegroundColor Yellow
Write-Host "       MONITOR PDF -> JPG ATIVO" -ForegroundColor Yellow
Write-Host "============================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "PASTA DE ENTRADA: $PastaEntrada"
Write-Host "PASTA DE SAIDA  : $PastaSaida"
Write-Host "RESOLUCAO (DPI) : $DPI"
Write-Host "QUALIDADE JPG   : $QualidadeJPG%"
Write-Host "HISTORICO       : $Registro"
Write-Host ""
Write-Host "Aguardando novos PDFs..." -ForegroundColor Cyan
Write-Host "Pressione CTRL + C para encerrar."
Write-Host ""


# ============================================================
# LOOP PRINCIPAL
# ============================================================

try {
    while ($true) {
        Wait-Event -Timeout 3600 | Out-Null
    }
}
finally {
    Write-Host "`nEncerrando monitor..." -ForegroundColor Yellow
    Unregister-Event -SourceIdentifier "MonitorNovoPDF_Created" -ErrorAction SilentlyContinue
    Unregister-Event -SourceIdentifier "MonitorNovoPDF_Renamed" -ErrorAction SilentlyContinue
    $Watcher.Dispose()
    Write-Host "Monitor finalizado com sucesso." -ForegroundColor Gray
}
