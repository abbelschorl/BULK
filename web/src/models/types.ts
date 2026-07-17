/* Data model mirroring the Swift app (Bulk/Models). All nutrition values are
   per 100 g; log entries and saved-meal components snapshot nutrition at
   creation time so history is immutable. Day keys are local-timezone
   "YYYY-MM-DD" strings. */

export interface NutritionValues {
  calories: number;
  protein: number;
  carbs: number;
  fat: number;
}

export const ZERO_NUTRITION: NutritionValues = { calories: 0, protein: 0, carbs: 0, fat: 0 };

export type MealType = "breakfast" | "lunch" | "dinner" | "snack";

export const MEAL_TYPES: MealType[] = ["breakfast", "lunch", "dinner", "snack"];

export const MEAL_DISPLAY_NAMES: Record<MealType, string> = {
  breakfast: "Breakfast",
  lunch: "Lunch",
  dinner: "Dinner",
  snack: "Snack",
};

export type FoodSource = "myFood" | "openFoodFacts" | "usda";

export const FOOD_SOURCE_LABELS: Record<FoodSource, string> = {
  myFood: "My Food",
  openFoodFacts: "Open Food Facts",
  usda: "USDA",
};

/** A food in the user's personal library. */
export interface FoodItem {
  id: string;
  name: string;
  brand?: string;
  per100g: NutritionValues;
  defaultServingGrams?: number;
  notes?: string;
  barcode?: string;
  isFavorite: boolean;
  source: FoodSource;
  createdAt: string; // ISO 8601
  lastLoggedAt?: string;
}

/** One logged food in the diary; nutrition snapshotted at log time. */
export interface LogEntry {
  id: string;
  loggedAt: string;
  dayKey: string;
  mealType: MealType;
  grams: number;
  foodName: string;
  foodBrand?: string;
  per100g: NutritionValues;
  sourceLabel: string;
  /** Reference to library food, only to power "recent foods". */
  foodId?: string;
}

export interface SavedMealComponent {
  foodName: string;
  foodBrand?: string;
  grams: number;
  per100g: NutritionValues;
  sourceLabel: string;
  sortOrder: number;
}

/** A reusable, self-contained group of foods (e.g. "Morning oats"). */
export interface SavedMeal {
  id: string;
  name: string;
  createdAt: string;
  components: SavedMealComponent[];
}

/** A single weigh-in; weight always stored in kilograms. */
export interface WeightEntry {
  id: string;
  date: string; // ISO 8601 timestamp
  weightKg: number;
  note?: string;
}

/** A single water intake event, stored in milliliters. */
export interface WaterEntry {
  id: string;
  date: string;
  dayKey: string;
  amountML: number;
}

export interface Supplement {
  id: string;
  name: string;
  dose?: string;
  timeOfDayLabel?: string;
  notes?: string;
  isArchived: boolean;
  sortOrder: number;
  createdAt: string;
}

/** One "taken" check for a supplement on a given day. */
export interface SupplementLog {
  id: string;
  supplementId: string;
  dayKey: string;
  loggedAt: string;
}
