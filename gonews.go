package main

import (
	"bytes"
	"encoding/json"
	"encoding/xml"
	"fmt"
	"io"
	"net/http"
	"os"
	"regexp"
	"strings"
	"time"
)

// ============================================================================
// CONFIGURAÇÕES
// ============================================================================

// Variáveis de ambiente (carregadas no init)
var (
	TelegramBotToken string
	TelegramChatID   string
)

func init() {
	// Carregar variáveis de ambiente do arquivo .env se existir
	loadEnvFile(".env")

	// Obter variáveis de ambiente
	TelegramBotToken = os.Getenv("TELEGRAM_BOT_TOKEN")
	TelegramChatID = os.Getenv("TELEGRAM_CHAT_ID")

	// Validar se as variáveis obrigatórias estão definidas
	if TelegramBotToken == "" {
		fmt.Println("⚠️  TELEGRAM_BOT_TOKEN não está definido")
		fmt.Println("   Configure no arquivo .env ou como variável de ambiente")
	}

	if TelegramChatID == "" {
		fmt.Println("⚠️  TELEGRAM_CHAT_ID não está definido")
		fmt.Println("   Configure no arquivo .env ou como variável de ambiente")
	}
}

var feedURLs = []string{
	//// BBC
	//"http://feeds.bbci.co.uk/news/rss.xml",
	//"https://feeds.bbci.co.uk/news/world/rss.xml",
	//"https://feeds.bbci.co.uk/news/technology/rss.xml",
	//// New York Times
	//"https://rss.nytimes.com/services/xml/rss/nyt/HomePage.xml",
	//// The Guardian
	//"https://www.theguardian.com/world/rss",
	//// Reuters
	//"https://www.reuters.com/tools/rss",
	//// Al Jazeera
	//"https://www.aljazeera.com/xml/rss/all.xml",
	//// Folha de São Paulo
	//"https://feeds.folha.uol.com.br/tec/rss091.xml",
	//"https://feeds.folha.uol.com.br/poder/rss091.xml",
	//"https://feeds.folha.uol.com.br/mundo/rss091.xml",
	//"https://feeds.folha.uol.com.br/mercado/rss091.xml",
	// G1
	"https://g1.globo.com/rss/g1/",
	//// Agência Brasil
	//"https://agenciabrasil.ebc.com.br/rss/ultimasnoticias/feed.xml",
}

// ============================================================================
// ESTRUTURAS DE DADOS
// ============================================================================

// RSS structures
type RSS struct {
	Channel Channel `xml:"channel"`
}

type Channel struct {
	Title string `xml:"title"`
	Items []Item `xml:"item"`
}

type Item struct {
	Title       string   `xml:"title"`
	Link        string   `xml:"link"`
	Description string   `xml:"description"`
	PubDate     string   `xml:"pubDate"`
	Category    []string `xml:"category"`
}

// Metadata structures (compacto para IA)
type MetadataOutput struct {
	FetchedAt  string         `json:"fetched_at"`
	TotalItems int            `json:"total_items"`
	Items      []MetadataItem `json:"items"`
}

type MetadataItem struct {
	Title       string   `json:"title"`
	Link        string   `json:"link"`
	Description string   `json:"description"`
	PubDate     string   `json:"pub_date"`
	Source      string   `json:"source"`
	Category    []string `json:"category,omitempty"`
}

// Selected news structure (da IA)
type SelectedNews struct {
	Title       string `json:"title"`
	Source      string `json:"source"`
	Link        string `json:"link"`
	PubDate     string `json:"pub_date"`
	Summary     string `json:"summary"`
	Category    string `json:"category"`
	Description string `json:"description,omitempty"`
}

// Final output structure
type FinalOutput struct {
	GeneratedAt       string      `json:"generated_at"`
	TotalArticles     int         `json:"total_articles"`
	ArticlesExtracted int         `json:"articles_extracted"`
	Articles          []FinalNews `json:"articles"`
}

type FinalNews struct {
	Title            string `json:"title"`
	Source           string `json:"source"`
	Link             string `json:"link"`
	PubDate          string `json:"pub_date"`
	Summary          string `json:"summary"`
	Category         string `json:"category"`
	FullArticle      string `json:"full_article"`
	ArticleExtracted bool   `json:"article_extracted"`
}

// Telegram structures
type TelegramMessage struct {
	ChatID                string `json:"chat_id"`
	Text                  string `json:"text"`
	ParseMode             string `json:"parse_mode"`
	DisableWebPagePreview bool   `json:"disable_web_page_preview"`
}

// ============================================================================
// FUNÇÃO PRINCIPAL
// ============================================================================

func main() {
	if len(os.Args) > 1 {
		switch os.Args[1] {
		case "--extract-full":
			if len(os.Args) < 3 {
				fmt.Println("Uso: go run gonews.go --extract-full <arquivo_selecionadas.json>")
				os.Exit(1)
			}
			extractFullArticles(os.Args[2])
		case "--send-telegram":
			if len(os.Args) < 3 {
				fmt.Println("Uso: go run gonews.go --send-telegram <arquivo_noticias.json>")
				os.Exit(1)
			}
			sendAllToTelegram(os.Args[2])
		default:
			fmt.Println("Comandos disponíveis:")
			fmt.Println("  go run gonews.go                              # Coleta metadados")
			fmt.Println("  go run gonews.go --extract-full <arquivo>     # Extrai corpo completo")
			fmt.Println("  go run gonews.go --send-telegram <arquivo>    # Envia para Telegram")
			os.Exit(1)
		}
		return
	}

	// ETAPA 1: Coleta de metadados
	collectMetadata()
}

// ============================================================================
// ETAPA 1: COLETA DE METADADOS
// ============================================================================

func collectMetadata() {
	fmt.Printf("=== GoNews - Etapa 1: Coleta de Metadados ===\n")
	fmt.Printf("Feeds a processar: %d\n\n", len(feedURLs))

	var allItems []MetadataItem

	for i, feedURL := range feedURLs {
		fmt.Printf("[%d/%d] %s\n", i+1, len(feedURLs), feedURL)

		items := fetchFeedMetadata(feedURL)
		allItems = append(allItems, items...)

		time.Sleep(300 * time.Millisecond)
	}

	output := MetadataOutput{
		FetchedAt:  time.Now().Format(time.RFC3339),
		TotalItems: len(allItems),
		Items:      allItems,
	}

	saveJSON(output, "rss_feeds_metadata.json")

	fmt.Printf("\n%s\n", strings.Repeat("=", 70))
	fmt.Printf("✓ Metadados salvos: rss_feeds_metadata.json\n")
	fmt.Printf("  Total de itens: %d\n", len(allItems))
	fmt.Printf("\n📝 Próximo passo:\n")
	fmt.Printf("  Analise com IA e gere news_selected.json\n")
	fmt.Printf("%s\n", strings.Repeat("=", 70))
}

func fetchFeedMetadata(feedURL string) []MetadataItem {
	resp, err := http.Get(feedURL)
	if err != nil {
		fmt.Printf("  ❌ Erro: %v\n", err)
		return nil
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		fmt.Printf("  ❌ Status: %d\n", resp.StatusCode)
		return nil
	}

	body, _ := io.ReadAll(resp.Body)
	var rss RSS
	if err := xml.Unmarshal(body, &rss); err != nil {
		fmt.Printf("  ❌ Parse error: %v\n", err)
		return nil
	}

	items := make([]MetadataItem, 0, len(rss.Channel.Items))
	for _, item := range rss.Channel.Items {
		items = append(items, MetadataItem{
			Title:       item.Title,
			Link:        item.Link,
			Description: item.Description,
			PubDate:     item.PubDate,
			Source:      rss.Channel.Title,
			Category:    item.Category,
		})
	}

	fmt.Printf("  ✓ %s (%d itens)\n", rss.Channel.Title, len(items))
	return items
}

// ============================================================================
// ETAPA 2: EXTRAÇÃO DE CORPO COMPLETO
// ============================================================================

func extractFullArticles(inputFile string) {
	fmt.Printf("\n=== GoNews - Etapa 2: Extração de Corpo Completo ===\n\n")

	data, err := os.ReadFile(inputFile)
	if err != nil {
		fmt.Printf("❌ Erro ao ler %s: %v\n", inputFile, err)
		os.Exit(1)
	}

	var selectedNews []SelectedNews
	if err := json.Unmarshal(data, &selectedNews); err != nil {
		fmt.Printf("❌ Erro ao parsear JSON: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("📰 Notícias selecionadas: %d\n\n", len(selectedNews))

	finalNews := make([]FinalNews, 0, len(selectedNews))
	successCount := 0

	for i, news := range selectedNews {
		fmt.Printf("[%d/%d] %s\n", i+1, len(selectedNews), truncate(news.Title, 60))

		fullArticle, extracted := extractArticleContent(news.Link)

		finalNews = append(finalNews, FinalNews{
			Title:            news.Title,
			Source:           news.Source,
			Link:             news.Link,
			PubDate:          news.PubDate,
			Summary:          news.Summary,
			Category:         news.Category,
			FullArticle:      fullArticle,
			ArticleExtracted: extracted,
		})

		if extracted {
			successCount++
			fmt.Printf("  ✓ Extraído (%d chars)\n", len(fullArticle))
		} else {
			fmt.Printf("  ⚠️  Falha: %s\n", fullArticle)
		}

		time.Sleep(500 * time.Millisecond)
	}

	output := FinalOutput{
		GeneratedAt:       time.Now().Format(time.RFC3339),
		TotalArticles:     len(finalNews),
		ArticlesExtracted: successCount,
		Articles:          finalNews,
	}

	saveJSON(output, "news_today_full.json")

	fmt.Printf("\n%s\n", strings.Repeat("=", 70))
	fmt.Printf("✓ Arquivo gerado: news_today_full.json\n")
	fmt.Printf("  Total: %d | Sucesso: %d\n", len(finalNews), successCount)
	fmt.Printf("\n📱 Próximo passo:\n")
	fmt.Printf("  go run gonews.go --send-telegram news_today_full.json\n")
	fmt.Printf("%s\n", strings.Repeat("=", 70))
}

func extractArticleContent(url string) (string, bool) {
	if url == "" {
		return "URL vazia", false
	}

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Get(url)
	if err != nil {
		return fmt.Sprintf("Erro: %v", err), false
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Sprintf("Status: %d", resp.StatusCode), false
	}

	body, _ := io.ReadAll(resp.Body)
	return extractTextFromHTML(string(body)), true
}

func extractTextFromHTML(html string) string {
	// Remove scripts, styles, comments
	html = regexp.MustCompile(`(?is)<script[^>]*>.*?</script>`).ReplaceAllString(html, "")
	html = regexp.MustCompile(`(?is)<style[^>]*>.*?</style>`).ReplaceAllString(html, "")
	html = regexp.MustCompile(`(?s)<!--.*?-->`).ReplaceAllString(html, "")

	// Extract main content
	patterns := []string{
		`(?is)<article[^>]*>(.*?)</article>`,
		`(?is)<main[^>]*>(.*?)</main>`,
		`(?is)<div[^>]*class="[^"]*(?:article|content|story|post|entry)[^"]*"[^>]*>(.*?)</div>`,
		`(?is)<div[^>]*id="[^"]*(?:article|content|story|post|entry)[^"]*"[^>]*>(.*?)</div>`,
	}

	var content string
	for _, pattern := range patterns {
		if matches := regexp.MustCompile(pattern).FindStringSubmatch(html); len(matches) > 1 && len(matches[1]) > 200 {
			content = matches[1]
			break
		}
	}

	if content == "" {
		if matches := regexp.MustCompile(`(?is)<body[^>]*>(.*?)</body>`).FindStringSubmatch(html); len(matches) > 1 {
			content = matches[1]
		} else {
			content = html
		}
	}

	// Remove tags HTML mantendo o texto
	content = regexp.MustCompile(`<br\s*/?>|<p\s*/?>|</p>`).ReplaceAllString(content, "\n")
	content = regexp.MustCompile(`<[^>]+>`).ReplaceAllString(content, " ")

	// Decodificar entidades HTML COMPLETAS
	content = decodeHTMLEntities(content)

	// Limpar espaços múltiplos mas manter quebras de linha
	lines := strings.Split(content, "\n")
	var cleanLines []string
	for _, line := range lines {
		line = strings.TrimSpace(line)
		line = regexp.MustCompile(`\s+`).ReplaceAllString(line, " ")
		if line != "" && len(line) > 10 { // Ignorar linhas muito curtas (lixo)
			cleanLines = append(cleanLines, line)
		}
	}
	content = strings.Join(cleanLines, "\n\n")

	// Limitar tamanho
	if len(content) > 50000 {
		content = content[:50000]
	}

	return content
}

// decodeHTMLEntities decodifica todas as entidades HTML comuns
func decodeHTMLEntities(text string) string {
	// Entidades nomeadas
	entities := map[string]string{
		"&nbsp;":   " ",
		"&amp;":    "&",
		"&lt;":     "<",
		"&gt;":     ">",
		"&quot;":   "\"",
		"&#34;":    "\"",
		"&#39;":    "'",
		"&apos;":   "'",
		"&ndash;":  "–",
		"&mdash;":  "—",
		"&lsquo;":  "'",
		"&rsquo;":  "'",
		"&ldquo;":  "\"",
		"&rdquo;":  "\"",
		"&hellip;": "…",
		"&bull;":   "•",
		"&middot;": "·",
		"&copy;":   "©",
		"&reg;":    "®",
		"&trade;":  "™",
		"&euro;":   "€",
		"&pound;":  "£",
		"&yen;":    "¥",
		"&cent;":   "¢",
		"&deg;":    "°",
		"&plusmn;": "±",
		"&times;":  "×",
		"&divide;": "÷",
		"&ne;":     "≠",
		"&le;":     "≤",
		"&ge;":     "≥",
		"&para;":   "¶",
		"&sect;":   "§",
	}

	for entity, char := range entities {
		text = strings.ReplaceAll(text, entity, char)
	}

	// Entidades numéricas decimais &#123;
	re := regexp.MustCompile(`&#(\d+);`)
	text = re.ReplaceAllStringFunc(text, func(match string) string {
		matches := re.FindStringSubmatch(match)
		if len(matches) > 1 {
			var num int
			if _, err := fmt.Sscanf(matches[1], "%d", &num); err == nil {
				if num > 0 && num < 1114112 {
					return string(rune(num))
				}
			}
		}
		return match
	})

	// Entidades numéricas hexadecimais &#x1F;
	reHex := regexp.MustCompile(`&#[xX]([0-9A-Fa-f]+);`)
	text = reHex.ReplaceAllStringFunc(text, func(match string) string {
		matches := reHex.FindStringSubmatch(match)
		if len(matches) > 1 {
			var num int
			if _, err := fmt.Sscanf(matches[1], "%x", &num); err == nil {
				if num > 0 && num < 1114112 {
					return string(rune(num))
				}
			}
		}
		return match
	})

	return text
}

// ============================================================================
// ETAPA 3: ENVIO PARA TELEGRAM
// ============================================================================

func sendAllToTelegram(inputFile string) {
	fmt.Printf("\n=== GoNews - Envio para Telegram ===\n\n")

	// Validar configuração do Telegram
	if TelegramBotToken == "" || TelegramChatID == "" {
		fmt.Println("❌ Erro: Configuração do Telegram incompleta")
		fmt.Println("\nCrie um arquivo .env com:")
		fmt.Println("TELEGRAM_BOT_TOKEN=seu_token_aqui")
		fmt.Println("TELEGRAM_CHAT_ID=seu_chat_id_aqui")
		fmt.Println("\nOu defina as variáveis de ambiente:")
		fmt.Println("export TELEGRAM_BOT_TOKEN=seu_token")
		fmt.Println("export TELEGRAM_CHAT_ID=seu_chat_id")
		os.Exit(1)
	}

	data, err := os.ReadFile(inputFile)
	if err != nil {
		fmt.Printf("❌ Erro ao ler %s: %v\n", inputFile, err)
		os.Exit(1)
	}

	var output FinalOutput
	if err := json.Unmarshal(data, &output); err != nil {
		fmt.Printf("❌ Erro ao parsear JSON: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("📰 Notícias a enviar: %d\n\n", len(output.Articles))

	for i, news := range output.Articles {
		fmt.Printf("[%d/%d] %s\n", i+1, len(output.Articles), truncate(news.Title, 60))

		if err := sendToTelegram(news); err != nil {
			fmt.Printf("  ❌ Erro: %v\n", err)
		} else {
			fmt.Printf("  ✓ Enviado\n")
		}

		time.Sleep(1 * time.Second)
	}

	fmt.Printf("\n%s\n", strings.Repeat("=", 70))
	fmt.Printf("✅ Concluído! %d notícias enviadas\n", len(output.Articles))
	fmt.Printf("%s\n", strings.Repeat("=", 70))
}

func sendToTelegram(news FinalNews) error {
	// Formatar data de forma legível
	formattedDate := formatPubDate(news.PubDate)

	// Usar a descrição/summary ao invés do corpo completo
	description := news.Summary
	if description == "" {
		description = news.FullArticle
		// Limitar a 500 caracteres se for o corpo completo
		if len(description) > 500 {
			description = description[:500]
			lastPeriod := strings.LastIndex(description, ".")
			if lastPeriod > 300 {
				description = description[:lastPeriod+1]
			}
		}
	}

	// Formatar mensagem simples e limpa
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

	payload := TelegramMessage{
		ChatID:                TelegramChatID,
		Text:                  text,
		ParseMode:             "Markdown",
		DisableWebPagePreview: false, // Ativar preview da imagem/link
	}

	payloadBytes, _ := json.Marshal(payload)
	url := fmt.Sprintf("https://api.telegram.org/bot%s/sendMessage", TelegramBotToken)

	resp, err := http.Post(url, "application/json", bytes.NewBuffer(payloadBytes))
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("status %d: %s", resp.StatusCode, string(body))
	}

	return nil
}

// formatPubDate converte data RSS para formato brasileiro legível
func formatPubDate(pubDate string) string {
	// Tentar parsear diferentes formatos de data RSS
	formats := []string{
		time.RFC1123,  // "Mon, 02 Jan 2006 15:04:05 MST"
		time.RFC1123Z, // "Mon, 02 Jan 2006 15:04:05 -0700"
		"Mon, 2 Jan 2006 15:04:05 MST",
		"Mon, 2 Jan 2006 15:04:05 -0700",
		time.RFC3339, // "2006-01-02T15:04:05Z07:00"
	}

	var parsedTime time.Time
	var err error

	for _, format := range formats {
		parsedTime, err = time.Parse(format, pubDate)
		if err == nil {
			break
		}
	}

	if err != nil {
		// Se não conseguir parsear, retorna data original
		return pubDate
	}

	// Converter para timezone local (Brasília)
	loc, _ := time.LoadLocation("America/Sao_Paulo")
	localTime := parsedTime.In(loc)

	// Formatar como: 15:30, 11/02/2025
	return localTime.Format("15:04, 02/01/2006")
}

// ============================================================================
// FUNÇÕES AUXILIARES
// ============================================================================

// loadEnvFile carrega variáveis de ambiente de um arquivo .env
func loadEnvFile(filename string) {
	file, err := os.Open(filename)
	if err != nil {
		// Arquivo .env não existe, usar variáveis de ambiente do sistema
		return
	}
	defer file.Close()

	data, err := io.ReadAll(file)
	if err != nil {
		return
	}

	lines := strings.Split(string(data), "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)

		// Ignorar linhas vazias e comentários
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}

		// Processar linha no formato KEY=VALUE
		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			continue
		}

		key := strings.TrimSpace(parts[0])
		value := strings.TrimSpace(parts[1])

		// Remover aspas se existirem
		value = strings.Trim(value, "\"'")

		// Definir variável de ambiente
		os.Setenv(key, value)
	}
}

func saveJSON(data interface{}, filename string) {
	file, err := os.Create(filename)
	if err != nil {
		fmt.Printf("❌ Erro ao criar %s: %v\n", filename, err)
		os.Exit(1)
	}
	defer file.Close()

	encoder := json.NewEncoder(file)
	encoder.SetIndent("", "  ")
	encoder.Encode(data)
}

func truncate(s string, maxLen int) string {
	if len(s) <= maxLen {
		return s
	}
	return s[:maxLen] + "..."
}
