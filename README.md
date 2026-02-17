# GoNews

Coleta, cura (com IA) e envia notícias automaticamente para o Telegram.

## 🎯 Fluxo de Trabalho

```
1. Coleta metadados → 2. IA seleciona → 3. Extrai corpo → 4. Envia Telegram
   (GoNews)              (você/IA)        (GoNews)          (GoNews)
```

## 🚀 Uso Rápido

### 1️⃣ Coletar Metadados
```bash
go run gonews.go
```
**Output**: `rss_feeds_metadata.json` (~500 linhas, 13 feeds)

### 2️⃣ Analisar com IA
```bash
opencode run --model google/gemini-3-pro-preview "Execute o prompt_v2.txt"
```
**Output**: `news_selected.json` (10-20 notícias selecionadas)

### 3️⃣ Extrair Corpo Completo
```bash
go run gonews.go --extract-full news_selected.json
```
**Output**: `news_today_full.json` (com artigos completos)

### 4️⃣ Enviar para Telegram
```bash
go run gonews.go --send-telegram news_today_full.json
```

---

## 🤖 Automação com run.sh

O script `run.sh` executa todo o fluxo automaticamente, com suporte a cron, logging estruturado e tratamento de erros.

### Pré-requisitos

Antes de usar o script, certifique-se de que o arquivo `.env` está configurado (veja a seção [Configuração](#️-configuração)):

```bash
cp .env.example .env
nano .env
```

### Execução

```bash
# Tornar executável (apenas na primeira vez)
chmod +x run.sh

# Executar o processo completo
./run.sh

# Ou explicitamente
./run.sh --all
```

### Opções disponíveis

| Opção | Descrição |
|-------|-----------|
| `--all`, `-a` | Executa as 4 etapas completas (padrão) |
| `--collect`, `-c` | Apenas Etapa 1: Coletar metadados |
| `--ai` | Apenas Etapa 2: Análise com IA |
| `--extract`, `-e` | Apenas Etapa 3: Extrair corpo completo |
| `--send`, `-s` | Apenas Etapa 4: Enviar para Telegram |
| `--clean` | Limpar logs antigos |
| `--archive` | Arquivar JSONs do dia anterior |
| `--status` | Mostrar status dos arquivos gerados |
| `--help`, `-h` | Exibir ajuda |

### Agendamento com Cron

Para executar automaticamente todo dia às 8h:

```bash
crontab -e
```

Adicione a linha:

```cron
0 8 * * * /caminho/para/run.sh --all >> /caminho/para/logs/cron.log 2>&1
```

> **Importante:** Use sempre o caminho absoluto para o script no cron.

### Logs

Os logs são salvos em `logs/` com timestamp por etapa:

```
logs/
├── step1_20260211_080001.log   # Coleta de metadados
├── step2_20260211_080035.log   # Análise com IA
├── step3_20260211_081102.log   # Extração de corpo
└── step4_20260211_081305.log   # Envio para Telegram
```

Logs mais antigos que `KEEP_LOGS_DAYS` (padrão: 2 dias) são removidos automaticamente.

### Variáveis do .env para o run.sh

Além das credenciais do Telegram, o `run.sh` lê as seguintes variáveis do `.env`:

| Variável | Obrigatória | Descrição |
|----------|-------------|-----------|
| `PROJECT_DIR` | ✅ Sim | Caminho absoluto do projeto (ex: `/home/user/go_news/`) |
| `GO_NEWS` | ✅ Sim | Caminho do binário gonews (ex: `/usr/bin/gonews`) |
| `GO` | ✅ Sim | Caminho do binário go (ex: `/usr/local/go/bin/go`) |
| `OPENCODE` | ✅ Sim | Caminho do binário opencode (ex: `/home/user/.opencode/bin/opencode`) |
| `LOG_DIR` | ⬜ Não | Diretório de logs (padrão: `${PROJECT_DIR}logs`) |
| `METADATA_FILE` | ⬜ Não | Caminho do JSON de metadados (padrão: `${PROJECT_DIR}rss_feeds_metadata.json`) |
| `SELECTED_FILE` | ⬜ Não | Caminho do JSON selecionado (padrão: `${PROJECT_DIR}news_selected.json`) |
| `FULL_FILE` | ⬜ Não | Caminho do JSON completo (padrão: `${PROJECT_DIR}news_today_full.json`) |
| `PROMPT_FILE` | ⬜ Não | Caminho do arquivo de prompt (padrão: `${PROJECT_DIR}prompt.txt`) |
| `AI_MODEL` | ⬜ Não | Modelo de IA (padrão: `opencode/minimax-m2.5-free`) |
| `KEEP_LOGS_DAYS` | ⬜ Não | Dias para manter logs (padrão: `2`) |

---

## 📋 Comandos

| Comando | Descrição |
|---------|-----------|
| `go run gonews.go` | Coleta metadados de 13 feeds RSS |
| `go run gonews.go --extract-full <arquivo>` | Extrai corpo completo das notícias |
| `go run gonews.go --send-telegram <arquivo>` | Envia notícias para o Telegram |

## 📰 Fontes de Notícias

**Internacional (Inglês):**
- BBC News (Home, World, Technology)
- New York Times
- The Guardian
- Reuters
- Al Jazeera

**Brasil (Português):**
- Folha de S.Paulo (Tech, Política, Mundo, Mercado)
- G1
- Agência Brasil

## ⚙️ Configuração

### Telegram Bot

**IMPORTANTE**: O GoNews usa variáveis de ambiente para armazenar credenciais de forma segura.

#### Método 1: Arquivo .env (Recomendado)

1. Copie o template:
```bash
cp .env.example .env
```

2. Edite o arquivo `.env`:
```bash
nano .env
```

3. Adicione suas credenciais:
```env
TELEGRAM_BOT_TOKEN=seu_token_aqui
TELEGRAM_CHAT_ID=seu_chat_id_aqui
```

#### Método 2: Variáveis de Ambiente do Sistema

**Linux/macOS:**
```bash
export TELEGRAM_BOT_TOKEN="seu_token"
export TELEGRAM_CHAT_ID="seu_chat_id"
```

**Windows PowerShell:**
```powershell
$env:TELEGRAM_BOT_TOKEN = "seu_token"
$env:TELEGRAM_CHAT_ID = "seu_chat_id"
```

**Como criar um bot:**
1. Fale com [@BotFather](https://t.me/botfather) no Telegram
2. Use `/newbot` e siga as instruções
3. Copie o token fornecido
4. Para obter o Chat ID:
   - Use [@userinfobot](https://t.me/userinfobot) (mais fácil)
   - Ou envie uma mensagem para o bot e acesse:
     ```
     https://api.telegram.org/bot<SEU_TOKEN>/getUpdates
     ```
   - Procure por `"chat":{"id":XXXXXXX`

**Arquivo .env.example incluído** com instruções detalhadas.

### Adicionar/Remover Feeds

Edite a variável `feedURLs`:

```go
var feedURLs = []string{
    "https://seu-feed.com/rss.xml",
    // ...
}
```

## 📊 Estrutura dos Arquivos

### `rss_feeds_metadata.json` (Etapa 1)
```json
{
  "fetched_at": "2025-02-11T15:30:00Z",
  "total_items": 287,
  "items": [
    {
      "title": "Título da notícia",
      "link": "https://...",
      "description": "Resumo breve",
      "pub_date": "Mon, 10 Feb 2025 12:30:00 GMT",
      "source": "BBC News",
      "category": ["Politics"]
    }
  ]
}
```

### `news_selected.json` (você cria com IA)
```json
[
  {
    "title": "Título original",
    "source": "BBC News",
    "link": "https://...",
    "pub_date": "Mon, 10 Feb 2025 12:30:00 GMT",
    "summary": "Resumo de 2-3 frases",
    "category": "Politics"
  }
]
```

### `news_today_full.json` (Etapa 3)
```json
{
  "generated_at": "2025-02-11T16:45:00Z",
  "total_articles": 15,
  "articles_extracted": 14,
  "articles": [
    {
      "title": "Título",
      "source": "BBC News",
      "link": "https://...",
      "pub_date": "Mon, 10 Feb 2025 12:30:00 GMT",
      "summary": "Resumo curado pela IA",
      "category": "Politics",
      "full_article": "Corpo completo extraído...",
      "article_extracted": true
    }
  ]
}
```

## 💡 Prompt para IA

Use o arquivo `prompt_v2.txt` fornecido ou personalize:

```
Analise rss_feeds_metadata.json e selecione 10-20 notícias mais relevantes.

Critérios:
- Impacto global, política, economia, tecnologia, segurança
- Remover duplicatas (mesmo evento, fontes diferentes)
- Manter idioma original
- Notícias das últimas 24h

Output: news_selected.json com estrutura específica
```

## 📱 Formato das Mensagens Telegram

As mensagens são enviadas com formato limpo e preview de imagem:

```
*Título da Notícia em Negrito*

Descrição curta e objetiva da notícia curada pela IA.
Resumo conciso em 2-3 frases no idioma original.

📅 Data: 15:30, 11/02/2026
📂 Categoria: Politics
🔗 https://link-da-noticia.com

[Preview de imagem do site aparece aqui]
[Botão INSTANT VIEW se disponível]
```

### Características:

- ✅ **Formato simples e profissional**
- ✅ **Preview de imagem/link habilitado**
- ✅ **Summary da IA** (conciso, não corpo completo)
- ✅ **Data brasileira**: HH:MM, DD/MM/AAAA (timezone Brasília)
- ✅ **Emojis organizados**: 📅 Data, 📂 Categoria
- ✅ **Visual limpo** igual a canais de notícias profissionais

## ⚡ Performance

| Etapa | Tempo | Descrição |
|-------|-------|-----------|
| Etapa 1 | ~30s | Coleta 287 itens de 13 feeds |
| IA | ~1min | Analisa e seleciona ~15 notícias |
| Etapa 2 | ~2min | Extrai corpo de 15 artigos |
| Etapa 3 | ~15s | Envia 15 mensagens no Telegram |
| **Total** | **~4min** | Processo completo |

## 🛡️ Proteções

- Rate limiting entre requests (300-500ms)
- Timeouts de 10s por artigo
- Decodificação completa de entidades HTML (35+ entidades)
- Extração inteligente de conteúdo principal
- Limpeza de tags e elementos não desejados
- Fallback para summary se extração falhar

## 📦 Dependências

Apenas biblioteca padrão do Go:
- `encoding/json`
- `encoding/xml`
- `net/http`
- `regexp`
- `time`
- `strings`

Não requer instalação de pacotes externos.

## 🔐 Segurança

**Proteção de Credenciais:**
- ✅ Credenciais em variáveis de ambiente (fora do código)
- ✅ Arquivo `.env` no `.gitignore` (não vai para Git)
- ✅ Template `.env.example` sem dados sensíveis
- ✅ Validação de credenciais antes de usar

**Boas práticas:**
- Nunca commite o arquivo `.env`
- Use `.env` em desenvolvimento
- Use variáveis de ambiente do sistema em produção
- Revogue tokens expostos acidentalmente em [@BotFather](https://t.me/botfather)

## 🔧 Troubleshooting

**Erro: "Arquivo .env não encontrado"**
- Crie o arquivo `.env` a partir do `.env.example`
- O `.env` deve estar na mesma pasta que o `run.sh`
- Verifique permissões de leitura do arquivo

**Erro: "Variável obrigatória não definida no .env: PROJECT_DIR"**
- Abra o `.env` e preencha as variáveis obrigatórias: `PROJECT_DIR`, `GO_NEWS`, `GO`, `OPENCODE`
- Certifique-se de que os caminhos são absolutos e corretos

**Erro: "TELEGRAM_BOT_TOKEN não está definido"**
- Crie o arquivo `.env` a partir do `.env.example`
- Ou defina as variáveis de ambiente do sistema
- Verifique se o arquivo `.env` está na mesma pasta que `gonews.go`

**Erro: syntax error in gonews.go**
- Certifique-se de usar a versão mais recente do arquivo
- Verifique se não há aspas tipográficas (", ") no código

**Telegram API error 401**:
- Token inválido ou expirado
- Crie um novo bot com @BotFather
- Copie o token correto para o `.env`

**Telegram API error 400**:
- Verifique o chat_id no arquivo `.env`
- Confirme que o bot foi iniciado (envie `/start` para o bot)
- Para grupos: adicione o bot como administrador

**Preview de imagem não aparece**:
- Normal - depende do site ter Open Graph tags
- A maioria dos sites de notícias tem preview
- O link ainda funciona mesmo sem imagem

**Extração de artigo retorna texto estranho**:
- Alguns sites têm proteção anti-scraping
- O summary da IA ainda é enviado
- A notícia fica legível mesmo sem o corpo completo

**IA retorna JSON inválido**:
- Revise o prompt para ser mais específico
- Peça explicitamente "JSON válido"
- Use exemplos no prompt

**run.sh falha em cron mas funciona manualmente**:
- Verifique se o `.env` contém os caminhos absolutos de `GO_NEWS`, `GO` e `OPENCODE`
- O cron não herda o `PATH` do usuário — caminhos absolutos são obrigatórios
- Confirme que o script tem permissão de execução: `chmod +x run.sh`

## 🎨 Customização

### Alterar formato da mensagem

Edite a função `sendToTelegram()` em `gonews.go`:

```go
text := fmt.Sprintf(
    "*%s*\n\n"+
    "%s\n\n"+
    "📅 Data: %s\n"+
    "📂 Categoria: %s\n"+
    "🔗 %s",
    news.Title,
    description,
    formattedDate,
    news.Category,
    news.Link,
)
```

### Desabilitar preview de imagem

```go
DisableWebPagePreview: true,  // false = com preview
```

### Alterar tamanho da descrição

```go
if len(description) > 500 {  // Altere este número
    description = description[:500]
    // ...
}
```

### Alterar retenção de logs

No `.env`:
```env
KEEP_LOGS_DAYS=7   # Manter logs por 7 dias
```

### Alterar modelo de IA

No `.env`:
```env
AI_MODEL=google/gemini-3-pro-preview
```

## 🆘 Suporte

**Problemas comuns:**

1. **Bot não responde**: Verifique se o token está correto
2. **Mensagens não chegam**: Confirme o chat_id
3. **Compilação falha**: Use Go 1.21 ou superior
4. **Feed não carrega**: Verifique se a URL está acessível
5. **run.sh não inicia**: Confirme que o `.env` está preenchido corretamente

## 📄 Licença

MIT License - Use livremente, modifique como quiser.

---

**Feito com ❤️ para automatizar sua curadoria de notícias**