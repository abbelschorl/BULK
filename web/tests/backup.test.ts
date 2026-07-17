/* Backup export/import: Swift-schema compatibility and full round-trip. */

import "fake-indexeddb/auto";
import { beforeEach, describe, expect, test } from "vitest";

// Node has no localStorage; a Map-backed stand-in is enough for settings.
if (typeof globalThis.localStorage === "undefined") {
  const store = new Map<string, string>();
  globalThis.localStorage = {
    getItem: (k: string) => store.get(k) ?? null,
    setItem: (k: string, v: string) => void store.set(k, String(v)),
    removeItem: (k: string) => void store.delete(k),
    clear: () => store.clear(),
    key: (i: number) => [...store.keys()][i] ?? null,
    get length() {
      return store.size;
    },
  } as Storage;
}
import { IDBFactory } from "fake-indexeddb";
import { resetDBForTests } from "../src/db/database";
import { repo, newId } from "../src/db/repo";
import { updateSettings, loadSettings } from "../src/db/settings";
import { exportBackupJSON, restoreBackup, decodeBackup, ImportError } from "../src/services/backup";

beforeEach(() => {
  indexedDB = new IDBFactory();
  resetDBForTests();
  localStorage.clear();
});

async function seed() {
  updateSettings({ calorieMinimum: 3200, weightUnit: "pounds" });
  await repo.saveFood({
    id: newId(),
    name: "Oats",
    brand: "Kölln",
    per100g: { calories: 372, protein: 13.5, carbs: 58.7, fat: 7 },
    defaultServingGrams: 40,
    isFavorite: true,
    source: "openFoodFacts",
    barcode: "4000521006112",
    createdAt: "2026-07-01T08:00:00Z",
  });
  await repo.saveEntry({
    id: newId(),
    loggedAt: "2026-07-17T07:30:00Z",
    dayKey: "2026-07-17",
    mealType: "breakfast",
    grams: 100,
    foodName: "Oats",
    per100g: { calories: 372, protein: 13.5, carbs: 58.7, fat: 7 },
    sourceLabel: "Open Food Facts",
  });
  await repo.saveMeal({
    id: newId(),
    name: "Morning oats",
    createdAt: "2026-07-01T08:00:00Z",
    components: [
      {
        foodName: "Oats",
        grams: 100,
        per100g: { calories: 372, protein: 13.5, carbs: 58.7, fat: 7 },
        sourceLabel: "My Food",
        sortOrder: 0,
      },
    ],
  });
  await repo.saveWeight({ id: newId(), date: "2026-07-17T06:00:00Z", weightKg: 82.5 });
  await repo.saveWater({
    id: newId(),
    date: "2026-07-17T09:00:00Z",
    dayKey: "2026-07-17",
    amountML: 500,
  });
  const suppId = newId();
  await repo.saveSupplement({
    id: suppId,
    name: "Creatine",
    dose: "5 g",
    isArchived: false,
    sortOrder: 0,
    createdAt: "2026-07-01T08:00:00Z",
  });
  await repo.saveSupplementLog({
    id: newId(),
    supplementId: suppId,
    dayKey: "2026-07-16",
    loggedAt: "2026-07-16T08:00:00Z",
  });
}

describe("backup", () => {
  test("export matches the Swift v1 schema", async () => {
    await seed();
    const backup = JSON.parse(await exportBackupJSON());

    expect(backup.version).toBe(1);
    expect(backup.settings.calorieMinimum).toBe(3200);
    expect(backup.settings.weightUnit).toBe("pounds");
    expect(backup.foods[0]).toMatchObject({
      name: "Oats",
      brand: "Kölln",
      caloriesPer100g: 372,
      proteinPer100g: 13.5,
      source: "openFoodFacts",
      isFavorite: true,
    });
    expect(backup.logEntries[0]).toMatchObject({
      mealType: "breakfast",
      grams: 100,
      foodName: "Oats",
      sourceLabel: "Open Food Facts",
    });
    // Swift-compatible dates: ISO 8601 without milliseconds.
    expect(backup.exportedAt).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/);
    expect(backup.logEntries[0].dayKey).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/);
    expect(backup.supplements[0].completedDayKeys).toHaveLength(1);
    expect(backup.supplements[0].isActive).toBe(true);
  });

  test("export → wipe → import restores everything", async () => {
    await seed();
    const json = await exportBackupJSON();

    await repo.deleteAllData();
    updateSettings({ calorieMinimum: 1111, weightUnit: "kilograms" });
    expect(await repo.allFoods()).toHaveLength(0);

    await restoreBackup(json);

    expect(loadSettings().calorieMinimum).toBe(3200);
    expect(loadSettings().weightUnit).toBe("pounds");

    const foods = await repo.allFoods();
    expect(foods).toHaveLength(1);
    expect(foods[0].name).toBe("Oats");
    expect(foods[0].per100g.protein).toBe(13.5);

    const entries = await repo.entriesForDay("2026-07-17");
    expect(entries).toHaveLength(1);
    expect(entries[0].mealType).toBe("breakfast");

    const meals = await repo.allMeals();
    expect(meals[0].components).toHaveLength(1);

    expect(await repo.allWeights()).toHaveLength(1);
    expect(await repo.waterForDay("2026-07-17")).toHaveLength(1);

    const supplements = await repo.allSupplements();
    expect(supplements[0].name).toBe("Creatine");
    const logs = await repo.supplementLogsForDay("2026-07-16");
    expect(logs).toHaveLength(1);
    expect(logs[0].supplementId).toBe(supplements[0].id);
  });

  test("garbage input throws ImportError and changes nothing", async () => {
    await seed();
    expect(() => decodeBackup("not json")).toThrow(ImportError);
    expect(() => decodeBackup('{"version": 2}')).toThrow(ImportError);
    expect(await repo.allFoods()).toHaveLength(1);
  });
});
