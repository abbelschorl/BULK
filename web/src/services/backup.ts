/* JSON backup of every user-created record plus settings, byte-compatible
   with the Swift app's ExportImportService.Backup (version 1) so backups move
   between the native and web versions. Import replaces all data so restore is
   deterministic. Dates are ISO 8601 WITHOUT fractional seconds — Swift's
   .iso8601 decoder rejects milliseconds. */

import { dayKeyOf, dayKeyToDate } from "../models/dayKey";
import type {
  FoodItem,
  LogEntry,
  MealType,
  SavedMeal,
  Supplement,
  WaterEntry,
  WeightEntry,
} from "../models/types";
import { FOOD_SOURCE_LABELS, MEAL_TYPES, type FoodSource } from "../models/types";
import { repo, newId } from "../db/repo";
import { loadSettings, updateSettings, type Settings } from "../db/settings";
import type { WaterUnit, WeightUnit } from "../models/units";

interface Backup {
  version: number;
  exportedAt: string;
  settings: {
    calorieMinimum: number;
    proteinMinimum: number;
    waterGoalML: number;
    desiredWeeklyGainKg: number;
    weightUnit: string;
    waterUnit: string;
  };
  foods: Array<{
    name: string;
    brand?: string;
    caloriesPer100g: number;
    proteinPer100g: number;
    carbsPer100g: number;
    fatPer100g: number;
    defaultServingGrams?: number;
    notes?: string;
    barcode?: string;
    isFavorite: boolean;
    source: string;
    createdAt: string;
    lastLoggedAt?: string;
  }>;
  logEntries: Array<{
    loggedAt: string;
    dayKey: string;
    mealType: string;
    grams: number;
    foodName: string;
    foodBrand?: string;
    caloriesPer100g: number;
    proteinPer100g: number;
    carbsPer100g: number;
    fatPer100g: number;
    sourceLabel: string;
  }>;
  savedMeals: Array<{
    name: string;
    createdAt: string;
    components: Array<{
      foodName: string;
      foodBrand?: string;
      grams: number;
      caloriesPer100g: number;
      proteinPer100g: number;
      carbsPer100g: number;
      fatPer100g: number;
      sourceLabel: string;
      sortOrder: number;
    }>;
  }>;
  weightEntries: Array<{ date: string; weightKg: number; note?: string; healthKitUUID?: string }>;
  waterEntries: Array<{ date: string; dayKey: string; amountML: number }>;
  supplements: Array<{
    name: string;
    dose?: string;
    timeOfDayLabel?: string;
    notes?: string;
    isActive: boolean;
    isArchived: boolean;
    sortOrder: number;
    createdAt: string;
    completedDayKeys: string[];
  }>;
}

/** ISO 8601 without fractional seconds ("2026-07-17T08:00:00Z"). */
function isoDate(date: Date | string): string {
  const d = typeof date === "string" ? new Date(date) : date;
  return d.toISOString().replace(/\.\d{3}Z$/, "Z");
}

/** Local start-of-day timestamp for a "YYYY-MM-DD" day key. */
function dayKeyToISO(dayKey: string): string {
  const noon = dayKeyToDate(dayKey);
  return isoDate(new Date(noon.getFullYear(), noon.getMonth(), noon.getDate()));
}

function isoToDayKey(iso: string): string {
  return dayKeyOf(new Date(iso));
}

export async function makeBackup(): Promise<Backup> {
  const settings = loadSettings();
  const [foods, entries, meals, weights, water, supplements, supplementLogs] = await Promise.all([
    repo.allFoods(),
    repo.allEntries(),
    repo.allMeals(),
    repo.allWeights(),
    repo.allWater(),
    repo.allSupplements(),
    repo.allSupplementLogs(),
  ]);

  return {
    version: 1,
    exportedAt: isoDate(new Date()),
    settings: {
      calorieMinimum: settings.calorieMinimum,
      proteinMinimum: settings.proteinMinimum,
      waterGoalML: settings.waterGoalML,
      desiredWeeklyGainKg: settings.desiredWeeklyGainKg,
      weightUnit: settings.weightUnit,
      waterUnit: settings.waterUnit,
    },
    foods: foods.map((f) => ({
      name: f.name,
      brand: f.brand,
      caloriesPer100g: f.per100g.calories,
      proteinPer100g: f.per100g.protein,
      carbsPer100g: f.per100g.carbs,
      fatPer100g: f.per100g.fat,
      defaultServingGrams: f.defaultServingGrams,
      notes: f.notes,
      barcode: f.barcode,
      isFavorite: f.isFavorite,
      source: f.source,
      createdAt: isoDate(f.createdAt),
      lastLoggedAt: f.lastLoggedAt ? isoDate(f.lastLoggedAt) : undefined,
    })),
    logEntries: entries.map((e) => ({
      loggedAt: isoDate(e.loggedAt),
      dayKey: dayKeyToISO(e.dayKey),
      mealType: e.mealType,
      grams: e.grams,
      foodName: e.foodName,
      foodBrand: e.foodBrand,
      caloriesPer100g: e.per100g.calories,
      proteinPer100g: e.per100g.protein,
      carbsPer100g: e.per100g.carbs,
      fatPer100g: e.per100g.fat,
      sourceLabel: e.sourceLabel,
    })),
    savedMeals: meals.map((m) => ({
      name: m.name,
      createdAt: isoDate(m.createdAt),
      components: [...m.components]
        .sort((a, b) => a.sortOrder - b.sortOrder)
        .map((c) => ({
          foodName: c.foodName,
          foodBrand: c.foodBrand,
          grams: c.grams,
          caloriesPer100g: c.per100g.calories,
          proteinPer100g: c.per100g.protein,
          carbsPer100g: c.per100g.carbs,
          fatPer100g: c.per100g.fat,
          sourceLabel: c.sourceLabel,
          sortOrder: c.sortOrder,
        })),
    })),
    weightEntries: weights.map((w) => ({
      date: isoDate(w.date),
      weightKg: w.weightKg,
      note: w.note,
    })),
    waterEntries: water.map((w) => ({
      date: isoDate(w.date),
      dayKey: dayKeyToISO(w.dayKey),
      amountML: w.amountML,
    })),
    supplements: supplements.map((s) => ({
      name: s.name,
      dose: s.dose,
      timeOfDayLabel: s.timeOfDayLabel,
      notes: s.notes,
      isActive: !s.isArchived,
      isArchived: s.isArchived,
      sortOrder: s.sortOrder,
      createdAt: isoDate(s.createdAt),
      completedDayKeys: supplementLogs
        .filter((l) => l.supplementId === s.id)
        .map((l) => dayKeyToISO(l.dayKey)),
    })),
  };
}

export async function exportBackupJSON(): Promise<string> {
  return JSON.stringify(await makeBackup(), null, 2);
}

export class ImportError extends Error {
  constructor() {
    super("This file doesn't look like a Bulk backup. Nothing was changed.");
  }
}

export function decodeBackup(json: string): Backup {
  let parsed: unknown;
  try {
    parsed = JSON.parse(json);
  } catch {
    throw new ImportError();
  }
  const backup = parsed as Backup;
  if (
    typeof backup !== "object" ||
    backup === null ||
    backup.version !== 1 ||
    typeof backup.settings !== "object" ||
    !Array.isArray(backup.foods) ||
    !Array.isArray(backup.logEntries)
  ) {
    throw new ImportError();
  }
  return backup;
}

/** Replaces all stored data with the backup's contents. */
export async function restoreBackup(json: string): Promise<void> {
  const backup = decodeBackup(json);
  await repo.deleteAllData();

  const settingsPatch: Partial<Settings> = {
    calorieMinimum: backup.settings.calorieMinimum,
    proteinMinimum: backup.settings.proteinMinimum,
    waterGoalML: backup.settings.waterGoalML,
    desiredWeeklyGainKg: backup.settings.desiredWeeklyGainKg,
  };
  if (backup.settings.weightUnit === "kilograms" || backup.settings.weightUnit === "pounds") {
    settingsPatch.weightUnit = backup.settings.weightUnit as WeightUnit;
  }
  if (backup.settings.waterUnit === "milliliters" || backup.settings.waterUnit === "fluidOunces") {
    settingsPatch.waterUnit = backup.settings.waterUnit as WaterUnit;
  }
  updateSettings(settingsPatch);

  for (const f of backup.foods) {
    const source: FoodSource = ["myFood", "openFoodFacts", "usda"].includes(f.source)
      ? (f.source as FoodSource)
      : "myFood";
    const item: FoodItem = {
      id: newId(),
      name: f.name,
      brand: f.brand,
      per100g: {
        calories: f.caloriesPer100g,
        protein: f.proteinPer100g,
        carbs: f.carbsPer100g,
        fat: f.fatPer100g,
      },
      defaultServingGrams: f.defaultServingGrams,
      notes: f.notes,
      barcode: f.barcode,
      isFavorite: f.isFavorite,
      source,
      createdAt: f.createdAt,
      lastLoggedAt: f.lastLoggedAt,
    };
    await repo.saveFood(item);
  }

  for (const e of backup.logEntries) {
    const mealType: MealType = MEAL_TYPES.includes(e.mealType as MealType)
      ? (e.mealType as MealType)
      : "snack";
    const entry: LogEntry = {
      id: newId(),
      loggedAt: e.loggedAt,
      dayKey: isoToDayKey(e.dayKey),
      mealType,
      grams: e.grams,
      foodName: e.foodName,
      foodBrand: e.foodBrand,
      per100g: {
        calories: e.caloriesPer100g,
        protein: e.proteinPer100g,
        carbs: e.carbsPer100g,
        fat: e.fatPer100g,
      },
      sourceLabel: e.sourceLabel || FOOD_SOURCE_LABELS.myFood,
    };
    await repo.saveEntry(entry);
  }

  for (const m of backup.savedMeals) {
    const meal: SavedMeal = {
      id: newId(),
      name: m.name,
      createdAt: m.createdAt,
      components: m.components.map((c) => ({
        foodName: c.foodName,
        foodBrand: c.foodBrand,
        grams: c.grams,
        per100g: {
          calories: c.caloriesPer100g,
          protein: c.proteinPer100g,
          carbs: c.carbsPer100g,
          fat: c.fatPer100g,
        },
        sourceLabel: c.sourceLabel,
        sortOrder: c.sortOrder,
      })),
    };
    await repo.saveMeal(meal);
  }

  for (const w of backup.weightEntries) {
    const weight: WeightEntry = { id: newId(), date: w.date, weightKg: w.weightKg, note: w.note };
    await repo.saveWeight(weight);
  }

  for (const w of backup.waterEntries) {
    const water: WaterEntry = {
      id: newId(),
      date: w.date,
      dayKey: isoToDayKey(w.dayKey),
      amountML: w.amountML,
    };
    await repo.saveWater(water);
  }

  for (const s of backup.supplements) {
    const supplement: Supplement = {
      id: newId(),
      name: s.name,
      dose: s.dose,
      timeOfDayLabel: s.timeOfDayLabel,
      notes: s.notes,
      isArchived: s.isArchived || !s.isActive,
      sortOrder: s.sortOrder,
      createdAt: s.createdAt,
    };
    await repo.saveSupplement(supplement);
    for (const dayISO of s.completedDayKeys) {
      await repo.saveSupplementLog({
        id: newId(),
        supplementId: supplement.id,
        dayKey: isoToDayKey(dayISO),
        loggedAt: dayISO,
      });
    }
  }
}
