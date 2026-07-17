# Bulk PWA — Design

Date: 2026-07-17
Status: Approved by Daniel (chat), pending spec review

## Goal

Ship Bulk — the bulking/nutrition tracker already fully implemented in Swift/SwiftUI
in this repo — as an installable, offline-capable PWA. The Swift app in `Bulk/`
is the authoritative spec; the PWA ports it feature-for-feature except where the
web platform can't (HealthKit) or where we deliberately defer (barcode scanning).

## Decisions (made with Daniel)

- **Scope:** full parity with the Swift app, minus HealthKit sync and barcode scanning.
- **Stack:** Vite + React + TypeScript, Vitest for tests, `vite-plugin-pwa` for
  manifest + service worker. No UI framework; custom dark-first CSS.
- **Hosting:** GitHub Pages via GitHub Actions (repo remote to be created with `gh`).
- **Barcode scanning:** deferred to v2. Food search by name covers v1 logging.

## Location & Layout

New `web/` directory at repo root, beside the Swift app:

```
web/
  index.html
  vite.config.ts          # base path for GitHub Pages, PWA plugin
  src/
    models/               # TS types mirroring Bulk/Models (FoodItem, LogEntry,
                          # SavedMeal(+Component), WeightEntry, WaterEntry,
                          # Supplement, SupplementLog, enums, units)
    logic/                # pure functions, 1:1 ports of Bulk/Logic
    db/                   # IndexedDB access (idb), one store per model
    services/             # Open Food Facts, USDA, export/import
    views/                # one folder per tab: today/ food/ progress/
                          # supplements/ settings/
    components/           # shared UI (progress ring/bar, cards, tab bar)
    theme.css             # dark-first design tokens
  tests/                  # Vitest ports of BulkTests
.github/workflows/deploy.yml
```

## Data

- **IndexedDB** via the `idb` wrapper. Object stores: `foods`, `logEntries`,
  `savedMeals`, `weightEntries`, `waterEntries`, `supplements`, `supplementLogs`.
  Records carry string UUIDs (`crypto.randomUUID()`).
- **Log entries snapshot nutrition at log time** (name, brand, per-100g values,
  source label) exactly like the Swift `LogEntry` — editing a library food never
  rewrites history. Optional `foodId` reference powers "recent foods" only.
- **Saved meals are self-contained**: components carry their own per-100g
  snapshots and gram amounts.
- **Settings** in localStorage, same keys/defaults as `AppSettings`:
  calorieMinimum 3000, proteinMinimum 150, waterGoalML 3000,
  desiredWeeklyGainKg 0.25, weightUnit kg, waterUnit ml, usdaAPIKey "".
- **Day keys:** local-timezone start of day, stored as `YYYY-MM-DD` strings.
- **Numbers:** plain JS numbers instead of Swift `Decimal`; round at display
  time (1 fraction digit for macros, integer for calories). Accepted deviation.

## Logic (pure, unit-tested)

Ports of `Bulk/Logic/`, same semantics:

- `nutrition.ts` — per-100g scaling (`grams / 100` factor), day totals.
- `goalState.ts` — minimum-style goals only: `below(remaining)` / `reached`,
  progress fraction clamped 0…1. No upper warning range, ever.
- `weightTrend.ts` — average multiple weigh-ins per day, then trailing
  7-calendar-day moving average over days that have data; weekly rate =
  (last − first) / days × 7, nil under 1 day of span.
- `waterMath.ts`, `dailyStats.ts`, `supplementDay.ts`, `insights.ts` —
  deterministic sentence-template insights, no AI/network.

## Views (five tabs, bottom tab bar)

- **Today** — goal card (calories + protein vs minimums, red/orange below,
  green at/above), diary grouped by meal (breakfast/lunch/dinner/snack) with
  edit/delete, water strip with quick-add buttons, supplement summary card.
  Day navigation (yesterday/today/any day).
- **Food** — search (Open Food Facts + USDA when key set), personal library
  (custom foods, favorites, recents), saved meals (create from foods, log whole
  meal into a chosen meal type), custom food editor (per-100g values, optional
  default serving/brand/notes/barcode field kept as plain text).
- **Progress** — weight logging (kg/lb entry stored as kg), 7-day trend line +
  weekly rate vs desired gain, calorie/protein history, insights list.
  Charts as lightweight inline SVG (no chart library).
- **Supplements** — daily checklist (checking logs to supplementLogs by day key;
  past days untouched), manage/archive supplements.
- **Settings** — goals, units (kg/lb, ml/fl-oz), USDA API key, export/import,
  danger zone (delete all data, confirm first).

## Services

- **Open Food Facts** — `https://world.openfoodfacts.org` search API, no key,
  CORS-open. Map per-100g nutriments; skip results without calories.
- **USDA FoodData Central** — user-supplied API key from settings; hidden when
  no key. Same mapping rules as the Swift `USDAService`.
- **Export/Import** — JSON backup **identical to the Swift app's `Backup`
  schema (version 1)**, so backups are portable between native and web.
  Import replaces all data after explicit confirmation.

## PWA behavior

- `vite-plugin-pwa`: precache app shell, standalone display, dark theme color,
  app icons. Everything except food search works offline.
- Vite `base` set for GitHub Pages project-site path.

## Out of scope (v1)

HealthKit sync, barcode camera scanning, any server/backend, accounts/sync.

## Testing & CI

- Vitest ports of `BulkTests/` (CalculationTests, TrendAndHistoryTests,
  FoodSearchMappingTests) against the TS logic/services.
- GitHub Actions: on push to main — install, test, build `web/`, deploy to Pages.
