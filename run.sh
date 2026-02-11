#!/usr/bin/env sh

#!/bin/bash

#==============================================================================
# GoNews - Script de Automação Completa
# Automatiza: Coleta → IA → Extração → Telegram
#==============================================================================

set -e  # Sair em caso de erro

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configurações
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
METADATA_FILE="rss_feeds_metadata.json"
SELECTED_FILE="news_selected.json"
FULL_FILE="news_today_full.json"
PROMPT_FILE="prompt.txt"

#==============================================================================
# FUNÇÕES AUXILIARES
#==============================================================================

print_header() {
    echo -e "${CYAN}"
    echo "═══════════════════════════════════════════════════════════════════"
    echo "  $1"
    echo "═══════════════════════════════════════════════════════════════════"
    echo -e "${NC}"
}

print_step() {
    echo -e "${BLUE}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

check_file_exists() {
    if [ ! -f "$1" ]; then
        print_error "Arquivo não encontrado: $1"
        exit 1
    fi
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        print_error "Comando '$1' não encontrado. Instale antes de continuar."
        exit 1
    fi
}

#==============================================================================
# VERIFICAÇÕES INICIAIS
#==============================================================================

check_dependencies() {
    print_step "Verificando dependências..."
    
    check_command "go"
    print_success "Go encontrado: $(go version)"
    
    if command -v opencode &> /dev/null; then
        print_success "OpenCode encontrado"
    else
        print_warning "OpenCode não encontrado (necessário para IA)"
    fi
    
    # Verificar .env
    if [ ! -f ".env" ]; then
        print_warning "Arquivo .env não encontrado"
        echo -e "${YELLOW}Crie o arquivo .env com suas credenciais do Telegram:${NC}"
        echo "  cp .env.example .env"
        echo "  # Edite .env com seu token e chat_id"
        exit 1
    fi
    
    print_success "Arquivo .env encontrado"
    echo ""
}

#==============================================================================
# ETAPA 1: COLETA DE METADADOS
#==============================================================================

step1_collect() {
    print_header "ETAPA 1: Coleta de Metadados"
    
    print_step "Coletando notícias dos feeds RSS..."
    go run gonews
    
    if [ -f "$METADATA_FILE" ]; then
        TOTAL_ITEMS=$(grep -o '"total_items":[0-9]*' "$METADATA_FILE" | grep -o '[0-9]*')
        print_success "Metadados coletados: $TOTAL_ITEMS itens"
        print_success "Arquivo gerado: $METADATA_FILE"
    else
        print_error "Falha ao gerar $METADATA_FILE"
        exit 1
    fi
    echo ""
}

#==============================================================================
# ETAPA 2: ANÁLISE COM IA
#==============================================================================

step2_ai_analysis() {
    print_header "ETAPA 2: Análise com IA"
    
    check_file_exists "$METADATA_FILE"
    check_file_exists "$PROMPT_FILE"
    
    # Verificar se opencode está disponível
    if ! command -v opencode &> /dev/null; then
        print_warning "OpenCode não instalado. Executando manualmente..."
        echo ""
        echo -e "${YELLOW}Execute o comando:${NC}"
        echo "  opencode run \"Execute o $PROMPT_FILE\""
        echo ""
        echo -e "${YELLOW}Ou crie manualmente o arquivo $SELECTED_FILE${NC}"
        echo ""
        read -p "Pressione ENTER após gerar $SELECTED_FILE..."
    else
        print_step "Executando análise com IA..."
        opencode run "Execute o $PROMPT_FILE"
    fi

    # Verificar se o arquivo foi gerado
    if [ ! -f "$SELECTED_FILE" ]; then
        print_error "Arquivo $SELECTED_FILE não foi gerado"
        print_warning "Crie o arquivo manualmente e execute novamente"
        exit 1
    fi
    
    SELECTED_COUNT=$(grep -o '"title"' "$SELECTED_FILE" | wc -l)
    print_success "IA selecionou: $SELECTED_COUNT notícias"
    print_success "Arquivo gerado: $SELECTED_FILE"
    echo ""
}

#==============================================================================
# ETAPA 3: EXTRAÇÃO DE CORPO COMPLETO
#==============================================================================

step3_extract() {
    print_header "ETAPA 3: Extração de Corpo Completo"
    
    check_file_exists "$SELECTED_FILE"
    
    print_step "Extraindo corpo completo dos artigos..."
    go run gonews --extract-full "$SELECTED_FILE"
    
    if [ -f "$FULL_FILE" ]; then
        TOTAL=$(grep -o '"total_articles":[0-9]*' "$FULL_FILE" | grep -o '[0-9]*')
        EXTRACTED=$(grep -o '"articles_extracted":[0-9]*' "$FULL_FILE" | grep -o '[0-9]*')
        print_success "Artigos processados: $TOTAL"
        print_success "Extrações bem-sucedidas: $EXTRACTED"
        print_success "Arquivo gerado: $FULL_FILE"
    else
        print_error "Falha ao gerar $FULL_FILE"
        exit 1
    fi
    echo ""
}

#==============================================================================
# ETAPA 4: ENVIO PARA TELEGRAM
#==============================================================================

step4_send() {
    print_header "ETAPA 4: Envio para Telegram"
    
    check_file_exists "$FULL_FILE"
    
    print_step "Enviando notícias para o Telegram..."
    go run gonews --send-telegram "$FULL_FILE"
    
    print_success "Notícias enviadas para o Telegram!"
    echo ""
}

#==============================================================================
# FUNÇÃO PRINCIPAL
#==============================================================================

run_all() {
    print_header "🗞️  GoNews - Automação Completa"
    echo -e "${CYAN}Início: $(date '+%H:%M:%S - %d/%m/%Y')${NC}"
    echo ""
    
    START_TIME=$(date +%s)
    
    check_dependencies
    step1_collect
    step2_ai_analysis
    step3_extract
    step4_send
    
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    MINUTES=$((DURATION / 60))
    SECONDS=$((DURATION % 60))
    
    print_header "✅ Processo Concluído"
    echo -e "${GREEN}Tempo total: ${MINUTES}m ${SECONDS}s${NC}"
    echo -e "${CYAN}Fim: $(date '+%H:%M:%S - %d/%m/%Y')${NC}"
    echo ""
}

#==============================================================================
# FUNÇÕES DE LIMPEZA
#==============================================================================

clean() {
    print_header "🧹 Limpeza de Arquivos"
    
    print_step "Removendo arquivos gerados..."
    
    rm -f "$METADATA_FILE" && echo "  - $METADATA_FILE"
    rm -f "$SELECTED_FILE" && echo "  - $SELECTED_FILE"
    rm -f "$FULL_FILE" && echo "  - $FULL_FILE"
    
    print_success "Arquivos removidos"
}

#==============================================================================
# MENU INTERATIVO
#==============================================================================

show_menu() {
    clear
    print_header "GoNews - Menu Principal"
    echo ""
    echo "  1) Executar processo completo (automático)"
    echo "  2) Etapa 1: Coletar metadados"
    echo "  3) Etapa 2: Análise com IA (manual)"
    echo "  4) Etapa 3: Extrair corpo completo"
    echo "  5) Etapa 4: Enviar para Telegram"
    echo "  6) Limpar arquivos gerados"
    echo "  7) Verificar status dos arquivos"
    echo "  0) Sair"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

check_status() {
    print_header "📊 Status dos Arquivos"
    
    check_file() {
        if [ -f "$1" ]; then
            SIZE=$(du -h "$1" | cut -f1)
            echo -e "${GREEN}✓${NC} $1 ${CYAN}($SIZE)${NC}"
        else
            echo -e "${RED}✗${NC} $1 ${YELLOW}(não encontrado)${NC}"
        fi
    }
    
    check_file ".env"
    check_file "$METADATA_FILE"
    check_file "$SELECTED_FILE"
    check_file "$FULL_FILE"
    echo ""
}

interactive_menu() {
    while true; do
        show_menu
        read -p "Escolha uma opção: " choice
        echo ""
        
        case $choice in
            1)
                run_all
                read -p "Pressione ENTER para continuar..."
                ;;
            2)
                check_dependencies
                step1_collect
                read -p "Pressione ENTER para continuar..."
                ;;
            3)
                step2_ai_analysis
                read -p "Pressione ENTER para continuar..."
                ;;
            4)
                step3_extract
                read -p "Pressione ENTER para continuar..."
                ;;
            5)
                step4_send
                read -p "Pressione ENTER para continuar..."
                ;;
            6)
                clean
                read -p "Pressione ENTER para continuar..."
                ;;
            7)
                check_status
                read -p "Pressione ENTER para continuar..."
                ;;
            0)
                echo "Saindo..."
                exit 0
                ;;
            *)
                print_error "Opção inválida!"
                sleep 2
                ;;
        esac
    done
}

#==============================================================================
# ARGUMENTOS DE LINHA DE COMANDO
#==============================================================================

show_usage() {
    echo "Uso: $0 [opção]"
    echo ""
    echo "Opções:"
    echo "  --all, -a       Executar processo completo"
    echo "  --collect, -c   Apenas coletar metadados"
    echo "  --extract, -e   Apenas extrair corpo completo"
    echo "  --send, -s      Apenas enviar para Telegram"
    echo "  --clean         Limpar arquivos gerados"
    echo "  --status        Verificar status dos arquivos"
    echo "  --menu, -m      Menu interativo"
    echo "  --help, -h      Mostrar esta ajuda"
    echo ""
    echo "Exemplos:"
    echo "  $0 --all        # Executar tudo automaticamente"
    echo "  $0 --menu       # Menu interativo"
    echo "  $0 --status     # Ver status dos arquivos"
}

#==============================================================================
# MAIN
#==============================================================================

main() {
    # Se não houver argumentos, mostrar menu
    if [ $# -eq 0 ]; then
        interactive_menu
        exit 0
    fi
    
    # Processar argumentos
    case "$1" in
        --all|-a)
            run_all
            ;;
        --collect|-c)
            check_dependencies
            step1_collect
            ;;
        --extract|-e)
            step3_extract
            ;;
        --send|-s)
            step4_send
            ;;
        --clean)
            clean
            ;;
        --status)
            check_status
            ;;
        --menu|-m)
            interactive_menu
            ;;
        --help|-h)
            show_usage
            ;;
        *)
            print_error "Opção inválida: $1"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

main "$@"