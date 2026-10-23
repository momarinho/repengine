# 🚀 RepEngine — Kit de Publicação no LinkedIn

Esta pasta reúne todos os arquivos necessários para a publicação no LinkedIn: texto, vídeo nativo, capa (thumbnail) e imagem de apoio para o primeiro comentário.

---

## 📁 Arquivos desta Pasta

| Arquivo | Descrição | Onde usar no LinkedIn |
|:---|:---|:---|
| 🎬 [`video-flutter-mobile-demo.mp4`](video-flutter-mobile-demo.mp4) | Vídeo nativo do Flutter (26s, 1.7 MB, 1080×2340, 60fps) | **Mídia principal do post (Opção A: Foco Mobile)** |
| 🎬 [`video-web-desktop-demo.mp4`](video-web-desktop-demo.mp4) | Vídeo HD do Web Studio no Desktop (31s, 1.3 MB, 1280×720) | **Mídia principal do post (Opção B: Foco Web/Desktop)** |
| 🎞️ [`bonus-comment-web-studio.gif`](bonus-comment-web-studio.gif) | GIF animado do Web Studio em ação (12s, 1.1 MB) | **Anexo animado no 1º comentário do post** |
| 🖼️ [`thumbnail-video-hud.png`](thumbnail-video-hud.png) | Capa do HUD mobile em alta definição | Miniatura para o vídeo mobile |
| 🖼️ [`thumbnail-desktop-studio.png`](thumbnail-desktop-studio.png) | Capa do Studio desktop em alta definição | Miniatura para o vídeo desktop |
| 🖥️ [`bonus-comment-web-studio.png`](bonus-comment-web-studio.png) | Print estático do Web Studio | Alternativa estática para comentários |

---

## 📝 1. Texto da Publicação Principal (Copiar e Colar)

```text
Planejar treinos com lógicas complexas de progressão (como GZCLP ou progressão dupla) em uma tela pequena de celular é péssimo. Por outro lado, levar planilhas de Excel para a academia também não funciona. 🏋️‍♂️

Para resolver isso, desenvolvi o RepEngine: uma plataforma desenhada sob o conceito de Dual-Workflow:

💻 No PC (Web Studio): Você programa periodizações complexas, faixas de repetições (rep ranges) e regras de progressão em um estúdio visual.
📱 No Celular (Flutter App): Você apenas executa. O app já abre com as cargas calculadas, roda 100% offline na academia e sincroniza com o PC automaticamente via rede local.

🛠️ A Stack & Decisões de Arquitetura:

🔹 Core API em Go (Golang + Fiber):
Escolhida pela altíssima performance, baixo consumo de memória e concorrência limpa. Utiliza pgxpool nativo com PostgreSQL 16, transações seguras com advisory locks para migrações, autenticação JWT e métricas expostas via Prometheus.

🔹 Mobile em Flutter (Riverpod 2 + Drift SQLite):
Arquitetura Local-First real: zero latência de rede (<5ms). Toda mutação entra em uma fila transacional (Outbox Pattern) para sincronização idempotente em lote. Inclui temporizador em Canvas a 120 FPS, calculadora de anilhas e atalhos táteis para o polegar.

🔹 Mobile BFF em Dart Frog & Shared Core:
Backend-for-Frontend em Dart para conciliação de sincronização e pacote compartilhado em Dart puro (repengine_core) contendo algoritmos de ciência esportiva (1RM e autorregulação).

🔹 Web Studio em SvelteKit 5 (Runes):
Frontend reativo e minimalista, com renderização de gráficos SVG nativos client-side (zero dependências pesadas de bibliotecas de terceiros).

O projeto é 100% open-source, conta com mais de 145 testes automatizados (unitários, integração e widgets) e pipeline de CI/CD no GitHub Actions.

Confira no vídeo de 26s a execução fluida do Flutter na academia 👇

🔗 Repositório no GitHub: https://github.com/momarinho/repengine

#Flutter #Golang #SoftwareArchitecture #LocalFirst #OpenSource
```

---

## 💬 2. Texto para o 1º Comentário (Logo após publicar)

> **Dica**: O LinkedIn valoriza discussões nos comentários. Postar um complemento visual aumenta o tempo de tela dos usuários e o alcance orgânico.

**Texto para colar:**
```text
💡 Para quem tiver curiosidade sobre o lado do PC (Web Studio em SvelteKit 5 onde montamos as rotinas em blocos antes do treino): é aqui que organizamos os tiers do GZCLP, progressões duplas e checkpoints.
```
*(Anexar o arquivo [`bonus-comment-web-studio.png`](bonus-comment-web-studio.png) neste comentário)*

---

## 🛠️ Passo a Passo na Interface do LinkedIn

1. Abra o LinkedIn e clique em **"Iniciar publicação"**.
2. Cole o texto da **Seção 1**.
3. Clique no ícone de **Vídeo** e selecione [`video-flutter-mobile-demo.mp4`](video-flutter-mobile-demo.mp4).
4. Na tela de prévia do vídeo, clique em **"Selecionar miniatura" / "Select thumbnail"** e escolha [`thumbnail-video-hud.png`](thumbnail-video-hud.png).
5. Clique em **Avançar** e publique.
6. Vá na área de comentários do post recém-criado, cole o texto da **Seção 2** e anexe a imagem [`bonus-comment-web-studio.png`](bonus-comment-web-studio.png).
