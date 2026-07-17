/* A food the user is about to log, regardless of where it came from (library,
   recent, public search). Ported from Bulk/Views/Food/PendingFood.swift. */

import { repo, newId } from "../../db/repo";
import type { FoodItem, LogEntry, MealType, NutritionValues } from "../../models/types";
import { FOOD_SOURCE_LABELS } from "../../models/types";
import type { FoodSearchResult } from "../../services/searchResult";
import { ORIGIN_LABELS } from "../../services/searchResult";

export interface PendingFood {
  name: string;
  brand?: string;
  per100g: NutritionValues;
  sourceLabel: string;
  defaultServingGrams?: number;
  barcode?: string;
  hasIncompleteNutrition: boolean;
  missingFields: string[];
  /** Set when this food already exists in the local library. */
  foodId?: string;
  /** Origin kind, used to offer "save to My Foods" for public results. */
  isPublicResult: boolean;
}

export function pendingFromFood(food: FoodItem): PendingFood {
  return {
    name: food.name,
    brand: food.brand,
    per100g: food.per100g,
    sourceLabel: FOOD_SOURCE_LABELS[food.source],
    defaultServingGrams: food.defaultServingGrams,
    barcode: food.barcode,
    hasIncompleteNutrition: false,
    missingFields: [],
    foodId: food.id,
    isPublicResult: false,
  };
}

export function pendingFromResult(result: FoodSearchResult): PendingFood {
  const isLocal = result.origin === "myFood" || result.origin === "recent";
  return {
    name: result.name,
    brand: result.brand,
    per100g: result.per100g,
    sourceLabel: isLocal ? FOOD_SOURCE_LABELS.myFood : ORIGIN_LABELS[result.origin],
    defaultServingGrams: result.defaultServingGrams,
    barcode: result.barcode,
    hasIncompleteNutrition: result.hasIncompleteNutrition,
    missingFields: result.missingFields,
    foodId: isLocal ? result.foodId : undefined,
    isPublicResult: !isLocal,
  };
}

export function pendingFromEntry(entry: LogEntry): PendingFood {
  return {
    name: entry.foodName,
    brand: entry.foodBrand,
    per100g: entry.per100g,
    sourceLabel: entry.sourceLabel,
    hasIncompleteNutrition: false,
    missingFields: [],
    isPublicResult: false,
  };
}

/** Central mutation: inserts an immutable LogEntry snapshot and touches the
    linked FoodItem's lastLoggedAt for "recent" suggestions. */
export async function logPending(
  pending: PendingFood,
  grams: number,
  meal: MealType,
  dayKey: string,
): Promise<void> {
  await repo.saveEntry({
    id: newId(),
    loggedAt: new Date().toISOString(),
    dayKey,
    mealType: meal,
    grams,
    foodName: pending.name,
    foodBrand: pending.brand,
    per100g: { ...pending.per100g },
    sourceLabel: pending.sourceLabel,
    foodId: pending.foodId,
  });
  if (pending.foodId) {
    const food = (await repo.allFoods()).find((f) => f.id === pending.foodId);
    if (food) await repo.saveFood({ ...food, lastLoggedAt: new Date().toISOString() });
  }
}

/** Saves a public result into the personal library so it works offline and
    appears under My Foods from now on. */
export async function saveToLibrary(pending: PendingFood): Promise<FoodItem> {
  const food: FoodItem = {
    id: newId(),
    name: pending.name,
    brand: pending.brand,
    per100g: { ...pending.per100g },
    defaultServingGrams: pending.defaultServingGrams,
    barcode: pending.barcode,
    isFavorite: false,
    source: pending.sourceLabel === FOOD_SOURCE_LABELS.usda ? "usda" : "openFoodFacts",
    createdAt: new Date().toISOString(),
    lastLoggedAt: new Date().toISOString(),
  };
  await repo.saveFood(food);
  return food;
}
