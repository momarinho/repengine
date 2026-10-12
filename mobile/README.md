# RepEngine Mobile (`repengine_mobile`)

The official mobile client for **RepEngine**, engineered as a local-first, gym-hardened physical training companion using **Flutter**, **Riverpod 2**, and **Drift (SQLite)**.

It delivers instantaneous $< 5\text{ms}$ UI response times, full offline workout logging in basement gyms, thumb-first ergonomics, and automatic background synchronization with the RepEngine Core API via the Dart Frog BFF.

---

## 📱 Key Features

### 🏋️ Gym Execution HUD (Thumb-First Ergonomics)
* **Kanagawa Dark Theme**: High-contrast, glare-resistant dark palette designed for dimly lit gyms.
* **Thumb Zone Pad**: Large tactile increment buttons (`-5kg`, `-2.5kg`, `+2.5kg`, `+5kg`) and massive one-tap "LOG SET" button within natural thumb reach.
* **Smart Progression Engine**: Real-time suggestion engine for linear and double progression schemes directly in the active HUD.
* **Custom In-Workout Swaps**: Swap exercises on the fly (e.g. when gym machines are occupied) without altering base templates permanently.
* **Plate Calculator**: Visual barbell plate loading breakdown for standard Olympic bars and plates.
* **Rest Timer with Haptic Feedback**: Circular rest countdown timer with tactile vibrations on 3-2-1 intervals.

### 💾 Local-First SQLite Storage (Drift)
* **Zero Network Latency**: Reads and writes complete locally in milliseconds using Drift SQLite.
* **Atomic Outbox Sync Queue**: Mutations (`CREATE`, `UPDATE`, `DELETE`) are saved inside a transactional outbox table (`SyncQueueTable`) before dispatch.
* **Safe Offline Operation**: Fully operational without an internet connection. Logs persist locally and sync once network is restored.

### 🌐 Auto-Discovery & Cloud Sync
* **LAN Subnet Probing**: The app automatically scans the local Wi-Fi subnet (`/24`) in parallel to discover the RepEngine PC/Docker host on port 8081 without manual IP configuration.
* **Visual Sync Status Badge**: Instant header status indicators (`Synced with PC`, `Gym Mode / Offline`, `Syncing...`, `PC Offline`).
* **Manual Diagnostic Drawer**: Inspect pending outbox payloads, test host latency, or simulate gym offline mode.

### 📥 Canonical Routine JSON Hub
* **Import & Export**: One-tap JSON paste from clipboard with instant schema validation and visual routine preview.
* **AI Prompt Compatibility**: Defensively parses standard RepEngine v1 formats as well as LLM-generated routines (`days`/`exercises`).

### 🔐 Authentication Flow
* **Unauthenticated Startup Route**: Greets athletes with the Athlete Login screen (`AthleteAuthScreen`) if not logged in.
* **Instant Guest Mode**: Allows athletes to tap "Train Offline / Guest Mode" to begin logging immediately without an account.
* **Persistent Sessions**: JWT credentials stored safely in `SharedPreferences` automatically navigate directly to the Gym HUD on subsequent launches.

---

## 🏗️ Architecture & Project Structure

The mobile project follows Clean Architecture principles organized by feature modules:

```
mobile/lib/
├── core/
│   ├── database/          # Drift SQLite database, tables, DAOs, and migrations
│   ├── network/           # Host discovery service (LAN scanner), server config
│   └── theme/             # Kanagawa Dark Palette tokens & typography
└── features/
    ├── ai_copilot/        # AI Routine generator dialog & Gemini BYOK integration
    ├── auth/              # Athlete authentication, JWT state notifier & screens
    ├── sync/              # Outbox sync engine, HTTP client, and push/pull loop
    └── workout_execution/ # Active Gym HUD, routine editor, JSON import, repository
```

---

## 🛠️ Development & Tooling

### Prerequisites
* Flutter SDK (3.24+ / 3.47+ recommended)
* Android SDK (API level 34+)
* Running RepEngine Backend (`docker compose -f docker-compose.dev.yml up`)

### Useful Commands

```bash
# Install dependencies
flutter pub get

# Generate Drift database code and Riverpod stubs
dart run build_runner build --delete-conflicting-outputs

# Run code analysis (strict lints)
flutter analyze

# Execute complete test suite (74 unit and widget tests)
flutter test

# Run app on connected device or emulator
flutter run

# Build release APK
flutter build apk --release
```

---

## 📦 Installing the Release APK

To install the compiled release binary directly to an Android phone with USB debugging enabled:

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```
