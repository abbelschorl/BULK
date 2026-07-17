/* Port of BulkTests/CalculationTests.swift. Exact-Decimal assertions become
   toBeCloseTo, matching the accepted JS-number deviation. */

import { describe, expect, test } from "vitest";
import { scalePer100g, dayTotals } from "../src/logic/nutrition";
import { evaluateGoal, goalProgress } from "../src/logic/goalState";
import { totalML, waterProgress } from "../src/logic/waterMath";
import { waterFromML, waterToML } from "../src/models/units";
import type { LogEntry, WaterEntry } from "../src/models/types";

function entry(overrides: Partial<LogEntry>): LogEntry {
  return {
    id: crypto.randomUUID(),
    loggedAt: new Date().toISOString(),
    dayKey: "2026-07-17",
    mealType: "snack",
    grams: 100,
    foodName: "Food",
    per100g: { calories: 0, protein: 0, carbs: 0, fat: 0 },
    sourceLabel: "My Food",
    ...overrides,
  };
}

describe("nutrition scaling", () => {
  test("150 g of a 20 g/100 g protein food is 30 g protein", () => {
    const totals = scalePer100g({ calories: 165, protein: 20, carbs: 0, fat: 3.6 }, 150);
    expect(totals.protein).toBeCloseTo(30, 9);
    expect(totals.calories).toBeCloseTo(247.5, 9);
    expect(totals.fat).toBeCloseTo(5.4, 9);
  });

  test("zero grams gives zero everything", () => {
    const totals = scalePer100g({ calories: 380, protein: 13, carbs: 60, fat: 7 }, 0);
    expect(totals).toEqual({ calories: 0, protein: 0, carbs: 0, fat: 0 });
  });

  test("scaled values stay exact at display precision", () => {
    // 110 g of 0.3/100 g must read 0.33 (0.1+0.2-style pitfall).
    const totals = scalePer100g({ calories: 0, protein: 0.3, carbs: 0, fat: 0 }, 110);
    expect(totals.protein).toBeCloseTo(0.33, 9);
    expect(Number(totals.protein.toFixed(2))).toBe(0.33);
  });

  test("day totals sum entries", () => {
    const a = entry({
      mealType: "breakfast",
      grams: 100,
      foodName: "Oats",
      per100g: { calories: 380, protein: 13, carbs: 60, fat: 7 },
    });
    const b = entry({
      mealType: "lunch",
      grams: 200,
      foodName: "Chicken",
      per100g: { calories: 165, protein: 31, carbs: 0, fat: 3.6 },
    });
    const totals = dayTotals([a, b]);
    expect(totals.calories).toBeCloseTo(380 + 330, 9);
    expect(totals.protein).toBeCloseTo(13 + 62, 9);
  });
});

describe("goal state", () => {
  test("below minimum reports remaining", () => {
    const state = evaluateGoal(2400, 3000);
    expect(state.reached).toBe(false);
    expect(state.remaining).toBe(600);
  });

  test("exactly at minimum counts as reached", () => {
    expect(evaluateGoal(3000, 3000).reached).toBe(true);
  });

  test("above minimum stays reached — no upper warning range", () => {
    const state = evaluateGoal(5200, 3000);
    expect(state.reached).toBe(true);
    expect(state.remaining).toBe(0);
  });

  test("progress fraction clamps to 0...1", () => {
    expect(goalProgress(1500, 3000)).toBe(0.5);
    expect(goalProgress(4500, 3000)).toBe(1);
    expect(goalProgress(0, 3000)).toBe(0);
    expect(goalProgress(100, 0)).toBe(1);
  });
});

describe("water math", () => {
  function water(amountML: number): WaterEntry {
    return {
      id: crypto.randomUUID(),
      date: new Date().toISOString(),
      dayKey: "2026-07-17",
      amountML,
    };
  }

  test("totals sum a day's entries", () => {
    expect(totalML([water(250), water(500), water(330)])).toBe(1080);
  });

  test("progress clamps and handles zero goal", () => {
    expect(waterProgress(1500, 3000)).toBe(0.5);
    expect(waterProgress(4000, 3000)).toBe(1);
    expect(waterProgress(100, 0)).toBe(1);
    expect(waterProgress(0, 0)).toBe(0);
  });

  test("unit conversion round-trips", () => {
    const ml = waterToML(12, "fluidOunces");
    expect(Math.abs(waterFromML(ml, "fluidOunces") - 12)).toBeLessThan(0.0001);
    expect(Math.abs(ml - 354.88)).toBeLessThan(0.01);
  });
});
