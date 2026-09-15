# Guia Completo de Implementação: Fase 1 — Mobile Player Gym-Ready 📱💪

Este guia foi elaborado para documentar e ensinar como transformar o **Workout Player** do RepEngine em uma aplicação web com comportamento e ergonomia de aplicativo nativo de academia, sem precisar de React Native ou Swift/Kotlin.

---

## 🧭 Índice do Guia

1. [Visão Geral e Objetivos](#1-visão-geral-e-objetivos)
2. [Passo 1: Screen Wake Lock API (Manter Tela Acesa)](#passo-1-screen-wake-lock-api)
3. [Passo 2: Teclados Numéricos Nativos (inputmode)](#passo-2-teclados-numéricos-nativos)
4. [Passo 3: Feedback Tátil Háptico (Vibration API)](#passo-3-feedback-tátil-háptico)
5. [Passo 4: Safe Areas & Ergonomia Touch (CSS env)](#passo-4-safe-areas--ergonomia-touch)
6. [Passo 5: Como Testar no Celular Localmente (Passo a Passo)](#passo-5-como-testar-no-celular-localmente)
7. [Checklist de Verificação](#checklist-de-verificação)

---

## 1. Visão Geral e Objetivos

Na academia, o usuário enfrenta condições adversas para usar telas sensíveis ao toque:
- **Mãos suadas ou com magnésio:** digitar texto em teclados pequenos é frustrante.
- **Intervalos de descanso:** o celular costuma apagar a tela após 30 segundos, obrigando a desbloquear o aparelho a cada série.
- **Barulho ambiente e fones de ouvido:** alertas sonoros podem não ser ouvidos se o celular estiver no bolso ou no banco; a vibração é essencial.

A **Fase 1** foca em eliminar 100% desse atrito usando apenas **Web APIs nativas e padrões de navegadores modernos**.

---

## Passo 1: Screen Wake Lock API

### 🎯 O Conceito
A **Screen Wake Lock API** (`navigator.wakeLock`) permite que uma página web solicite ao sistema operacional que a tela permaneça ligada enquanto a página estiver visível.

### ⚙️ Ciclo de Vida e Regras Críticas
1. **Adquirir a trava:** Quando o treino começa ou o componente do Player é montado (`onMount`).
2. **Reaquisição automática (`visibilitychange`):** Se o usuário minimizar o navegador, trocar de aplicativo (ex: mudar de música no Spotify) e voltar para o RepEngine, o navegador automaticamente revoga a trava. É necessário ouvir o evento `visibilitychange` e solicitar a trava novamente ao voltar a ficar `visible`.
3. **Liberar a trava:** Ao completar o treino, abandonar a sessão ou desmontar o componente (`onDestroy`), a trava DEVE ser liberada para poupar a bateria do usuário.

### 💻 Código de Referência (TypeScript / Svelte)

```typescript
let wakeLock: WakeLockSentinel | null = null;

// 1. Função para solicitar trava de tela
async function requestWakeLock(): Promise<void> {
  if (typeof navigator === 'undefined' || !('wakeLock' in navigator)) return;
  try {
    if (!wakeLock || wakeLock.released) {
      wakeLock = await navigator.wakeLock.request('screen');
      console.log('[WAKE_LOCK] Tela mantida acesa com sucesso.');
    }
  } catch (err) {
    console.warn('[WAKE_LOCK] Não foi possível ativar wake lock:', err);
  }
}

// 2. Função para liberar
function releaseWakeLock(): void {
  if (wakeLock) {
    wakeLock.release().catch(() => {});
    wakeLock = null;
    console.log('[WAKE_LOCK] Trava de tela liberada.');
  }
}

// 3. Listener de visibilidade (ex: usuário trocou de app e voltou)
function handleVisibilityChange(): void {
  if (document.visibilityState === 'visible' && !isSessionComplete) {
    void requestWakeLock();
  }
}
```

---

## Passo 2: Teclados Numéricos Nativos

### 🎯 O Conceito
Por padrão, tags `<input>` ou `<input type="text">` fazem com que o teclado do iOS e Android abra com as letras do alfabeto (QWERTY). O usuário é forçado a clicar no botão `?123` para digitar cargas como `80` ou reps como `10`.

### ⚙️ Os Atributos `inputmode`
- `inputmode="numeric"`: Abre o teclado numérico puro (0 a 9). Perfeito para **Reps** inteiras.
- `inputmode="decimal"`: Abre o teclado numérico com botão de ponto/vírgula decimal. Perfeito para **Carga (kg)** (ex: `102.5`) e **RPE/RIR** (ex: `8.5`).

### 💻 Exemplo de Substituição no Player

**Antes (Abre teclado com letras):**
```svelte
<input id="actual-load" placeholder="100 kg" bind:value={actualLoad} />
```

**Depois (Abre o teclado numérico imediatamente ao toque):**
```svelte
<input
  id="actual-load"
  type="text"
  inputmode="decimal"
  autocomplete="off"
  enterkeyhint="done"
  placeholder="100 kg"
  bind:value={actualLoad}
/>
```

---

## Passo 3: Feedback Tátil Háptico (Vibration API)

### 🎯 O Conceito
A **Vibration API** (`navigator.vibrate`) permite emitir pulsos físicos no motor háptico do smartphone.

### ⚙️ Integração com o Web Audio HUD
O RepEngine já possui a função `playAudioTone(type)` para bips de intervalo e descanso. Nós conectamos a vibração exatamente nos mesmos gatilhos:

```typescript
function triggerHaptic(type: 'warning' | 'sprint' | 'work' | 'rest' | 'prep' | 'complete'): void {
  if (typeof navigator === 'undefined' || !navigator.vibrate) return;
  try {
    switch (type) {
      case 'warning':
        navigator.vibrate(60); // Toque rápido de alerta nos 3-2-1
        break;
      case 'sprint':
      case 'work':
        navigator.vibrate([100, 50, 100]); // Pulso duplo forte para início de esforço
        break;
      case 'rest':
        navigator.vibrate(150); // Pulso único longo para relaxar / descansar
        break;
      case 'complete':
        navigator.vibrate([100, 50, 100, 50, 250]); // Padrão comemorativo de fim de round/sessão
        break;
    }
  } catch {
    // Silencioso se o dispositivo não permitir ou não tiver motor de vibração
  }
}
```

---

## Passo 4: Safe Areas & Ergonomia Touch

### 🎯 O Conceito
Smartphones modernos possuem a barra de gestos inferior (iOS Home Bar e Android Gesture Pill). Elementos com `fixed bottom-0` podem colidir com esses gestos se não considerarem o espaçamento seguro do sistema.

### ⚙️ Como Ativar
1. No arquivo `web/src/app.html`, adicione `viewport-fit=cover`:
   ```html
   <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />
   ```
2. No `footer` fixo do Player, garanta o espaçamento da safe area:
   ```svelte
   <footer class="fixed bottom-0 left-0 z-50 w-full pb-[env(safe-area-inset-bottom)] ...">
   ```
3. No contêiner de rolagem principal `<main>`, compense o espaço inferior:
   ```svelte
   <main class="... pb-[calc(5.5rem+env(safe-area-inset-bottom))]">
   ```

---

## Passo 5: Como Testar no Celular Localmente

Para testar no seu próprio telefone na sua casa sem gastar nada:

### 1. Certifique-se de que os containers Docker estão rodando
No seu PC, no terminal da raiz do projeto:
```bash
docker compose -f docker-compose.dev.yml ps
```
Você verá `repengine-web-1` rodando na porta `3000` e `repengine-api-1` na porta `8080`.

### 2. Conecte o celular no mesmo Wi-Fi do seu PC
O IP local da sua máquina na rede doméstica é:
```text
192.168.100.2
```

### 3. Abra o navegador do celular
No Chrome ou Safari do celular, digite:
```text
http://192.168.100.2:3000
```

### 4. Experimente o modo PWA (Tela Cheia Nativa)
- **No iOS (Safari):** Toque no botão de compartilhar (ícone com quadrado e seta para cima) ➔ Role para baixo e selecione **"Adicionar à Tela de Início"**.
- **No Android (Chrome):** Toque nos três pontinhos no canto superior direito ➔ Selecione **"Instalar aplicativo"** ou **"Adicionar à tela inicial"**.
- O ícone do RepEngine aparecerá na grade de aplicativos do seu celular. Ao tocar nele, ele abre sem barra de navegação de navegador.

---

## Checklist de Verificação da Fase 1

- [ ] A tela do celular não apaga sozinha durante o descanso de 2 minutos.
- [ ] Ao tocar em Carga ou Repetições, o teclado que sobe é imediatamente o teclado numérico (sem letras).
- [ ] Na contagem regressiva 3-2-1 dos intervalos, o celular vibra levemente junto com os bips de áudio.
- [ ] O rodapé de botões respeita a barra de gestos do iPhone/Android.
- [ ] O app funciona em tela cheia via PWA adicionado à tela inicial.
