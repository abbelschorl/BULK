/* Ported from Bulk/Logic/WeightTrendCalculator.swift: 7-day moving average
   and weekly rate of change over (dayKey, kg) points. */

import { dayKeyDiff, dayKeyOf, shiftDayKey } from "../models/dayKey";
import type { WeightEntry } from "../models/types";

export interface TrendPoint {
  dayKey: string;
  kg: number;
}

export function trendPoints(entries: WeightEntry[]): TrendPoint[] {
  return entries.map((e) => ({ dayKey: dayKeyOf(new Date(e.date)), kg: e.weightKg }));
}

/**
 * For each day that has at least one weigh-in, averages that day's weigh-ins,
 * then averages over a trailing 7-calendar-day window ending on that day.
 * Missing days are simply absent from the window.
 */
export function movingAverage7(points: TrendPoint[]): TrendPoint[] {
  const byDay = new Map<string, number[]>();
  for (const p of points) {
    const list = byDay.get(p.dayKey) ?? [];
    list.push(p.kg);
    byDay.set(p.dayKey, list);
  }
  const dailyAverages = [...byDay.entries()]
    .map(([dayKey, kgs]) => ({ dayKey, kg: kgs.reduce((a, b) => a + b, 0) / kgs.length }))
    .sort((a, b) => (a.dayKey < b.dayKey ? -1 : 1));

  return dailyAverages.map((current) => {
    const windowStart = shiftDayKey(current.dayKey, -6);
    const window = dailyAverages.filter(
      (p) => p.dayKey >= windowStart && p.dayKey <= current.dayKey,
    );
    const avg = window.reduce((a, p) => a + p.kg, 0) / window.length;
    return { dayKey: current.dayKey, kg: avg };
  });
}

/**
 * Weekly rate of change in kg/week from the first and last moving-average
 * points. Null when there is less than a day of trend data to compare.
 */
export function weeklyRateKg(movingAverage: TrendPoint[]): number | null {
  if (movingAverage.length === 0) return null;
  const first = movingAverage[0];
  const last = movingAverage[movingAverage.length - 1];
  const days = dayKeyDiff(first.dayKey, last.dayKey);
  if (days < 1) return null;
  return ((last.kg - first.kg) / days) * 7;
}

export type TrendAssessment = "belowDesired" | "nearDesired" | "aboveDesired";

/** Compares observed vs desired weekly rate with a ±0.1 kg/week "near" band. */
export function assessTrend(weeklyRate: number, desiredWeeklyGainKg: number): TrendAssessment {
  const tolerance = 0.1;
  if (weeklyRate < desiredWeeklyGainKg - tolerance) return "belowDesired";
  if (weeklyRate > desiredWeeklyGainKg + tolerance) return "aboveDesired";
  return "nearDesired";
}
