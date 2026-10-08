# 📋 RepEngine Mobile & Sincronização — Checklist Detalhado de Implementação

Este checklist complementa os Sprints do roadmap, rastreando individualmente cada componente de UI, banco local Drift, backend Dart Frog e motor de sincronização.

---

## 📱 1. Interface & Frontend (Flutter Mobile)

### 🏋️ 1.1 Gym Execution HUD (Modo Treino)
- [x] **Tema Atelier Dark & Tipografia**: Cores de alto contraste e tokens definidos ([`app_colors.dart`](file:///home/mateus/Projects/repengine/mobile/lib/core/theme/app_colors.dart), [`app_typography.dart`](file:///home/mateus/Projects/repengine/mobile/lib/core/theme/app_typography.dart)).
- [x] **Tela Principal do Treino**: [`workout_execution_screen.dart`](file:///home/mateus/Projects/repengine/mobile/lib/features/workout_execution/presentation/workout_execution_screen.dart) com suporte a estado vazio e sessão em andamento.
- [x] **Thumb Zone Pad (Ajuste Ergonômico de Séries)**:
  - [x] Incrementos rápidos de carga (`-5`, `-2.5`, `+2.5`, `+5`).
  - [x] Incrementos de repetições (`-1`, `+1`).
  - [x] Botão massivo "CONCLUIR SÉRIE" no terço inferior da tela.
  - [x] Conexão com fórmula estatística real de 1RM via `OneRepMaxCalculator` do core em tempo real.
- [x] **Cronômetro Circular Nativo (120 FPS Canvas)**: [`circular_rest_timer.dart`](file:///home/mateus/Projects/repengine/mobile/lib/features/workout_execution/presentation/widgets/circular_rest_timer.dart) com vibração tátil nos 3s finais.
- [x] **Cards de Séries Concluídas**: [`set_log_card.dart`](file:///home/mateus/Projects/repengine/mobile/lib/features/workout_execution/presentation/widgets/set_log_card.dart) com índice da série, carga, reps e 1RM estimado.
- [x] **Modal de Resumo do Treino Concluído**: Dialog com volume total levantado (kg), tempo de treino e total de séries gravadas no SQLite ([`workout_summary_dialog.dart`](file:///home/mateus/Projects/repengine/mobile/lib/features/workout_execution/presentation/widgets/workout_summary_dialog.dart)).

### 🌐 1.2 Status de Nuvem & Diagnósticos (Modo Academia)
- [x] **Cloud Sync Badge Dinâmico na AppBar**:
  - [x] 🟢 `Sincronizado com o PC` (0 pendentes na fila).
  - [x] 🟡 `Modo Academia` (N séries salvas offline no SQLite).
  - [x] 🔵 `Sincronizando com o PC...` (envio em andamento).
  - [x] ⚪ `PC Offline` (Docker inativo ou celular fora do Wi-Fi).
- [x] **Gaveta de Ajustes & Diagnóstico (Debug Drawer)**:
  - [x] Campo editável para IP do PC com botões de atalho (`localhost`, `10.0.2.2`).
  - [x] Botão "Testar Conexão" com medição de ping/latência em tempo real.
  - [x] Switch "Simular Modo Academia (Offline)" para testes manuais.
  - [x] Inspetor da Fila de Sincronização (`SyncQueueTable`) com visualização de mutações pendentes.
  - [x] Botão "Sincronizar Agora" (Pull & Push manual).

---

## 💾 2. Banco Local Reativo (Drift / SQLite)
- [x] **Esquema de Tabelas Locais**:
  - [x] `RoutinesTable` (workflows locais).
  - [x] `WorkoutSessionsTable` (sessões de treino).
  - [x] `WorkoutSetLogsTable` (séries concluídas com `client_id`).
  - [x] `SyncQueueTable` (fila outbox de mutações locais).
  - [ ] `ProgressionStatesTable` (cargas sugeridas e semanas ativas salvas localmente).
- [x] **Repositório Atômico (`WorkoutRepository`)**:
  - [x] `startSession()` com gravação simultânea na fila de sync.
  - [x] `logSet()` com gravação atômica da série + mutação outbox.
  - [x] `completeSession()` finalizando o treino e enfileirando sync.
  - [x] Streams reativos (`watchActiveSession`, `watchSessionLogs`, `watchPendingSyncCount`).
  - [x] Stream de inspeção da fila (`watchSyncQueue`).
  - [x] Operações de rotinas e outbox (`watchRoutines`, `upsertWorkflows`, `deleteWorkflows`, `deleteQueueItemsByClientIds`).

---

## 🔄 3. Rede & Motor de Sincronização (Outbox Worker)
- [x] **Configuração do Servidor (`ServerConfig` / `ServerHealthNotifier`)**:
  - [x] Persistência do host/porta no `shared_preferences` ([`server_config.dart`](file:///home/mateus/Projects/repengine/mobile/lib/core/network/server_config.dart)).
  - [x] Endpoint de health check no BFF sem auth ([`server_mobile/routes/api/v1/health.dart`](file:///home/mateus/Projects/repengine/server_mobile/routes/api/v1/health.dart)) testado e rodando no Docker.
  - [x] Heartbeat automático a cada 15s.
- [x] **Cliente HTTP de Sincronização (`SyncHttpClient`)**:
  - [x] Despacho em lote para `POST /api/v1/mobile/sync/push`.
  - [x] Busca de atualizações em `GET /api/v1/mobile/sync/pull`.
- [x] **Worker em Segundo Plano (`SyncEngine`)**:
  - [x] Orquestrador de duas fases: Push de mutações locais -> Pull delta de rotinas.
  - [x] Expulso atômico dos itens confirmados da `SyncQueueTable` via `deleteQueueItemsByClientIds`.
  - [x] Integração reativa com badge na AppBar (`_CloudSyncBadge`) e drawer (`DebugSettingsDrawer`).
  - [ ] Monitoramento automático de conectividade via `connectivity_plus`.

---

## 🔬 4. Ciência do Esporte & Analytics em Dart Puro
- [x] **`packages/repengine_core/lib/src/sports_science/`**:
  - [x] `one_rep_max.dart`: Fórmulas Brzycki, Epley, Mayhew, Wathen, Lombardi + consenso e intervalos de 95% ([`one_rep_max.dart`](file:///home/mateus/Projects/repengine/packages/repengine_core/lib/src/sports_science/one_rep_max.dart)).
  - [x] `inol.dart`: Intensity Number of Lifts por série e acumulado com zonas de recuperação ([`inol.dart`](file:///home/mateus/Projects/repengine/packages/repengine_core/lib/src/sports_science/inol.dart)).
  - [x] `workload_acwr.dart`: Razão de carga crônica x aguda (EWMA / Sweet Spot 0.8 - 1.3) ([`workload_acwr.dart`](file:///home/mateus/Projects/repengine/packages/repengine_core/lib/src/sports_science/workload_acwr.dart)).
  - [x] `autoregulation.dart`: Motor de ajuste de carga por RPE/falhas consecutivas ([`autoregulation.dart`](file:///home/mateus/Projects/repengine/packages/repengine_core/lib/src/sports_science/autoregulation.dart)).
  - [x] Testes unitários puros com 100% de cobertura e paridade (`dart test` aprovado).

### 📱 4.1 Integração no Mobile (Flutter HUD)
- [x] Conectar `OneRepMaxCalculator` no [`thumb_zone_pad.dart`](file:///home/mateus/Projects/repengine/mobile/lib/features/workout_execution/presentation/widgets/thumb_zone_pad.dart) para 1RM dinâmico enquanto digita carga/reps.
- [x] Conectar `OneRepMaxCalculator` no [`set_log_card.dart`](file:///home/mateus/Projects/repengine/mobile/lib/features/workout_execution/presentation/widgets/set_log_card.dart) para exibir o 1RM histórico de cada série concluída.

### 🖥️ 4.2 Exposição no Dart Frog BFF & Substituição do Python no Desktop Web
- [x] **Endpoints Analíticos no Dart Frog BFF (`server_mobile`)**:
  - [x] `POST /api/v1/1rm`: Recebe carga/reps do Desktop e responde consenso e projeções.
  - [x] `POST /api/v1/autoregulation`: Avalia histórico de sessões do Desktop e sugere ação (`increase_load`, etc.).
  - [x] `POST /api/v1/acwr`: Calcula razão aguda:crônica a partir das cargas diárias.
- [x] **Virada de Chave na Web Desktop (SvelteKit)**:
  - [x] Atualizar `docker-compose.dev.yml`: `ANALYTICS_URL: http://mobile-bff:8080`.
  - [x] Validar carregamento do card `ScientificInsights` na Web Desktop consumindo o Dart Frog.
- [x] **Descomissionamento do Python**:
  - [x] Remover o contêiner `analytics` do `docker-compose.dev.yml` (economia de ~200MB de RAM).
  - [x] Aposentar pasta `analytics/`.
