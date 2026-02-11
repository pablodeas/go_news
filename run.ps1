#==============================================================================
# GoNews - Script de Automação para Windows (PowerShell)
# Automatiza: Coleta → IA → Extração → Telegram
#==============================================================================

$ErrorActionPreference = "Stop"

# Configurações
$MetadataFile = "rss_feeds_metadata.json"
$SelectedFile = "news_selected.json"
$FullFile = "news_today_full.json"
$PromptFile = "prompt_v2.txt"

#==============================================================================
# FUNÇÕES AUXILIARES
#==============================================================================

function Print-Header {
    param([string]$Message)
    Write-Host "`n═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  $Message" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan
}

function Print-Step {
    param([string]$Message)
    Write-Host "▶ $Message" -ForegroundColor Blue
}

function Print-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Print-Error {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

function Print-Warning {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor Yellow
}

function Check-Command {
    param([string]$Command)
    if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
        Print-Error "Comando '$Command' não encontrado"
        exit 1
    }
}

#==============================================================================
# VERIFICAÇÕES INICIAIS
#==============================================================================

function Check-Dependencies {
    Print-Step "Verificando dependências..."
    
    Check-Command "go"
    $goVersion = go version
    Print-Success "Go encontrado: $goVersion"
    
    if (Get-Command opencode -ErrorAction SilentlyContinue) {
        Print-Success "OpenCode encontrado"
    } else {
        Print-Warning "OpenCode não encontrado (necessário para IA)"
    }
    
    if (-not (Test-Path ".env")) {
        Print-Warning "Arquivo .env não encontrado"
        Write-Host "`nCrie o arquivo .env com suas credenciais:" -ForegroundColor Yellow
        Write-Host "  Copy-Item .env.example .env"
        Write-Host "  # Edite .env com seu token e chat_id"
        exit 1
    }
    
    Print-Success "Arquivo .env encontrado"
    Write-Host ""
}

#==============================================================================
# ETAPA 1: COLETA DE METADADOS
#==============================================================================

function Step1-Collect {
    Print-Header "ETAPA 1: Coleta de Metadados"
    
    Print-Step "Coletando notícias dos feeds RSS..."
    go run gonews.go
    
    if (Test-Path $MetadataFile) {
        $content = Get-Content $MetadataFile -Raw | ConvertFrom-Json
        $totalItems = $content.total_items
        Print-Success "Metadados coletados: $totalItems itens"
        Print-Success "Arquivo gerado: $MetadataFile"
    } else {
        Print-Error "Falha ao gerar $MetadataFile"
        exit 1
    }
    Write-Host ""
}

#==============================================================================
# ETAPA 2: ANÁLISE COM IA
#==============================================================================

function Step2-AIAnalysis {
    Print-Header "ETAPA 2: Análise com IA"
    
    if (-not (Test-Path $MetadataFile)) {
        Print-Error "Arquivo $MetadataFile não encontrado"
        exit 1
    }
    
    if (-not (Test-Path $PromptFile)) {
        Print-Error "Arquivo $PromptFile não encontrado"
        exit 1
    }
    
    if (-not (Get-Command opencode -ErrorAction SilentlyContinue)) {
        Print-Warning "OpenCode não instalado"
        Write-Host "`nExecute o comando:" -ForegroundColor Yellow
        Write-Host "  opencode run --model google/gemini-3-pro-preview 'Execute o $PromptFile'"
        Write-Host "`nOu crie manualmente o arquivo $SelectedFile" -ForegroundColor Yellow
        Read-Host "`nPressione ENTER após gerar $SelectedFile"
    } else {
        Print-Step "Executando análise com IA..."
        opencode run --model google/gemini-3-pro-preview "Execute o $PromptFile"
    }
    
    if (-not (Test-Path $SelectedFile)) {
        Print-Error "Arquivo $SelectedFile não foi gerado"
        Print-Warning "Crie o arquivo manualmente e execute novamente"
        exit 1
    }
    
    $content = Get-Content $SelectedFile -Raw | ConvertFrom-Json
    $selectedCount = $content.Count
    Print-Success "IA selecionou: $selectedCount notícias"
    Print-Success "Arquivo gerado: $SelectedFile"
    Write-Host ""
}

#==============================================================================
# ETAPA 3: EXTRAÇÃO DE CORPO COMPLETO
#==============================================================================

function Step3-Extract {
    Print-Header "ETAPA 3: Extração de Corpo Completo"
    
    if (-not (Test-Path $SelectedFile)) {
        Print-Error "Arquivo $SelectedFile não encontrado"
        exit 1
    }
    
    Print-Step "Extraindo corpo completo dos artigos..."
    go run gonews.go --extract-full $SelectedFile
    
    if (Test-Path $FullFile) {
        $content = Get-Content $FullFile -Raw | ConvertFrom-Json
        $total = $content.total_articles
        $extracted = $content.articles_extracted
        Print-Success "Artigos processados: $total"
        Print-Success "Extrações bem-sucedidas: $extracted"
        Print-Success "Arquivo gerado: $FullFile"
    } else {
        Print-Error "Falha ao gerar $FullFile"
        exit 1
    }
    Write-Host ""
}

#==============================================================================
# ETAPA 4: ENVIO PARA TELEGRAM
#==============================================================================

function Step4-Send {
    Print-Header "ETAPA 4: Envio para Telegram"
    
    if (-not (Test-Path $FullFile)) {
        Print-Error "Arquivo $FullFile não encontrado"
        exit 1
    }
    
    Print-Step "Enviando notícias para o Telegram..."
    go run gonews.go --send-telegram $FullFile
    
    Print-Success "Notícias enviadas para o Telegram!"
    Write-Host ""
}

#==============================================================================
# EXECUTAR TUDO
#==============================================================================

function Run-All {
    Print-Header "🗞️  GoNews - Automação Completa"
    $startTime = Get-Date
    Write-Host "Início: $($startTime.ToString('HH:mm:ss - dd/MM/yyyy'))" -ForegroundColor Cyan
    Write-Host ""
    
    Check-Dependencies
    Step1-Collect
    Step2-AIAnalysis
    Step3-Extract
    Step4-Send
    
    $endTime = Get-Date
    $duration = $endTime - $startTime
    
    Print-Header "✅ Processo Concluído"
    Write-Host "Tempo total: $($duration.Minutes)m $($duration.Seconds)s" -ForegroundColor Green
    Write-Host "Fim: $($endTime.ToString('HH:mm:ss - dd/MM/yyyy'))" -ForegroundColor Cyan
    Write-Host ""
}

#==============================================================================
# LIMPEZA
#==============================================================================

function Clean-Files {
    Print-Header "🧹 Limpeza de Arquivos"
    
    Print-Step "Removendo arquivos gerados..."
    
    if (Test-Path $MetadataFile) {
        Remove-Item $MetadataFile
        Write-Host "  - $MetadataFile"
    }
    
    if (Test-Path $SelectedFile) {
        Remove-Item $SelectedFile
        Write-Host "  - $SelectedFile"
    }
    
    if (Test-Path $FullFile) {
        Remove-Item $FullFile
        Write-Host "  - $FullFile"
    }
    
    Print-Success "Arquivos removidos"
}

#==============================================================================
# STATUS
#==============================================================================

function Check-Status {
    Print-Header "📊 Status dos Arquivos"
    
    function Check-File {
        param([string]$FileName)
        if (Test-Path $FileName) {
            $size = (Get-Item $FileName).Length
            $sizeKB = [math]::Round($size / 1KB, 2)
            Write-Host "✓ $FileName " -ForegroundColor Green -NoNewline
            Write-Host "($sizeKB KB)" -ForegroundColor Cyan
        } else {
            Write-Host "✗ $FileName " -ForegroundColor Red -NoNewline
            Write-Host "(não encontrado)" -ForegroundColor Yellow
        }
    }
    
    Check-File ".env"
    Check-File $MetadataFile
    Check-File $SelectedFile
    Check-File $FullFile
    Write-Host ""
}

#==============================================================================
# MENU INTERATIVO
#==============================================================================

function Show-Menu {
    Clear-Host
    Print-Header "GoNews - Menu Principal"
    Write-Host "  1) Executar processo completo (automático)"
    Write-Host "  2) Etapa 1: Coletar metadados"
    Write-Host "  3) Etapa 2: Análise com IA (manual)"
    Write-Host "  4) Etapa 3: Extrair corpo completo"
    Write-Host "  5) Etapa 4: Enviar para Telegram"
    Write-Host "  6) Limpar arquivos gerados"
    Write-Host "  7) Verificar status dos arquivos"
    Write-Host "  0) Sair"
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
}

function Interactive-Menu {
    while ($true) {
        Show-Menu
        $choice = Read-Host "Escolha uma opção"
        Write-Host ""
        
        switch ($choice) {
            "1" {
                Run-All
                Read-Host "Pressione ENTER para continuar"
            }
            "2" {
                Check-Dependencies
                Step1-Collect
                Read-Host "Pressione ENTER para continuar"
            }
            "3" {
                Step2-AIAnalysis
                Read-Host "Pressione ENTER para continuar"
            }
            "4" {
                Step3-Extract
                Read-Host "Pressione ENTER para continuar"
            }
            "5" {
                Step4-Send
                Read-Host "Pressione ENTER para continuar"
            }
            "6" {
                Clean-Files
                Read-Host "Pressione ENTER para continuar"
            }
            "7" {
                Check-Status
                Read-Host "Pressione ENTER para continuar"
            }
            "0" {
                Write-Host "Saindo..." -ForegroundColor Yellow
                exit 0
            }
            default {
                Print-Error "Opção inválida!"
                Start-Sleep -Seconds 2
            }
        }
    }
}

#==============================================================================
# MAIN
#==============================================================================

param(
    [switch]$All,
    [switch]$Collect,
    [switch]$Extract,
    [switch]$Send,
    [switch]$Clean,
    [switch]$Status,
    [switch]$Menu,
    [switch]$Help
)

if ($Help) {
    Write-Host "Uso: .\run.ps1 [opção]"
    Write-Host ""
    Write-Host "Opções:"
    Write-Host "  -All       Executar processo completo"
    Write-Host "  -Collect   Apenas coletar metadados"
    Write-Host "  -Extract   Apenas extrair corpo completo"
    Write-Host "  -Send      Apenas enviar para Telegram"
    Write-Host "  -Clean     Limpar arquivos gerados"
    Write-Host "  -Status    Verificar status dos arquivos"
    Write-Host "  -Menu      Menu interativo"
    Write-Host "  -Help      Mostrar esta ajuda"
    Write-Host ""
    Write-Host "Exemplos:"
    Write-Host "  .\run.ps1 -All      # Executar tudo"
    Write-Host "  .\run.ps1 -Menu     # Menu interativo"
    Write-Host "  .\run.ps1 -Status   # Ver status"
    exit 0
}

if ($All) {
    Run-All
} elseif ($Collect) {
    Check-Dependencies
    Step1-Collect
} elseif ($Extract) {
    Step3-Extract
} elseif ($Send) {
    Step4-Send
} elseif ($Clean) {
    Clean-Files
} elseif ($Status) {
    Check-Status
} elseif ($Menu) {
    Interactive-Menu
} else {
    Interactive-Menu
}