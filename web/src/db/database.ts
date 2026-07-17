/* IndexedDB schema. One object store per model, keyed by string id, with
   dayKey indexes where the app queries per-day. */

import { openDB, type DBSchema, type IDBPDatabase } from "idb";
import type {
  FoodItem,
  LogEntry,
  SavedMeal,
  Supplement,
  SupplementLog,
  WaterEntry,
  WeightEntry,
} from "../models/types";

export interface BulkDB extends DBSchema {
  foods: { key: string; value: FoodItem };
  logEntries: { key: string; value: LogEntry; indexes: { byDay: string } };
  savedMeals: { key: string; value: SavedMeal };
  weightEntries: { key: string; value: WeightEntry };
  waterEntries: { key: string; value: WaterEntry; indexes: { byDay: string } };
  supplements: { key: string; value: Supplement };
  supplementLogs: { key: string; value: SupplementLog; indexes: { byDay: string } };
}

export const STORE_NAMES = [
  "foods",
  "logEntries",
  "savedMeals",
  "weightEntries",
  "waterEntries",
  "supplements",
  "supplementLogs",
] as const;

export type StoreName = (typeof STORE_NAMES)[number];

let dbPromise: Promise<IDBPDatabase<BulkDB>> | null = null;

export function getDB(): Promise<IDBPDatabase<BulkDB>> {
  dbPromise ??= openDB<BulkDB>("bulk", 1, {
    upgrade(db) {
      db.createObjectStore("foods", { keyPath: "id" });
      const logs = db.createObjectStore("logEntries", { keyPath: "id" });
      logs.createIndex("byDay", "dayKey");
      db.createObjectStore("savedMeals", { keyPath: "id" });
      db.createObjectStore("weightEntries", { keyPath: "id" });
      const water = db.createObjectStore("waterEntries", { keyPath: "id" });
      water.createIndex("byDay", "dayKey");
      db.createObjectStore("supplements", { keyPath: "id" });
      const suppLogs = db.createObjectStore("supplementLogs", { keyPath: "id" });
      suppLogs.createIndex("byDay", "dayKey");
    },
  });
  return dbPromise;
}

/** Test hook: forces the next getDB() to reopen (fake-indexeddb resets). */
export function resetDBForTests(): void {
  dbPromise = null;
}
