/* IndexedDB port of the Swift persistence suite: immutable history, cascade
   deletes, per-day queries. Runs against fake-indexeddb. */

import "fake-indexeddb/auto";
import { beforeEach, describe, expect, test } from "vitest";
import { IDBFactory } from "fake-indexeddb";
import { resetDBForTests } from "../src/db/database";
import { repo, newId } from "../src/db/repo";
import { entryTotals } from "../src/logic/nutrition";
import { completedSupplementIDs } from "../src/logic/supplementDay";
import type { FoodItem, LogEntry } from "../src/models/types";

beforeEach(() => {
  indexedDB = new IDBFactory();
  resetDBForTests();
});

function makeFood(): FoodItem {
  return {
    id: newId(),
    name: "Oats",
    per100g: { calories: 380, protein: 13, carbs: 60, fat: 7 },
    isFavorite: false,
    source: "myFood",
    createdAt: new Date().toISOString(),
  };
}

function logFood(food: FoodItem, dayKey: string): LogEntry {
  // What the log flow does: snapshot the food's values into the entry.
  return {
    id: newId(),
    loggedAt: new Date().toISOString(),
    dayKey,
    mealType: "breakfast",
    grams: 100,
    foodName: food.name,
    foodBrand: food.brand,
    per100g: { ...food.per100g },
    sourceLabel: "My Food",
    foodId: food.id,
  };
}

describe("immutable history", () => {
  test("editing a food does not change logged history", async () => {
    const food = makeFood();
    await repo.saveFood(food);
    await repo.saveEntry(logFood(food, "2026-07-17"));

    // User later "fixes" the food to different values.
    await repo.saveFood({
      ...food,
      name: "Oats (updated)",
      per100g: { calories: 400, protein: 15, carbs: 60, fat: 7 },
    });

    const entries = await repo.entriesForDay("2026-07-17");
    expect(entries).toHaveLength(1);
    expect(entries[0].foodName).toBe("Oats");
    expect(entryTotals(entries[0]).calories).toBe(380);
    expect(entryTotals(entries[0]).protein).toBe(13);

    // Deleting the food also leaves history intact.
    await repo.deleteFood(food.id);
    const after = await repo.entriesForDay("2026-07-17");
    expect(after).toHaveLength(1);
    expect(entryTotals(after[0]).calories).toBe(380);
  });

  test("per-day index only returns that day's entries", async () => {
    const food = makeFood();
    await repo.saveEntry(logFood(food, "2026-07-16"));
    await repo.saveEntry(logFood(food, "2026-07-17"));
    expect(await repo.entriesForDay("2026-07-17")).toHaveLength(1);
    expect(await repo.entriesForDay("2026-07-15")).toHaveLength(0);
  });
});

describe("supplements", () => {
  test("checklist resets per day while history persists", async () => {
    const creatine = {
      id: newId(),
      name: "Creatine",
      dose: "5 g",
      isArchived: false,
      sortOrder: 0,
      createdAt: new Date().toISOString(),
    };
    await repo.saveSupplement(creatine);
    await repo.saveSupplementLog({
      id: newId(),
      supplementId: creatine.id,
      dayKey: "2026-07-16",
      loggedAt: new Date().toISOString(),
    });

    const logs = await repo.allSupplementLogs();
    expect(completedSupplementIDs(logs, "2026-07-16").has(creatine.id)).toBe(true);
    expect(completedSupplementIDs(logs, "2026-07-17").size).toBe(0);
  });

  test("deleting a supplement cascades its logs", async () => {
    const s = {
      id: newId(),
      name: "Vitamin D",
      isArchived: false,
      sortOrder: 0,
      createdAt: new Date().toISOString(),
    };
    await repo.saveSupplement(s);
    await repo.saveSupplementLog({
      id: newId(),
      supplementId: s.id,
      dayKey: "2026-07-17",
      loggedAt: new Date().toISOString(),
    });
    await repo.deleteSupplement(s.id);
    expect(await repo.allSupplements()).toHaveLength(0);
    expect(await repo.allSupplementLogs()).toHaveLength(0);
  });
});

describe("delete all data", () => {
  test("wipes every store", async () => {
    const food = makeFood();
    await repo.saveFood(food);
    await repo.saveEntry(logFood(food, "2026-07-17"));
    await repo.saveWeight({
      id: newId(),
      date: new Date().toISOString(),
      weightKg: 80,
    });
    await repo.deleteAllData();
    expect(await repo.allFoods()).toHaveLength(0);
    expect(await repo.allEntries()).toHaveLength(0);
    expect(await repo.allWeights()).toHaveLength(0);
  });
});
