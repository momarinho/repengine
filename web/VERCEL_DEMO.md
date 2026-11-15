# RepEngine — Vercel Showcase Deployment Guide

This branch (`demo/vercel-showcase`) configures the `web/` SvelteKit frontend to run as a standalone interactive showcase on **Vercel** without requiring the Go API, PostgreSQL, or Python analytics services.

## How It Works

When deployed on Vercel without an `API_URL` environment variable (or whenever `DEMO_MODE=true` is set):

- **Landing Page (`/`):** Renders a public Showcase Landing Page instead of redirecting to `/login`.
- **Zero-Auth Demo Access:** Protected routes automatically authenticate as a demo athlete (`athlete@repengine.demo`).
- **Simulated In-Memory Backend (`src/lib/server/demo/`):** Intercepts `apiFetch` and `analyticsFetch` with:
  - Pre-seeded routines (**GZCLP Home Gym 72 kg Cap**, **5/3/1 Wave & Calisthenics**, **Upper Hypertrophy Express**).
  - Pre-seeded workout history, progression states (including `max_load` auto rep progression), templates, and training maxes.
  - TypeScript progression evaluator when completing sessions in the live Workout HUD.
  - Client-side / demo 1RM consensus, ACWR, and autoregulation calculations.

## Deploying on Vercel

1. Push/select the `demo/vercel-showcase` branch in Vercel.
2. Under **Project Settings → General → Root Directory**, set it to **`web`**.
3. Leave the Build & Output settings as Vercel's detected **SvelteKit** defaults (`npm run build`).
4. *(Optional)* Environment variables:
   - None required! `VERCEL=1` with no `API_URL` automatically enables Demo Mode.
   - To force Demo Mode locally: `DEMO_MODE=true npm run dev`
   - To connect a real Go API instead: set `API_URL` (and optionally `DEMO_MODE=false`).
