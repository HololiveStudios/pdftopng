# PDF to PNG - Monitor e Conversor Automático de Documentos

## 1. Objetivo e Finalidade
Serviço utilitário com monitoramento contínuo de pastas para conversão automática de páginas de arquivos PDF em imagens PNG de alta resolução.

## 2. Tecnologias Utilizadas
- PowerShell, Batch Script, Poppler / Ghostscript / ImageMagick

## 3. Arquitetura e Estrutura de Diretórios
Módulo utilitário baseado em scripts PowerShell (`monitor_pdf_jpg.ps1`) com gatilhos em lote (`.bat`) para instalação e inicialização transparente em ambiente Windows.

## 4. Principais Arquivos e Responsabilidades
- `1_INSTALAR_DEPENDENCIAS.bat`: Script de instalação automática de dependências.
- `2_INICIAR_MONITOR.bat`: Inicializador do serviço de monitoramento.
- `monitor_pdf_jpg.ps1`: Script PowerShell com FileSystemWatcher ativo.
- `GUIA_INSTALACAO_OUTRO_PC.md`: Manual completo de instalação e uso.

## 5. Funcionalidades Identificadas
- Monitoramento automático de diretório de entrada
- Conversão em tempo real sem necessidade de interação do usuário
- Registro de controle de arquivos convertidos em `processados.txt`
- Manual detalhado para portabilidade entre computadores

## 6. Como Compilar ou Executar
```cmd
1_INSTALAR_DEPENDENCIAS.bat
2_INICIAR_MONITOR.bat
```

## 7. Estado Atual do Projeto
**Completo**

## 8. Pendências e Limitações Identificadas
Adicionar script equivalente para ambientes Linux usando `inotifywait` e `pdftoppm`.
