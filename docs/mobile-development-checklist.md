# 📋 RepEngine Mobile & Sincronização — Checklist Detalhado de Implementação (EN Reference)

This checklist tracks the implementation progress across the Flutter mobile application, Drift SQLite local database, Dart Frog BFF, and the synchronization engine.

---

## 📱 1. Interface & Mobile Frontend (Flutter)

### 🏋️ 1.1 Gym Execution HUD (Active Workout Mode)
- [x] **Kanagawa Dark Theme & Typography**: High-contrast color tokens and typography ([`app_colors.dart`](file:///home/mateus/Projects/repengine/mobile/lib/core/theme/app_colors.dart), [`app_typography.dart`](file:///home/mateus/Projects/repengine/mobile/lib/core/theme/app_typography.dart)).
- [x] **Main Workout Execution View**: [`workout_execution_screen.dart`](file:///home/mateus/Projects/repengine/mobile/lib/features/workout_execution/presentation/workout_execution_screen.dart) supporting empty state and active workout session.
- [x] **Thumb Zone Pad (Ergonomic Set Logger)**:
  - [x] Quick load adjusters (`-5kg`, `-2.5kg`, `+2.5kg`, `+5kg`).
  - [x] Repetition adjusters (`-1`, `+1`).
  - [x] Massive "LOG SET" button in natural thumb reach.
  - [x] Real-time 1RM projection via `OneRepMaxCalculator` from `repengine_core`.
- [x] **Native Circular Rest Timer (120 FPS Canvas)**: [`circular_rest_timer.dart`](file:///home/mateus/Projects/repengine/mobile/lib/features/workout_execution/presentation/widgets/circular_rest_timer.dart) with haptic vibrations during the final 3 seconds.
- [x] **Completed Set Log Cards**: [`set_log_card.dart`](file:///home/mateus/Projects/repengine/mobile/lib/features/workout_execution/presentation/widgets/set_log_card.dart) showing set index, load, reps, and calculated 1RM.
- [x] **Automatic Exercise Transitions & Completion Pad**:
  - [x] Automatic rest timer trigger and auto-advance to the next exercise upon finishing prescribed sets.
  - [x] [`exercise_completed_pad.dart`](file:///home/mateus/Projects/repengine/mobile/lib/features/workout_execution/presentation/widgets/exercise_completed_pad.dart) locking completed exercises and guiding athlete with `NEXT: [EXERCISE]`.
  - [x] Final `ALL EXERCISES COMPLETED!` state with direct shortcut to `REVIEW & FINISH WORKOUT`.
  - [x] Widget regression tests in [`routine_selection_test.dart`](file:///home/mateus/Projects/repengine/mobile/test/features/workout_execution/routine_selection_test.dart).
- [x] **Workout Summary Modal**: Dialog showing total volume lifted (kg), total workout duration, and total sets logged in SQLite ([`workout_summary_dialog.dart`](file:///home/mateus/Projects/repengine/mobile/lib/features/workout_execution/presentation/widgets/workout_summary_dialog.dart)).

### 🌐 1.2 Cloud Status & Diagnostics (Gym Mode)
- [x] **Dynamic Cloud Sync Badge in AppBar**:
  - [x] 🟢 `Synced with PC` (0 pending in queue).
  - [x] 🟡 `Gym Mode / Offline` (N sets saved locally in SQLite).
  - [x] 🔵 `Syncing with PC...` (dispatch in progress).
  - [x] ⚪ `PC Offline` (Docker inactive or phone outside Wi-Fi).
- [x] **Diagnostic Drawer**:
  - [x] Automatic BFF host discovery (`HostDiscoveryService` with parallel subnet scan and signature validation).
  - [x] "Auto-Detect PC (Wi-Fi)" button with live feedback and silent background reconnection.
  - [x] Editable PC IP address with shortcut presets (`localhost`, `10.0.2.2`).
  - [x] "Test Connection" button measuring round-trip latency.
  - [x] "Simulate Gym Mode (Offline)" toggle for manual field testing.
  - [x] Outbox Queue Inspector (`SyncQueueTable`) displaying pending payloads.
  - [x] "Sync Now" button (manual pull & push).

---

## 💾 2. Local Reactive Storage (Drift / SQLite)
- [x] **Local Table Schema**:
  - [x] `RoutinesTable` (local routine workflows).
  - [x] `WorkoutSessionsTable` (active and completed workout sessions).
  - [x] `WorkoutSetLogsTable` (completed set logs with `client_id`).
  - [x] `SyncQueueTable` (outbox queue of local mutations).
  - [x] `ProgressionStatesTable` (prescribed loads and progression states cached locally).
- [x] **Atomic Repository (`WorkoutRepository`)**:
  - [x] `startSession()` with simultaneous outbox insertion.
  - [x] `logSet()` with atomic set insertion + outbox mutation.
  - [x] `completeSession()` finalizing session and enqueuing sync.
  - [x] Reactive streams (`watchActiveSession`, `watchSessionLogs`, `watchPendingSyncCount`, `watchSyncQueue`).
  - [x] Batch upserts and mutations (`watchRoutines`, `upsertWorkflows`, `deleteWorkflows`, `deleteQueueItemsByClientIds`).

---

## 🔄 3. Network & Synchronization Engine (Outbox Worker)
- [x] **Delta Sync Client (`SyncHttpClient`)**:
  - [x] Automatic retry with exponential backoff.
  - [x] Strict timeout protection and graceful offline fallback.
- [x] **Push & Pull Reconciliation**:
  - [x] Batch push dispatch of local outbox mutations to Dart Frog BFF.
  - [x] Upstream pull syncing routines and progression states into SQLite.
  - [x] Atomic queue purge after successful server acknowledgement.

---

## 📱 4. Sprint 9: Gym-Proof UI Ergonomics & In-Workout Adjustments
- [x] **Custom Exercise Swaps**:
  - [x] Swap exercise in active workout session when equipment is occupied.
  - [x] Add ad-hoc exercise on the fly.
  - [x] Prompt to optionally overwrite base routine template or keep changes isolated to today's session.
- [x] **Plate Calculator**: Visual breakdown for 20kg barbell with standard plates (25, 20, 15, 10, 5, 2.5, 1.25kg).
- [x] **Local Workout History Screen**: Full completed workout timeline with date filters and volume summaries.

---

## 🔐 5. Sprint 10: Dedicated Athlete Login & Mobile Routine Studio
- [x] **Authentication Flow & Athlete Profile**:
  - [x] Dedicated login view with Web account credentials or "Train Offline / Guest Mode".
  - [x] Reactive startup routing: boots to login screen when unauthenticated; boots directly to HUD when authenticated.
  - [x] Athlete profile sheet with cloud sync status and safe logout.
- [x] **Mobile Routine Studio (`RoutineEditorScreen`)**:
  - [x] Multi-day routine builder with custom exercises, sets, reps, load, and rest times.
  - [x] Deterministic local persistence in Drift SQLite and outbox sync dispatch.

---

## 🤖 6. Sprint 11: AI Workout Copilot
- [x] **Natural Language Routine Generation**:
  - [x] Dart Frog BFF endpoint (`POST /api/v1/mobile/ai/generate_routine`) powered by Google Genkit & Gemini 1.5 Flash.
  - [x] Structured output parsing into canonical `exercise` blocks.
  - [x] Mobile `AiRoutineDialog` with suggestion chips and routine editor integration.
  - [x] Web Studio `AiArchitectModal.svelte` with Replace / Append capabilities.

---

## 🧩 7. Sprint 12: Visual Progressions & Canonical Routine JSON Hub
- [x] **Structured Progression Sub-Blocks**:
  - [x] Exercises include structured `progression` object (`linear`, `double`).
  - [x] Web Studio `BlockExercise.svelte` with connected visual progression sub-blocks.
  - [x] Official database templates migrated to canonical `exercise` with structured progression.
  - [x] Mobile Gym HUD badges and dynamic autoregulation calculation (Double Progression & custom load increments).
- [x] **Canonical Routine JSON Hub (`repengine.routine.v1.json`)**:
  - [x] 1-Click Export and Import on Web Studio and Mobile.
  - [x] Mobile `RoutineImportSheet` with clipboard paste, real-time validation, and instant preview.
  - [x] Prompt generator for external LLMs (ChatGPT / Claude) matching the RepEngine canonical schema.
- [x] **Automated Test Coverage**:
  - [x] Unit tests for canonical parser, double progression logic, and custom increments (74 mobile tests passing).
