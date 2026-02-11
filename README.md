# GoNews - Agregador de Notícias com IA e Telegram

Coleta, cura (com IA) e envia notícias automaticamente para o Telegram com preview de imagem.

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

## 📝 Dependências

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

## 📚 Arquivos do Projeto

```
gonews.go              # Script principal (630 linhas)
go.mod                 # Módulo Go
.env.example           # Template de configuração
.gitignore             # Ignora arquivos sensíveis
README.md              # Esta documentação
QUICKSTART.txt         # Guia visual rápido
prompt_v2.txt          # Prompt otimizado para IA
ENV_CONFIG.txt         # Guia detalhado de configuração
FINAL_CHANGES.txt      # Changelog detalhado
```

**Arquivos gerados (não commitados):**
```
.env                        # Suas credenciais (em .gitignore)
rss_feeds_metadata.json     # Metadados dos feeds
news_selected.json          # Notícias selecionadas pela IA
news_today_full.json        # Notícias com corpo completo
```

## 🆘 Suporte

**Problemas comuns:**

1. **Bot não responde**: Verifique se o token está correto
2. **Mensagens não chegam**: Confirme o chat_id
3. **Compilação falha**: Use Go 1.21 ou superior
4. **Feed não carrega**: Verifique se a URL está acessível

## 📄 Licença

MIT License - Use livremente, modifique como quiser.

---

**Feito com ❤️ para automatizar sua curadoria de notícias**