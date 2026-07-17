/* Unit conversions ported from Bulk/Models/Enums.swift. Canonical storage is
   always kilograms and milliliters; units are a display concern. */

export type WeightUnit = "kilograms" | "pounds";
export type WaterUnit = "milliliters" | "fluidOunces";

const KG_PER_LB = 2.20462262185;
const ML_PER_FLOZ = 29.5735295625;

export const WEIGHT_UNIT_LABELS: Record<WeightUnit, string> = {
  kilograms: "kg",
  pounds: "lb",
};

export const WATER_UNIT_LABELS: Record<WaterUnit, string> = {
  milliliters: "ml",
  fluidOunces: "fl oz",
};

export function weightFromKg(kg: number, unit: WeightUnit): number {
  return unit === "kilograms" ? kg : kg * KG_PER_LB;
}

export function weightToKg(value: number, unit: WeightUnit): number {
  return unit === "kilograms" ? value : value / KG_PER_LB;
}

export function waterFromML(ml: number, unit: WaterUnit): number {
  return unit === "milliliters" ? ml : ml / ML_PER_FLOZ;
}

export function waterToML(value: number, unit: WaterUnit): number {
  return unit === "milliliters" ? value : value * ML_PER_FLOZ;
}
