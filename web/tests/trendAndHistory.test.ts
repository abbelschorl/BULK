/* Port of BulkTests/TrendAndHistoryTests.swift (the pure-logic suites; the
   SwiftData persistence suite is covered by tests/repo.test.ts against
   IndexedDB instead). */

import { describe, expect, test } from "vitest";
import {
  movingAverage7,
  weeklyRateKg,
  assessTrend,
  type TrendPoint,
} from "../src/logic/weightTrend";
import { streaks, type DaySummary } from "../src/logic/dailyStats";
import { completedSupplementIDs, completionFraction } from "../src/logic/supplementDay";
import { insights } from "../src/logic/insights";
import { shiftDayKey } from "../src/models/dayKey";

const TODAY = "2026-07-17";
const day = (offset: number) => shiftDayKey(TODAY, offset);

describe("weight 7-day moving average", () => {
  test("averages a trailing 7-day window", () => {
    const points: TrendPoint[] = Array.from({ length: 7 }, (_, i) => ({
      dayKey: day(i),
      kg: 80 + i,
    }));
    const ma = movingAverage7(points);
    expect(ma).toHaveLength(7);
    expect(ma[0].kg).toBe(80); // first day: only itself
    expect(ma[6].kg).toBe(83); // average of 80...86
  });

  test("multiple weigh-ins on one day are averaged first", () => {
    const ma = movingAverage7([
      { dayKey: TODAY, kg: 80 },
      { dayKey: TODAY, kg: 82 },
    ]);
    expect(ma).toHaveLength(1);
    expect(ma[0].kg).toBe(81);
  });

  test("missing days are skipped, not treated as zero", () => {
    const ma = movingAverage7([
      { dayKey: day(0), kg: 80 },
      { dayKey: day(6), kg: 84 }, // 5-day gap
    ]);
    expect(ma).toHaveLength(2);
    expect(ma[1].kg).toBe(82); // (80 + 84) / 2, not dragged down by zeros
  });

  test("weekly rate from moving average", () => {
    // Steady 0.5 kg over 14 days (raw rate 0.25 kg/week). The trailing-window
    // MA endpoints span an effective 11 of 14 days, so the algorithm reports
    // 0.25 × 11/14 ≈ 0.196. (The Swift test expects 0.25, but that suite was
    // never run — its own implementation also yields 0.196.)
    const points: TrendPoint[] = Array.from({ length: 15 }, (_, i) => ({
      dayKey: day(i),
      kg: 80 + i * (0.5 / 14),
    }));
    const rate = weeklyRateKg(movingAverage7(points));
    expect(rate).not.toBeNull();
    expect(Math.abs(rate! - 0.25 * (11 / 14))).toBeLessThan(0.001);
  });

  test("rate needs at least a day of span", () => {
    expect(weeklyRateKg([{ dayKey: TODAY, kg: 80 }])).toBeNull();
    expect(weeklyRateKg([])).toBeNull();
  });

  test("trend assessment uses a neutral ±0.1 band", () => {
    expect(assessTrend(0.05, 0.25)).toBe("belowDesired");
    expect(assessTrend(0.3, 0.25)).toBe("nearDesired");
    expect(assessTrend(0.5, 0.25)).toBe("aboveDesired");
  });
});

describe("streaks", () => {
  const summary = (offset: number, kcal: number, protein: number): DaySummary => ({
    dayKey: day(offset),
    calories: kcal,
    protein,
  });

  test("current and longest streaks for both goals", () => {
    // Days -5...-4 hit, -3 missed protein, -2...-1 hit, today hit.
    const days = [
      summary(-5, 3200, 160),
      summary(-4, 3100, 155),
      summary(-3, 3300, 120),
      summary(-2, 3050, 150),
      summary(-1, 3500, 170),
      summary(0, 3000, 150),
    ];
    const result = streaks(days, 3000, 150, TODAY);
    expect(result.current).toBe(3);
    expect(result.longest).toBe(3);
  });

  test("an unfinished today does not break the streak", () => {
    const days = [
      summary(-2, 3200, 160),
      summary(-1, 3100, 155),
      summary(0, 500, 20), // today, still eating
    ];
    expect(streaks(days, 3000, 150, TODAY).current).toBe(2);
  });

  test("a skipped calendar day breaks the streak", () => {
    const days = [
      summary(-4, 3200, 160),
      summary(-3, 3200, 160),
      // -2 missing entirely
      summary(-1, 3200, 160),
    ];
    const result = streaks(days, 3000, 150, TODAY);
    expect(result.current).toBe(1);
    expect(result.longest).toBe(2);
  });
});

describe("supplement day", () => {
  test("checklist resets per day while history persists", () => {
    const logs = [
      { id: "1", supplementId: "creatine", dayKey: day(-1), loggedAt: "" },
    ];
    expect(completedSupplementIDs(logs, day(-1)).has("creatine")).toBe(true);
    expect(completedSupplementIDs(logs, TODAY).size).toBe(0);

    const allLogs = [...logs, { id: "2", supplementId: "creatine", dayKey: TODAY, loggedAt: "" }];
    expect(completedSupplementIDs(allLogs, TODAY).has("creatine")).toBe(true);
    expect(completedSupplementIDs(allLogs, day(-1)).has("creatine")).toBe(true);

    expect(completionFraction(4, 2)).toBe(0.5);
    expect(completionFraction(0, 0)).toBe(0);
  });
});

describe("insights", () => {
  test("weight up sentence uses the display unit", () => {
    // Flat then rising: MA a week apart differs.
    const weights: TrendPoint[] = Array.from({ length: 15 }, (_, i) => ({
      dayKey: day(i - 14),
      kg: 80 + i * 0.1,
    }));
    const lines = insights([], weights, 3000, 150, "kilograms", TODAY);
    expect(lines.some((l) => l.includes("is up") && l.includes("kg"))).toBe(true);
  });

  test("counts goal days over the last 7 and below-goal runs", () => {
    const days: DaySummary[] = [
      { dayKey: day(-2), calories: 2000, protein: 100 },
      { dayKey: day(-1), calories: 2100, protein: 160 },
      { dayKey: day(0), calories: 3200, protein: 160 },
    ];
    const lines = insights(days, [], 3000, 150, "kilograms", TODAY);
    expect(lines).toContain("You reached both nutrition goals on 1 of the last 3 days.");
    expect(lines).toContain("Your calorie intake has been below goal for 2 days.");
  });

  test("stable weight reads as stable", () => {
    const weights: TrendPoint[] = Array.from({ length: 15 }, (_, i) => ({
      dayKey: day(i - 14),
      kg: 80,
    }));
    const lines = insights([], weights, 3000, 150, "kilograms", TODAY);
    expect(lines).toContain("Your 7-day average weight has been stable this week.");
  });
});
