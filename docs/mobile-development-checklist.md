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
  - [ ] Conexão com fórmula estatística real de 1RM *(aguarda `OneRepMaxCalculator` amanhã)*.
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
  - [ ] Botão "Sincronizar Agora" (Pull & Push manual).

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

---

## 🔄 3. Rede & Motor de Sincronização (Outbox Worker)
- [x] **Configuração do Servidor (`ServerConfig` / `ServerHealthNotifier`)**:
  - [x] Persistência do host/porta no `shared_preferences` ([`server_config.dart`](file:///home/mateus/Projects/repengine/mobile/lib/core/network/server_config.dart)).
  - [x] Endpoint de health check no BFF sem auth ([`server_mobile/routes/api/v1/health.dart`](file:///home/mateus/Projects/repengine/server_mobile/routes/api/v1/health.dart)) testado e rodando no Docker.
  - [x] Heartbeat automático a cada 15s.
- [ ] **Cliente HTTP de Sincronização (`SyncHttpClient`)**:
  - [ ] Despacho em lote para `POST /api/v1/mobile/sync/push`.
  - [ ] Busca de atualizações em `GET /api/v1/mobile/sync/pull`.
- [ ] **Worker em Segundo Plano (`SyncEngine`)**:
  - [ ] Monitoramento de conexão via `connectivity_plus`.
  - [ ] Heartbeat periódico no PC.
  - [ ] Auto-sync ao reconectar no Wi-Fi / ligar o Docker.
  - [ ] Expulso atômico dos itens confirmados da `SyncQueueTable`.

---

## 🔬 4. Ciência do Esporte & Analytics (Programação de Amanhã)
- [ ] **`packages/repengine_core/lib/src/sports_science/`**:
  - [ ] `one_rep_max.dart`: Fórmulas Brzycki, Epley, Mayhew, Wathen, Lombardi + consenso e intervalos de 95%.
  - [ ] `inol.dart`: Intensity Number of Lifts por série e acumulado com zonas de recuperação.
  - [ ] `workload_acwr.dart`: Razão de carga crônica x aguda (EWMA / Sweet Spot 0.8 - 1.3).
  - [ ] `autoregulation.dart`: Motor de ajuste de carga por RPE/falhas consecutivas.
  - [ ] Testes unitários puros (`dart test`).
- [ ] **Plugar no Mobile & BFF**:
  - [ ] Atualizar `ThumbZonePad` e `SetLogCard` para usar o `OneRepMaxCalculator` do core.
  - [ ] Endpoints no Dart Frog BFF (`/api/v1/1rm`, etc.) para aposentar o contêiner Python.
