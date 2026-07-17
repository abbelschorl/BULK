import { describe, expect, test } from "vitest";
import { weightFromKg, weightToKg, waterFromML, waterToML } from "../src/models/units";
import {
  dayKeyOf,
  dayKeyToDate,
  shiftDayKey,
  dayKeyDiff,
  dayKeyDisplayName,
} from "../src/models/dayKey";

describe("unit conversions", () => {
  test("kg/lb round-trips", () => {
    expect(weightFromKg(100, "pounds")).toBeCloseTo(220.462262185, 6);
    expect(weightToKg(220.462262185, "pounds")).toBeCloseTo(100, 6);
    expect(weightFromKg(82.5, "kilograms")).toBe(82.5);
  });

  test("ml/floz round-trips", () => {
    expect(waterFromML(29.5735295625, "fluidOunces")).toBeCloseTo(1, 9);
    expect(waterToML(1, "fluidOunces")).toBeCloseTo(29.5735295625, 9);
    expect(waterFromML(500, "milliliters")).toBe(500);
  });
});

describe("day keys", () => {
  test("formats local date", () => {
    expect(dayKeyOf(new Date(2026, 6, 17, 23, 59))).toBe("2026-07-17");
    expect(dayKeyOf(new Date(2026, 0, 3, 0, 0))).toBe("2026-01-03");
  });

  test("shift crosses month and year boundaries", () => {
    expect(shiftDayKey("2026-07-17", -1)).toBe("2026-07-16");
    expect(shiftDayKey("2026-01-01", -1)).toBe("2025-12-31");
    expect(shiftDayKey("2026-02-28", 1)).toBe("2026-03-01");
  });

  test("shift is stable across DST transitions", () => {
    // Europe/Berlin DST starts 2026-03-29; a naive +24h would skip or repeat.
    expect(shiftDayKey("2026-03-28", 1)).toBe("2026-03-29");
    expect(shiftDayKey("2026-03-29", 1)).toBe("2026-03-30");
    expect(shiftDayKey("2026-10-25", 1)).toBe("2026-10-26");
  });

  test("diff counts calendar days", () => {
    expect(dayKeyDiff("2026-07-10", "2026-07-17")).toBe(7);
    expect(dayKeyDiff("2026-07-17", "2026-07-10")).toBe(-7);
    expect(dayKeyDiff("2026-03-28", "2026-03-30")).toBe(2);
  });

  test("display names relative to a fixed now", () => {
    const now = new Date(2026, 6, 17, 10);
    expect(dayKeyDisplayName("2026-07-17", now)).toBe("Today");
    expect(dayKeyDisplayName("2026-07-16", now)).toBe("Yesterday");
    expect(dayKeyDisplayName("2026-07-18", now)).toBe("Tomorrow");
    expect(dayKeyDisplayName("2026-07-01", now)).toMatch(/Jul/);
  });

  test("round-trips through dayKeyToDate", () => {
    expect(dayKeyOf(dayKeyToDate("2026-07-17"))).toBe("2026-07-17");
  });
});
