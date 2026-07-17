/* Ported from Bulk/Logic/WaterMath.swift. */

import type { WaterEntry } from "../models/types";
import { WATER_UNIT_LABELS, waterFromML, type WaterUnit } from "../models/units";

export function totalML(entries: WaterEntry[]): number {
  return entries.reduce((sum, e) => sum + e.amountML, 0);
}

/** Progress fraction toward the daily goal, clamped to 0...1. */
export function waterProgress(total: number, goalML: number): number {
  if (goalML <= 0) return total > 0 ? 1 : 0;
  return Math.min(Math.max(total / goalML, 0), 1);
}

/** Display string like "1,250 ml" or "42 fl oz" in the user's unit. */
export function waterDisplay(ml: number, unit: WaterUnit): string {
  const value = waterFromML(ml, unit);
  return `${Math.round(value).toLocaleString()} ${WATER_UNIT_LABELS[unit]}`;
}
