/* Ported from Bulk/Logic/DailyStats.swift: per-day nutrition summaries used
   by Progress charts, streaks, and insights. */

import { shiftDayKey, todayKey } from "../models/dayKey";
import type { LogEntry } from "../models/types";
import { dayTotals } from "./nutrition";

export interface DaySummary {
  dayKey: string;
  calories: number;
  protein: number;
}

export function bothGoalsReached(day: DaySummary, calorieMin: number, proteinMin: number): boolean {
  return day.calories >= calorieMin && day.protein >= proteinMin;
}

/** Groups log entries into per-day summaries, sorted ascending by day.
    Days without entries are simply absent. */
export function daySummaries(entries: LogEntry[]): DaySummary[] {
  const byDay = new Map<string, LogEntry[]>();
  for (const e of entries) {
    const list = byDay.get(e.dayKey) ?? [];
    list.push(e);
    byDay.set(e.dayKey, list);
  }
  return [...byDay.entries()]
    .map(([dayKey, dayEntries]) => {
      const totals = dayTotals(dayEntries);
      return { dayKey, calories: totals.calories, protein: totals.protein };
    })
    .sort((a, b) => (a.dayKey < b.dayKey ? -1 : 1));
}

/** Percentage (0...100) of the given days on which `predicate` holds. */
export function percentageOfDays(
  days: DaySummary[],
  predicate: (d: DaySummary) => boolean,
): number {
  if (days.length === 0) return 0;
  return (days.filter(predicate).length / days.length) * 100;
}

export function averageCalories(days: DaySummary[]): number {
  if (days.length === 0) return 0;
  return days.reduce((sum, d) => sum + d.calories, 0) / days.length;
}

export function averageProtein(days: DaySummary[]): number {
  if (days.length === 0) return 0;
  return days.reduce((sum, d) => sum + d.protein, 0) / days.length;
}

/** Current and longest streaks of days hitting both goals. An unfinished
    today doesn't break the current streak — it then counts from yesterday. */
export function streaks(
  days: DaySummary[],
  calorieMin: number,
  proteinMin: number,
  today: string = todayKey(),
): { current: number; longest: number } {
  const hitDays = new Set(
    days.filter((d) => bothGoalsReached(d, calorieMin, proteinMin)).map((d) => d.dayKey),
  );
  if (hitDays.size === 0) return { current: 0, longest: 0 };

  let longest = 0;
  for (const day of hitDays) {
    if (hitDays.has(shiftDayKey(day, -1))) continue; // only start counting at run starts
    let length = 1;
    let cursor = day;
    while (hitDays.has(shiftDayKey(cursor, 1))) {
      length += 1;
      cursor = shiftDayKey(cursor, 1);
    }
    longest = Math.max(longest, length);
  }

  let current = 0;
  let cursor = today;
  if (!hitDays.has(cursor)) cursor = shiftDayKey(cursor, -1);
  while (hitDays.has(cursor)) {
    current += 1;
    cursor = shiftDayKey(cursor, -1);
  }

  return { current, longest };
}
