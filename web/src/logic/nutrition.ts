/* Ported from Bulk/Logic/NutritionCalculator.swift. Uses JS numbers instead
   of Swift Decimal (accepted deviation); round only at display time. */

import type { LogEntry, NutritionValues } from "../models/types";
import { ZERO_NUTRITION } from "../models/types";

export function addNutrition(a: NutritionValues, b: NutritionValues): NutritionValues {
  return {
    calories: a.calories + b.calories,
    protein: a.protein + b.protein,
    carbs: a.carbs + b.carbs,
    fat: a.fat + b.fat,
  };
}

/** Scales per-100 g values to an arbitrary gram amount. */
export function scalePer100g(per100g: NutritionValues, grams: number): NutritionValues {
  const factor = grams / 100;
  return {
    calories: per100g.calories * factor,
    protein: per100g.protein * factor,
    carbs: per100g.carbs * factor,
    fat: per100g.fat * factor,
  };
}

export function entryTotals(entry: LogEntry): NutritionValues {
  return scalePer100g(entry.per100g, entry.grams);
}

/** Sums the scaled totals of a day's log entries. */
export function dayTotals(entries: LogEntry[]): NutritionValues {
  return entries.reduce((acc, e) => addNutrition(acc, entryTotals(e)), ZERO_NUTRITION);
}
