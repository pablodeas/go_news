#!/usr/bin/env bash

#==============================================================================
# GoNews - Script de Automação (Otimizado para Cron)
#==============================================================================

set -u  # Erro em variáveis não definidas

#==============================================================================
# CONFIGURAÇÃO - CARREGADO DO ARQUIVO .env (ESSENCIAL PARA CRON)
#==============================================================================

# Localiza o .env relativo ao script ou no diretório atual
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

if [ -f "$ENV_FILE" ]; then
    # Exporta apenas variáveis válidas (ignora comentários e linhas vazias)
    set -o allexport
    # shellcheck source=/dev/null
    source "$ENV_FILE"
    set +o allexport
else
    echo "[ERRO] Arquivo .env não encontrado em: $ENV_FILE"
    echo "       Crie o arquivo .env com as variáveis necessárias."
    exit 1
fi

# Validar variáveis obrigatórias do .env
_required_vars=(PROJECT_DIR GO_NEWS GO OPENCODE)
_missing=0
for _var in "${_required_vars[@]}"; do
    if [ -z "${!_var:-}" ]; then
        echo "[ERRO] Variável obrigatória não definida no .env: $_var"
        ((_missing++))
    fi
done
[ $_missing -gt 0 ] && exit 1

# Derivar caminhos a partir de PROJECT_DIR (podem ser sobrescritos no .env)
LOG_DIR="${LOG_DIR:-${PROJECT_DIR}logs}"

# Arquivos
METADATA_FILE="${METADATA_FILE:-${PROJECT_DIR}rss_feeds_metadata.json}"
SELECTED_FILE="${SELECTED_FILE:-${PROJECT_DIR}news_selected.json}"
FULL_FILE="${FULL_FILE:-${PROJECT_DIR}news_today_full.json}"
PROMPT_FILE="${PROMPT_FILE:-${PROJECT_DIR}prompt.txt}"

# Configuração
AI_MODEL="${AI_MODEL:-opencode/minimax-m2.5-free}"
KEEP_LOGS_DAYS="${KEEP_LOGS_DAYS:-2}"  # Manter logs por X dias

#==============================================================================
# CORES (apenas se terminal interativo)
#==============================================================================

if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' CYAN='' BOLD='' NC=''
fi

#==============================================================================
# FUNÇÕES DE LOGGING
#==============================================================================

log_message() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        INFO)
            echo -e "${CYAN}[$timestamp]${NC} ${BLUE}▶${NC} $message"
            ;;
        SUCCESS)
            echo -e "${CYAN}[$timestamp]${NC} ${GREEN}✓${NC} $message"
            ;;
        ERROR)
            echo -e "${CYAN}[$timestamp]${NC} ${RED}✗${NC} $message" >&2
            ;;
        WARNING)
            echo -e "${CYAN}[$timestamp]${NC} ${YELLOW}⚠${NC} $message"
            ;;
        HEADER)
            echo ""
            echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════════${NC}"
            echo -e "${CYAN}${BOLD}  $message${NC}"
            echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════════${NC}"
            echo ""
            ;;
        *)
            echo "[$timestamp] $level $message"
            ;;
    esac
}

#==============================================================================
# FUNÇÕES AUXILIARES
#==============================================================================

# Extrai estatísticas de arquivos JSON
# Uso: extract_json_stat "arquivo.json" "campo" "valor_padrão"
# Campos suportados: total_items, total_articles, articles_extracted, title_count
extract_json_stat() {
    local file="$1"
    local field="$2"
    local default="${3:-0}"
    
    if [ ! -f "$file" ]; then
        echo "$default"
        return 1
    fi
    
    local value
    case "$field" in
        total_items|total_articles|articles_extracted)
            # Extrai valores numéricos de campos JSON
            value=$(grep -o "\"$field\":[0-9]*" "$file" | grep -o '[0-9]*' || echo "$default")
            ;;
        title_count)
            # Conta ocorrências do campo "title"
            value=$(grep -o '"title"' "$file" | wc -l || echo "$default")
            ;;
        *)
            echo "$default"
            return 1
            ;;
    esac
    
    echo "$value"
}

#==============================================================================
# VERIFICAÇÕES INICIAIS
#==============================================================================

check_dependencies() {
    log_message INFO "Verificando dependências e ambiente..."
    
    local errors=0
    
    # Verificar executáveis
    for cmd in "$GO_NEWS:GoNews" "$GO:Go" "$OPENCODE:OpenCode"; do
        local path="${cmd%:*}"
        local name="${cmd#*:}"
        
        if [ -f "$path" ] && [ -x "$path" ]; then
            log_message SUCCESS "$name encontrado: $path"
        else
            log_message ERROR "$name não encontrado ou sem permissão: $path"
            ((errors++))
        fi
    done
    
    # Verificar diretório do projeto
    if [ -d "$PROJECT_DIR" ]; then
        log_message SUCCESS "Diretório do projeto: $PROJECT_DIR"
    else
        log_message ERROR "Diretório do projeto não encontrado: $PROJECT_DIR"
        ((errors++))
    fi
    
    # Criar diretório de logs se não existir
    if [ ! -d "$LOG_DIR" ]; then
        if mkdir -p "$LOG_DIR"; then
            log_message SUCCESS "Diretório de logs criado: $LOG_DIR"
        else
            log_message ERROR "Não foi possível criar diretório de logs: $LOG_DIR"
            ((errors++))
        fi
    else
        log_message SUCCESS "Diretório de logs: $LOG_DIR"
    fi
    
    # Verificar arquivo .env
    if [ -f "${PROJECT_DIR}.env" ]; then
        log_message SUCCESS "Arquivo .env encontrado"
    else
        log_message WARNING "Arquivo .env não encontrado (necessário para Telegram)"
    fi
    
    # Verificar arquivo de prompt
    if [ -f "$PROMPT_FILE" ]; then
        log_message SUCCESS "Arquivo de prompt encontrado"
    else
        log_message WARNING "Arquivo prompt.txt não encontrado (necessário para IA)"
    fi
    
    if [ $errors -gt 0 ]; then
        log_message ERROR "Encontrado(s) $errors erro(s). Verifique a configuração."
        return 1
    fi
    
    log_message SUCCESS "Todas as verificações passaram"
    return 0
}

#==============================================================================
# ETAPA 1: COLETA DE METADADOS
#==============================================================================

step1_collect() {
    log_message HEADER "ETAPA 1: Coleta de Metadados"
    
    local log_file="${LOG_DIR}/step1_$(date +%Y%m%d_%H%M%S).log"
    local start_time=$(date +%s)
    
    log_message INFO "Executando: $GO_NEWS"
    log_message INFO "Diretório: $PROJECT_DIR"
    log_message INFO "Log: $log_file"
    
    if cd "$PROJECT_DIR" && "$GO_NEWS" > "$log_file" 2>&1; then
        local duration=$(($(date +%s) - start_time))
        log_message SUCCESS "Step1 concluído (${duration}s)"
        
        # Verificar e mostrar estatísticas
        if [ -f "$METADATA_FILE" ]; then
            local total=$(extract_json_stat "$METADATA_FILE" "total_items" "?")
            local size=$(du -h "$METADATA_FILE" 2>/dev/null | cut -f1 || echo "?")
            log_message SUCCESS "Arquivo: $METADATA_FILE ($size)"
            log_message INFO "Total de itens coletados: $total"
        else
            log_message WARNING "Arquivo $METADATA_FILE não encontrado"
        fi
        
        return 0
    else
        local exit_code=$?
        log_message ERROR "Step1 falhou (código: $exit_code)"
        log_message ERROR "Verifique o log: $log_file"
        return 1
    fi
}

#==============================================================================
# ETAPA 2: ANÁLISE COM IA
#==============================================================================

step2_ai_analysis() {
    log_message HEADER "ETAPA 2: Análise com IA"
    
    local log_file="${LOG_DIR}/step2_$(date +%Y%m%d_%H%M%S).log"
    local start_time=$(date +%s)
    
    # Validar arquivos necessários
    if [ ! -f "$METADATA_FILE" ]; then
        log_message ERROR "Arquivo de entrada não encontrado: $METADATA_FILE"
        return 1
    fi
    
    if [ ! -f "$PROMPT_FILE" ]; then
        log_message ERROR "Arquivo de prompt não encontrado: $PROMPT_FILE"
        return 1
    fi
    
    log_message INFO "Executando: $OPENCODE"
    log_message INFO "Modelo: $AI_MODEL"
    log_message INFO "Prompt: $PROMPT_FILE"
    log_message INFO "Log: $log_file"
    
    #if cd "$PROJECT_DIR" && "$OPENCODE" run --model "$AI_MODEL" "Execute o prompt.txt" > "$log_file" 2>&1; then
    if cd "$PROJECT_DIR" && "$OPENCODE" run "Execute o prompt.txt" > "$log_file" 2>&1; then
        local duration=$(($(date +%s) - start_time))
        log_message SUCCESS "Step2 concluído (${duration}s)"
        
        # Verificar e mostrar estatísticas
        if [ -f "$SELECTED_FILE" ]; then
            local count=$(extract_json_stat "$SELECTED_FILE" "title_count" "?")
            local size=$(du -h "$SELECTED_FILE" 2>/dev/null | cut -f1 || echo "?")
            log_message SUCCESS "Arquivo: $SELECTED_FILE ($size)"
            log_message INFO "Notícias selecionadas pela IA: $count"
        else
            log_message WARNING "Arquivo $SELECTED_FILE não encontrado"
        fi
        
        return 0
    else
        local exit_code=$?
        log_message ERROR "Step2 falhou (código: $exit_code)"
        log_message ERROR "Verifique o log: $log_file"
        return 1
    fi
}

#==============================================================================
# ETAPA 3: EXTRAÇÃO DE CORPO COMPLETO
#==============================================================================

step3_extract() {
    log_message HEADER "ETAPA 3: Extração de Corpo Completo"
    
    local log_file="${LOG_DIR}/step3_$(date +%Y%m%d_%H%M%S).log"
    local start_time=$(date +%s)
    
    # Validar arquivo necessário
    if [ ! -f "$SELECTED_FILE" ]; then
        log_message ERROR "Arquivo de entrada não encontrado: $SELECTED_FILE"
        return 1
    fi
    
    log_message INFO "Executando: $GO_NEWS --extract-full"
    log_message INFO "Entrada: news_selected.json"
    log_message INFO "Log: $log_file"
    
    if cd "$PROJECT_DIR" && "$GO_NEWS" --extract-full news_selected.json > "$log_file" 2>&1; then
        local duration=$(($(date +%s) - start_time))
        log_message SUCCESS "Step3 concluído (${duration}s)"
        
        # Verificar e mostrar estatísticas
        if [ -f "$FULL_FILE" ]; then
            local total=$(extract_json_stat "$FULL_FILE" "total_articles" "?")
            local extracted=$(extract_json_stat "$FULL_FILE" "articles_extracted" "?")
            local size=$(du -h "$FULL_FILE" 2>/dev/null | cut -f1 || echo "?")
            log_message SUCCESS "Arquivo: $FULL_FILE ($size)"
            log_message INFO "Artigos processados: $total"
            log_message INFO "Extrações bem-sucedidas: $extracted"
        else
            log_message WARNING "Arquivo $FULL_FILE não encontrado"
        fi
        
        return 0
    else
        local exit_code=$?
        log_message ERROR "Step3 falhou (código: $exit_code)"
        log_message ERROR "Verifique o log: $log_file"
        return 1
    fi
}

#==============================================================================
# ETAPA 4: ENVIO PARA TELEGRAM
#==============================================================================

step4_send() {
    log_message HEADER "ETAPA 4: Envio para Telegram"
    
    local log_file="${LOG_DIR}/step4_$(date +%Y%m%d_%H%M%S).log"
    local start_time=$(date +%s)
    
    # Validar arquivo necessário
    if [ ! -f "$FULL_FILE" ]; then
        log_message ERROR "Arquivo de entrada não encontrado: $FULL_FILE"
        return 1
    fi
    
    log_message INFO "Executando: $GO_NEWS --send-telegram"
    log_message INFO "Entrada: news_today_full.json"
    log_message INFO "Log: $log_file"
    
    if cd "$PROJECT_DIR" && "$GO_NEWS" --send-telegram news_today_full.json > "$log_file" 2>&1; then
        local duration=$(($(date +%s) - start_time))
        log_message SUCCESS "Step4 concluído (${duration}s)"
        log_message SUCCESS "Notícias enviadas para o Telegram!"
        return 0
    else
        local exit_code=$?
        log_message ERROR "Step4 falhou (código: $exit_code)"
        log_message ERROR "Verifique o log: $log_file"
        return 1
    fi
}

#==============================================================================
# LIMPEZA E MANUTENÇÃO
#==============================================================================

cleanup_old_logs() {
    log_message INFO "Removendo logs antigos (>${KEEP_LOGS_DAYS} dias)..."
    
    # Verificar se LOG_DIR existe
    if [ ! -d "$LOG_DIR" ]; then
        log_message WARNING "Diretório de logs não encontrado: $LOG_DIR"
        return 1
    fi
    
    # Contar arquivos antes de deletar
    local count=$(find "$LOG_DIR" -name "*.log" -type f -mtime +$KEEP_LOGS_DAYS 2>/dev/null | wc -l)
    
    if [ "$count" -eq 0 ]; then
        log_message INFO "Nenhum log antigo para remover"
        return 0
    fi
    
    # Listar arquivos que serão removidos (para debug)
    log_message INFO "Arquivos a serem removidos:"
    find "$LOG_DIR" -name "*.log" -type f -mtime +$KEEP_LOGS_DAYS -exec basename {} \;
    
    # Deletar arquivos
    find "$LOG_DIR" -name "*.log" -type f -mtime +$KEEP_LOGS_DAYS -exec rm -f {} \;
    local result=$?
    
    if [ $result -eq 0 ]; then
        log_message SUCCESS "Removidos $count arquivo(s) de log"
    else
        log_message ERROR "Erro ao remover logs (código: $result)"
        return 1
    fi
}

archive_old_json() {
    log_message INFO "Arquivando JSONs anteriores..."
    
    local archive_dir="${PROJECT_DIR}archive/$(date +%Y%m)"
    
    if [ ! -d "$archive_dir" ]; then
        mkdir -p "$archive_dir" || {
            log_message WARNING "Não foi possível criar diretório de arquivo: $archive_dir"
            return 1
        }
    fi
    
    local archived=0
    for file in "$METADATA_FILE" "$SELECTED_FILE" "$FULL_FILE"; do
        if [ -f "$file" ]; then
            local basename=$(basename "$file" .json)
            local archive_name="${archive_dir}/${basename}_$(date +%Y%m%d_%H%M%S).json"
            if mv "$file" "$archive_name"; then
                ((archived++))
                log_message INFO "Arquivado: $(basename "$file")"
            else
                log_message WARNING "Falha ao arquivar: $(basename "$file")"
            fi
        fi
    done
    
    [ $archived -gt 0 ] && log_message SUCCESS "Arquivados $archived arquivo(s)"
}

#==============================================================================
# RESUMO E ESTATÍSTICAS
#==============================================================================

show_summary() {
    log_message HEADER "📊 Resumo da Execução"
    
    echo -e "${BOLD}Configuração:${NC}"
    echo -e "  Projeto: ${CYAN}$PROJECT_DIR${NC}"
    echo -e "  Logs: ${CYAN}$LOG_DIR${NC}"
    echo ""
    
    echo -e "${BOLD}Arquivos Gerados:${NC}"
    
    check_file() {
        local file="$1"
        local desc="$2"
        
        if [ -f "$file" ]; then
            local size=$(du -h "$file" 2>/dev/null | cut -f1 || echo "?")
            local time=$(date -r "$file" '+%H:%M:%S' 2>/dev/null || echo "?")
            echo -e "  ${GREEN}✓${NC} $desc ${CYAN}($size, $time)${NC}"
            return 0
        else
            echo -e "  ${RED}✗${NC} $desc ${YELLOW}(não encontrado)${NC}"
            return 1
        fi
    }
    
    local files_ok=0
    check_file "$METADATA_FILE" "Metadados" && ((files_ok++))
    check_file "$SELECTED_FILE" "IA Selecionadas" && ((files_ok++))
    check_file "$FULL_FILE" "Corpo Completo" && ((files_ok++))
    
    echo ""
    echo -e "${BOLD}Estatísticas:${NC}"
    
    if [ -f "$METADATA_FILE" ]; then
        local total=$(extract_json_stat "$METADATA_FILE" "total_items" "0")
        echo -e "  Itens coletados: ${CYAN}$total${NC}"
    fi
    
    if [ -f "$SELECTED_FILE" ]; then
        local selected=$(extract_json_stat "$SELECTED_FILE" "title_count" "0")
        echo -e "  Selecionados pela IA: ${CYAN}$selected${NC}"
    fi
    
    if [ -f "$FULL_FILE" ]; then
        local total=$(extract_json_stat "$FULL_FILE" "total_articles" "0")
        local extracted=$(extract_json_stat "$FULL_FILE" "articles_extracted" "0")
        echo -e "  Artigos extraídos: ${CYAN}$extracted/$total${NC}"
    fi
    
    echo ""
    return $files_ok
}

#==============================================================================
# EXECUTAR TUDO
#==============================================================================

run_all() {
    local overall_start=$(date +%s)
    local start_timestamp=$(date '+%d/%m/%Y às %H:%M:%S')
    
    log_message HEADER "🗞️  GoNews - Execução Automática"
    
    echo -e "${CYAN}Início: $start_timestamp${NC}"
    echo -e "${CYAN}Diretório: $PROJECT_DIR${NC}"
    echo ""
    
    # Array para rastrear falhas
    local -a failed_steps=()
    
    # Verificar dependências
    if ! check_dependencies; then
        log_message ERROR "Verificação de dependências falhou"
        return 1
    fi
    
    echo ""
    
    # Executar etapas
    step1_collect || failed_steps+=("Step1")
    step2_ai_analysis || failed_steps+=("Step2")
    step3_extract || failed_steps+=("Step3")
    step4_send || failed_steps+=("Step4")
    
    # Manutenção
    echo ""
    log_message INFO "Executando manutenção..."
    cleanup_old_logs
    
    # Resumo
    echo ""
    show_summary
    local files_ok=$?
    
    # Resultado final
    local overall_duration=$(($(date +%s) - overall_start))
    local minutes=$((overall_duration / 60))
    local seconds=$((overall_duration % 60))
    
    echo ""
    log_message HEADER "Resultado Final"
    
    if [ ${#failed_steps[@]} -eq 0 ]; then
        echo -e "${GREEN}${BOLD}✅ Processo concluído com sucesso!${NC}"
        echo -e "${GREEN}   Todas as 4 etapas executadas sem erros${NC}"
    else
        echo -e "${RED}${BOLD}⚠️  Processo concluído com erros${NC}"
        echo -e "${RED}   Etapas com falha: ${failed_steps[*]}${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}Tempo total: ${BOLD}${minutes}m ${seconds}s${NC}"
    echo -e "${CYAN}Término: $(date '+%d/%m/%Y às %H:%M:%S')${NC}"
    echo ""
    
    # Retornar código de erro se houve falhas
    [ ${#failed_steps[@]} -eq 0 ]
}

#==============================================================================
# OPÇÕES DE LINHA DE COMANDO
#==============================================================================

show_help() {
    cat << HELP
Uso: $0 [opção]

Opções:
  --all, -a         Executar processo completo (padrão)
  --collect, -c     Apenas Step1: Coletar metadados
  --ai              Apenas Step2: Análise com IA
  --extract, -e     Apenas Step3: Extrair corpo completo
  --send, -s        Apenas Step4: Enviar para Telegram
  --clean           Limpar logs antigos
  --archive         Arquivar JSONs antigos
  --status          Mostrar status dos arquivos
  --help, -h        Mostrar esta ajuda

Exemplos:
  $0                  # Executar tudo
  $0 --all            # Executar tudo (explícito)
  $0 --status         # Ver status
  $0 --clean          # Limpar logs

Para usar no cron:
  0 8 * * * $0 --all >> $LOG_DIR/cron.log 2>&1

HELP
}

#==============================================================================
# MAIN
#==============================================================================

main() {
    case "${1:-}" in
        --all|-a|"")
            run_all
            ;;
        --collect|-c)
            check_dependencies && step1_collect
            ;;
        --ai)
            step2_ai_analysis
            ;;
        --extract|-e)
            step3_extract
            ;;
        --send|-s)
            step4_send
            ;;
        --clean)
            cleanup_old_logs
            ;;
        --archive)
            archive_old_json
            ;;
        --status)
            show_summary
            ;;
        --help|-h)
            show_help
            ;;
        *)
            echo "Opção inválida: $1"
            echo "Use --help para ver as opções disponíveis"
            exit 1
            ;;
    esac
}

# Executar
main "$@"