/* Typed data access on top of IndexedDB. Every write bumps a change counter
   so useQuery hooks re-run. */

import { getDB, STORE_NAMES, type StoreName } from "./database";
import type {
  FoodItem,
  LogEntry,
  SavedMeal,
  Supplement,
  SupplementLog,
  WaterEntry,
  WeightEntry,
} from "../models/types";

type Listener = () => void;
const listeners = new Set<Listener>();
let version = 0;

export function subscribe(listener: Listener): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

export function dataVersion(): number {
  return version;
}

export function notifyChanged(): void {
  version += 1;
  for (const l of listeners) l();
}

export function newId(): string {
  return crypto.randomUUID();
}

async function put<T>(store: StoreName, value: T): Promise<void> {
  const db = await getDB();
  await db.put(store, value as never);
  notifyChanged();
}

async function remove(store: StoreName, id: string): Promise<void> {
  const db = await getDB();
  await db.delete(store, id);
  notifyChanged();
}

export const repo = {
  // Foods
  saveFood: (f: FoodItem) => put("foods", f),
  deleteFood: (id: string) => remove("foods", id),
  async allFoods(): Promise<FoodItem[]> {
    return (await getDB()).getAll("foods");
  },
  async foodByBarcode(barcode: string): Promise<FoodItem | undefined> {
    const foods = await this.allFoods();
    return foods.find((f) => f.barcode === barcode);
  },

  // Log entries
  saveEntry: (e: LogEntry) => put("logEntries", e),
  deleteEntry: (id: string) => remove("logEntries", id),
  async entriesForDay(dayKey: string): Promise<LogEntry[]> {
    return (await getDB()).getAllFromIndex("logEntries", "byDay", dayKey);
  },
  async allEntries(): Promise<LogEntry[]> {
    return (await getDB()).getAll("logEntries");
  },

  // Saved meals
  saveMeal: (m: SavedMeal) => put("savedMeals", m),
  deleteMeal: (id: string) => remove("savedMeals", id),
  async allMeals(): Promise<SavedMeal[]> {
    return (await getDB()).getAll("savedMeals");
  },

  // Weight
  saveWeight: (w: WeightEntry) => put("weightEntries", w),
  deleteWeight: (id: string) => remove("weightEntries", id),
  async allWeights(): Promise<WeightEntry[]> {
    const all = await (await getDB()).getAll("weightEntries");
    return all.sort((a, b) => a.date.localeCompare(b.date));
  },

  // Water
  saveWater: (w: WaterEntry) => put("waterEntries", w),
  deleteWater: (id: string) => remove("waterEntries", id),
  async waterForDay(dayKey: string): Promise<WaterEntry[]> {
    return (await getDB()).getAllFromIndex("waterEntries", "byDay", dayKey);
  },
  async allWater(): Promise<WaterEntry[]> {
    return (await getDB()).getAll("waterEntries");
  },

  // Supplements
  saveSupplement: (s: Supplement) => put("supplements", s),
  deleteSupplement: async (id: string) => {
    const db = await getDB();
    // Cascade: remove the supplement's history like the Swift model does.
    const logs = await db.getAll("supplementLogs");
    const tx = db.transaction(["supplements", "supplementLogs"], "readwrite");
    await tx.objectStore("supplements").delete(id);
    for (const log of logs.filter((l) => l.supplementId === id)) {
      await tx.objectStore("supplementLogs").delete(log.id);
    }
    await tx.done;
    notifyChanged();
  },
  async allSupplements(): Promise<Supplement[]> {
    const all = await (await getDB()).getAll("supplements");
    return all.sort((a, b) => a.sortOrder - b.sortOrder);
  },

  // Supplement logs
  saveSupplementLog: (l: SupplementLog) => put("supplementLogs", l),
  deleteSupplementLog: (id: string) => remove("supplementLogs", id),
  async supplementLogsForDay(dayKey: string): Promise<SupplementLog[]> {
    return (await getDB()).getAllFromIndex("supplementLogs", "byDay", dayKey);
  },
  async allSupplementLogs(): Promise<SupplementLog[]> {
    return (await getDB()).getAll("supplementLogs");
  },

  /** Wipes every store (used by import-replace and Settings danger zone). */
  async deleteAllData(): Promise<void> {
    const db = await getDB();
    const tx = db.transaction([...STORE_NAMES], "readwrite");
    for (const name of STORE_NAMES) await tx.objectStore(name).clear();
    await tx.done;
    notifyChanged();
  },
};
