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
- [x] **Transição Automática de Exercícios & Pad de Conclusão**:
  - [x] Disparo automático do cronômetro de descanso e avanço para o próximo exercício ao concluir a última série prescrita.
  - [x] [`exercise_completed_pad.dart`](file:///home/mateus/Projects/repengine/mobile/lib/features/workout_execution/presentation/widgets/exercise_completed_pad.dart) bloqueando séries extras em exercícios já finalizados e guiando com botão `NEXT: [EXERCÍCIO]`.
  - [x] Estado final `ALL EXERCISES COMPLETED!` com atalho direto para `REVIEW & FINISH WORKOUT`.
  - [x] Testes de regressão de widget em [`routine_selection_test.dart`](file:///home/mateus/Projects/repengine/mobile/test/features/workout_execution/routine_selection_test.dart).
- [x] **Modal de Resumo do Treino Concluído**: Dialog com volume total levantado (kg), tempo de treino e total de séries gravadas no SQLite ([`workout_summary_dialog.dart`](file:///home/mateus/Projects/repengine/mobile/lib/features/workout_execution/presentation/widgets/workout_summary_dialog.dart)).

### 🌐 1.2 Status de Nuvem & Diagnósticos (Modo Academia)
- [x] **Cloud Sync Badge Dinâmico na AppBar**:
  - [x] 🟢 `Sincronizado com o PC` (0 pendentes na fila).
  - [x] 🟡 `Modo Academia` (N séries salvas offline no SQLite).
  - [x] 🔵 `Sincronizando com o PC...` (envio em andamento).
  - [x] ⚪ `PC Offline` (Docker inativo ou celular fora do Wi-Fi).
- [x] **Gaveta de Ajustes & Diagnóstico (Debug Drawer)**:
  - [x] Detecção Automática do Host BFF (`HostDiscoveryService` com probe paralelo na sub-rede local e validação da assinatura `repengine_mobile_bff`).
  - [x] Botão "Auto-Detect PC (Wi-Fi)" com feedback dinâmico e reconexão silenciosa no startup/queda.
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
  - [x] `ProgressionStatesTable` (cargas sugeridas e semanas ativas salvas localmente).
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
  - [x] Auto-sync automático ao reconectar com o servidor do PC (listener reativo no heartbeat).

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

---

## 🏆 5. Sprint 6: Dashboard de Rotinas/Dias, Resolução de Conflitos, Visual & CI/CD
- [x] **Seletor Offline de Rotinas e Dias de Treino (`RoutineSelectorView`)**:
  - [x] Modelo de domínio `ParsedRoutine`, `RoutineSection`, `RoutineExercise` com parser de blocos ([`routine_model.dart`](file:///home/mateus/Projects/repengine/mobile/lib/features/workout_execution/domain/routine_model.dart)).
  - [x] Coluna `blocksJson` no Drift (`RoutinesTable`) para armazenar blocos em JSON offline.
  - [x] Seletor de rotina e de dias/seções com chips horizontais interativos.
  - [x] Prévia detalhada de exercícios de cada dia de treino (séries, repetições, carga prescrita e descanso).
  - [x] Botão dinâmico para iniciar o dia de treino selecionado.
- [x] **Execução Multiexercício no HUD Ativo**:
  - [x] Exibição do título dinâmico da seção/dia no cabeçalho do HUD.
  - [x] Abas/chips horizontais para alternar entre exercícios do treino ativo sem perda de estado.
  - [x] `ThumbZonePad` responsivo com `FittedBox` exibindo nome do exercício selecionado e sugestão individual de sobrecarga.
- [x] **Resolução Determinística de Conflitos (Coach vs. Athlete)**:
  - [x] Teste de integração ponta a ponta ([`deterministic_conflict_resolution_test.dart`](file:///home/mateus/Projects/repengine/mobile/test/features/sync/deterministic_conflict_resolution_test.dart)).
  - [x] Validação de preservação 100% íntegra dos treinos offline do atleta com `client_id` enquanto o treinador atualiza a rotina no desktop.
  - [x] Atualização atômica da rotina local no SQLite sem impacto nos registros já concluídos.
- [x] **Testes de Regressão Visual e Responsividade de Design System**:
  - [x] Teste de regressão visual ([`hud_visual_test.dart`](file:///home/mateus/Projects/repengine/mobile/test/features/workout_execution/hud_visual_test.dart)) validando tokens Kanagawa, hierarquia visual e touch targets mínimos de 48-54dp.
  - [x] Responsividade validada para viewports de smartphones compactos a flagships (sem RenderFlex overflow).
- [x] **Esteira de CI/CD em GitHub Actions**:
  - [x] `.github/workflows/ci.yml` estendido com `core-test`, `bff-test`, `mobile-test` e `mobile-build-apk` com compilação e upload de release do APK.

---

## 🔐 6. Sprint 7: Conexão Real com Conta Web & Hidratação de Treinos
- [x] **Hidratação de Blocos de Rotina (`blocksJson`) no Dart Frog BFF**:
  - [x] `GoCoreClient.fetchWorkflows()` enriquecendo workflows com chamadas concorrentes a `GET /workflows/:id`.
  - [x] Entrega de seções e exercícios completos com repetições, carga e descansos no `SyncPullResponse`.
- [x] **Proxy de Autenticação no Dart Frog BFF**:
  - [x] `POST /api/v1/mobile/auth/login` conectando com Go Core `POST /auth/login`.
  - [x] Exceção estruturada `GoCoreAuthException` e bypass de rota pública no `_middleware.dart`.
- [x] **Gerenciamento de Autenticação & Token no Mobile**:
  - [x] `AuthState` e `AuthNotifier` ([`auth_repository.dart`](file:///home/mateus/Projects/repengine/mobile/lib/features/auth/data/auth_repository.dart)).
  - [x] Persistência em `SharedPreferences` de token, user ID e email.
  - [x] Injeção de JWT dinâmico no `SyncHttpClient` e gatilho de sync imediato pós-login.
- [x] **Interface do Usuário (UI)**:
  - [x] Card "Conta RepEngine Web" na gaveta de diagnóstico ([`debug_settings_drawer.dart`](file:///home/mateus/Projects/repengine/mobile/lib/features/workout_execution/presentation/widgets/debug_settings_drawer.dart)).
  - [x] Banner informativo de status offline/conectado no seletor de rotina ([`routine_selector_view.dart`](file:///home/mateus/Projects/repengine/mobile/lib/features/workout_execution/presentation/widgets/routine_selector_view.dart)).
- [x] **Testes Automatizados**:
  - [x] Testes no BFF (`go_core_client_test.dart`, `login_test.dart`, `_middleware_test.dart`).
  - [x] Testes no Mobile (`auth_notifier_test.dart`, `workout_execution_screen_test.dart`).

---

## 🏗️ 7. Sprint 8: Criador de Rotinas no Mobile & Recursos de Portfólio
- [x] **Abandono de Treino com Purga Atômica (Abandon Workout)**:
  - [x] Fluxo de confirmação com `AbandonWorkoutDialog` e botão ergonômico no topo do HUD.
  - [x] Acesso alternativo com botão "Discard Workout" no [`WorkoutSummaryDialog`](file:///home/mateus/Projects/repengine/mobile/lib/features/workout_execution/presentation/widgets/workout_summary_dialog.dart).
  - [x] Limpeza atômica no SQLite: deleção de `workout_sessions`, purga de `workout_set_logs` e remoção de registros pendentes na `sync_queue` para não replicar dados descartados.
  - [x] Testes unitários no [`workout_repository_test.dart`](file:///home/mateus/Projects/repengine/mobile/test/features/workout_execution/workout_repository_test.dart) e de widget no [`workout_execution_screen_test.dart`](file:///home/mateus/Projects/repengine/mobile/test/features/workout_execution/workout_execution_screen_test.dart).
- [ ] **Criador de Rotinas no Celular (`RoutineCreatorScreen` / Modal)**:
  - [ ] Formulário ergonômico no tema Kanagawa Dark com nome e descrição da rotina.
  - [ ] Construtor dinâmico de seções (dias de treino: Treino A, B, etc.).
  - [ ] Adição de exercícios com catálogo nativo (*Squat, Bench Press, Deadlift, OHP, etc.*) ou customizado.
  - [ ] Prescrição de séries, repetições, carga alvo inicial e tempo de descanso por exercício.
- [ ] **Gravação Atômica & Modelo Estruturado (`WorkoutRepository.createRoutine`)**:
  - [ ] Serialização determinística de blocos compatível com `routine_model.dart` (`blocksJson`).
  - [ ] Inserção no Drift local (`RoutinesTable`) com ID local e reflexo imediato no `watchRoutines()`.
  - [ ] Enfileiramento na `SyncQueueTable` para replicação no backend.
- [ ] **Interface & Ponto de Entrada**:
  - [ ] Botão `+ Create Routine` no cabeçalho do [`RoutineSelectorView`](file:///home/mateus/Projects/repengine/mobile/lib/features/workout_execution/presentation/widgets/routine_selector_view.dart).
  - [ ] Execução imediata do treino criado pelo atleta no HUD móvel com 1RM e timer.
- [ ] **Calculadora de Anilhas (*Plate Calculator*)**:
  - [ ] Bottom Sheet no `ThumbZonePad` decompondo qualquer carga alvo nas anilhas de barra olímpica (25, 20, 15, 10, 5, 2.5, 1.25kg).
- [ ] **Histórico Local de Treinos Concluídos (`WorkoutHistoryView`)**:
  - [ ] Tela para visualização de sessões finalizadas com volume total, séries e datas salvas no SQLite.
- [ ] **Testes Automatizados**:
  - [ ] Testes unitários de repositório e testes de widget para o fluxo de criação de rotinas.

---

## 🏋️‍♂️ 8. Sprint 9: UX de Academia, Edição Durante o Treino & Sobrescrita de Rotina
- [ ] **Ergonomia e Legibilidade de Academia (*Gym-Proof HUD*)**:
  - [ ] Aumentar escala tipográfica dos elementos centrais (carga alvo, repetições, número da série) para visualização rápida à distância (24–32px).
  - [ ] Aumentar área de toque mínima dos seletores de carga e repetições no `ThumbZonePad` (botões maiores e táteis).
  - [ ] Destacar cronômetro de descanso com feedback de alto contraste quando ativo e concluído.
- [ ] **Linguagem Amigável & Desacoplamento Técnico**:
  - [ ] Substituir jargões técnicos ("BFF Host", "Outbox", "Consensus 1RM", "Autoregulated target") por termos intuitivos ("Nuvem / Sincronização", "Recorde estimado", "Meta sugerida").
  - [ ] Reorganizar gaveta de configurações mantendo status de sincronização amigável e opções de IP/diagnóstico em seção de "Configurações Avançadas".
- [ ] **Edição Rápida Durante o Treino (*In-Workout Quick Edit*)**:
  - [ ] Menu de ações no player ativo para trocar exercício quando um aparelho estiver ocupado.
  - [ ] Adicionar exercício avulso à sessão de hoje.
  - [ ] Remover exercício da sessão atual sem afetar histórico prévio.
- [ ] **Sobrescrita Inteligente da Rotina Base ao Concluir Treino**:
  - [ ] Modal de conclusão de treino exibindo resumo de novas cargas e exercícios realizados hoje.
  - [ ] Opção para atualizar a rotina base (`routines.blocksJson`) no SQLite local com as cargas/ajustes executados hoje.
  - [ ] Opção alternativa para salvar apenas o log de hoje mantendo a rotina template intacta.
- [ ] **Testes Automatizados**:
  - [ ] Testes unitários para substituição/adição de exercícios em sessão ativa e sobrescrita de rotina base.
  - [ ] Testes de widget para o novo HUD ampliado e modal inteligente de conclusão.

---

## 📱 9. Sprint 10: Tela de Login Dedicada & Editor de Rotinas Mobile
- [ ] **Fluxo de Autenticação & Perfil do Atleta**:
  - [ ] Tela de Login dedicada com opções de entrar na Conta RepEngine Web ou "Treinar Offline / Convidado".
  - [ ] Tela/aba de perfil do atleta com status de conexão/sync e opção de desconectar.
- [ ] **Criador e Editor de Rotinas Mobile (`RoutineEditorScreen`)**:
  - [ ] Construtor completo de treinos com divisões (Dia A, Dia B...) e exercícios customizados.
  - [ ] Prescrição de séries, repetições, carga inicial e descanso.
  - [ ] Persistência determinística no SQLite local e enfileiramento na Outbox para sincronização upstream.


