/* User-configurable settings backed by localStorage, same keys and defaults
   as Bulk/Support/AppSettings.swift. Goals are minimums — the app never
   defines an upper warning range. */

import { useSyncExternalStore } from "react";
import type { WaterUnit, WeightUnit } from "../models/units";

export interface Settings {
  calorieMinimum: number;
  proteinMinimum: number;
  waterGoalML: number;
  desiredWeeklyGainKg: number;
  weightUnit: WeightUnit;
  waterUnit: WaterUnit;
  usdaAPIKey: string;
}

export const DEFAULT_SETTINGS: Settings = {
  calorieMinimum: 3000,
  proteinMinimum: 150,
  waterGoalML: 3000,
  desiredWeeklyGainKg: 0.25,
  weightUnit: "kilograms",
  waterUnit: "milliliters",
  usdaAPIKey: "",
};

const STORAGE_KEY = "bulk.settings";

const listeners = new Set<() => void>();
let cached: Settings | null = null;

export function loadSettings(): Settings {
  if (cached) return cached;
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    cached = raw ? { ...DEFAULT_SETTINGS, ...JSON.parse(raw) } : { ...DEFAULT_SETTINGS };
  } catch {
    cached = { ...DEFAULT_SETTINGS };
  }
  return cached;
}

export function updateSettings(patch: Partial<Settings>): void {
  cached = { ...loadSettings(), ...patch };
  localStorage.setItem(STORAGE_KEY, JSON.stringify(cached));
  for (const l of listeners) l();
}

function subscribeSettings(listener: () => void): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

export function useSettings(): Settings {
  return useSyncExternalStore(subscribeSettings, loadSettings, loadSettings);
}
