/* Display formatting ported from Bulk/Support/Formatters.swift. */

import { WEIGHT_UNIT_LABELS, weightFromKg, type WeightUnit } from "../models/units";

export const Format = {
  /** Whole-number kcal, e.g. "2,340". */
  kcal(value: number): string {
    return Math.round(value).toLocaleString();
  },

  /** Grams of macro with at most one decimal, e.g. "32.5" or "40". */
  macroGrams(value: number): string {
    return value.toLocaleString(undefined, { maximumFractionDigits: 1 });
  },

  /** Portion grams, e.g. "150 g". */
  portionGrams(value: number): string {
    return `${value.toLocaleString(undefined, { maximumFractionDigits: 1 })} g`;
  },

  /** Weight in the user's unit with one decimal, e.g. "82.4 kg". */
  weight(kg: number, unit: WeightUnit): string {
    const value = weightFromKg(kg, unit);
    return `${value.toLocaleString(undefined, {
      minimumFractionDigits: 1,
      maximumFractionDigits: 1,
    })} ${WEIGHT_UNIT_LABELS[unit]}`;
  },

  /** Signed weekly rate, e.g. "+0.30 kg/week". */
  weeklyRate(kgPerWeek: number, unit: WeightUnit): string {
    const value = weightFromKg(kgPerWeek, unit);
    const formatted = value.toLocaleString(undefined, {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
      signDisplay: "exceptZero",
    });
    return `${formatted} ${WEIGHT_UNIT_LABELS[unit]}/week`;
  },
};
