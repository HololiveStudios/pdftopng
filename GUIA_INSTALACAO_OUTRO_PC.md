# Guia Completo: Instalação e Execução do Monitor PDF -> JPG em Outro Computador

Este guia documenta todas as alterações feitas no código e no computador para que o script funcione perfeitamente em qualquer máquina Windows.

---

## 1. O que foi diagnosticado e corrigido

| Problema Encontrado | Causa Técnica | Solução Aplicada |
| :--- | :--- | :--- |
| **Provedor NuGet ausente** | O PowerShell 5.1 não vem com o provedor NuGet instalado por padrão. | Instalado via `Install-PackageProvider -Name NuGet -Scope CurrentUser`. |
| **Erro ao buscar Magick.NET** | O repositório `nuget.org` não vem registrado como origem de pacotes no Windows. | Registrado via `Register-PackageSource -Name nuget.org ...`. |
| **Exceção `DllNotFoundException: Magick.Native-Q16-x64.dll`** | O .NET Framework 4.8 não busca automaticamente DLLs nativas na subpasta `runtimes\win-x64\native`. | O script agora localiza a pasta da DLL nativa e adiciona temporariamente ao `PATH`. |
| **Erro `FailedToExecuteCommand "gswin64c.exe"`** | O Magick.NET necessita obrigatoriamente do **Ghostscript** para rasterizar páginas de PDF. | Ghostscript instalado e sua pasta `bin` configurada no `PATH`. |
| **PDFs existentes ignorados** | O `FileSystemWatcher` só monitorava novos arquivos gerados após o script abrir. | Adicionada varredura inicial para processar qualquer PDF que já esteja em `C:\PDF`. |
| **Arquivos renomeados não processados** | Downloads de navegador ou transferências salvam temporários e depois renomeiam para `.pdf`. | Adicionado tratamento do evento `Renamed` além de `Created`. |

---

## 2. Como Instalar no Novo Computador

### Método 1: Instalação Automática (Recomendado)

1. Copie esta pasta (`pdftopng`) para o novo computador.
2. Abra o **PowerShell** (não precisa ser como Administrador).
3. Navegue até a pasta ou execute o script de instalação:
   ```powershell
   powershell.exe -ExecutionPolicy Bypass -File ".\instalar_dependencias.ps1"
   ```
4. O script fará tudo sozinho:
   - Ativa TLS 1.2
   - Instala o provedor NuGet
   - Registra o repositório nuget.org
   - Baixa e instala a biblioteca `Magick.NET-Q16-AnyCPU`
   - Baixa e configura o `Ghostscript`
   - Cria as pastas `C:\PDF` e `C:\JPG`

---

### Método 2: Instalação Manual (Passo a Passo)

Caso queira fazer manualmente no outro computador, execute no PowerShell:

```powershell
# 1. Habilitar TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

# 2. Instalar o Provedor NuGet
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser

# 3. Registrar o nuget.org
Register-PackageSource -Name nuget.org -Location https://www.nuget.org/api/v2 -ProviderName NuGet -Trusted -Force

# 4. Instalar o Magick.NET
Install-Package Magick.NET-Q16-AnyCPU -ProviderName NuGet -Scope CurrentUser -Force

# 5. Instalar o Ghostscript
# Baixe a versao 64-bit do Ghostscript (gs...w64.exe) em:
# https://github.com/ArtifexSoftware/ghostpdl-downloads/releases
# Instale no computador e certifique-se de que a pasta bin (ex: C:\Program Files\gs\gs10.xx\bin ou AppData\Local\Ghostscript\bin) esteja no PATH.

# 6. Criar pastas de trabalho
New-Item -ItemType Directory -Path "C:\PDF" -Force
New-Item -ItemType Directory -Path "C:\JPG" -Force
```

---

## 3. Como Executar o Monitor

Para iniciar o monitoramento contínuo:

```powershell
powershell.exe -ExecutionPolicy Bypass -File ".\monitor_pdf_jpg.ps1"
```

Ou clique com o botão direito em `monitor_pdf_jpg.ps1` e selecione **"Executar com o PowerShell"**.

- Ao colar ou salvar qualquer arquivo `.pdf` em `C:\PDF`, ele será convertido automaticamente para imagem JPG em `C:\JPG`.
- Os arquivos processados ficam registrados em `processados.txt` para evitar repetições.
- Para encerrar o monitor, pressione `CTRL + C` na janela do PowerShell.
