/* Ported from Bulk/Logic/InsightsEngine.swift: short, plain-language, fully
   deterministic insights from local data. No AI, no network — just arithmetic
   and fixed sentence templates. */

import { shiftDayKey, todayKey } from "../models/dayKey";
import { WEIGHT_UNIT_LABELS, weightFromKg, type WeightUnit } from "../models/units";
import { bothGoalsReached, type DaySummary } from "./dailyStats";
import { movingAverage7, type TrendPoint } from "./weightTrend";

export function insights(
  days: DaySummary[],
  weights: TrendPoint[],
  calorieMin: number,
  proteinMin: number,
  weightUnit: WeightUnit,
  today: string = todayKey(),
): string[] {
  const results: string[] = [];

  // Weight: compare today's 7-day moving average with the one from 7 days ago.
  const ma = movingAverage7(weights);
  if (ma.length >= 2) {
    const last = ma[ma.length - 1];
    const weekAgoCutoff = shiftDayKey(last.dayKey, -7);
    const reference = [...ma].reverse().find((p) => p.dayKey <= weekAgoCutoff);
    if (reference) {
      const delta = weightFromKg(last.kg - reference.kg, weightUnit);
      const magnitude = Math.abs(delta).toFixed(1);
      const unitLabel = WEIGHT_UNIT_LABELS[weightUnit];
      if (Math.abs(delta) < 0.05) {
        results.push("Your 7-day average weight has been stable this week.");
      } else if (delta > 0) {
        results.push(`Your 7-day average weight is up ${magnitude} ${unitLabel} this week.`);
      } else {
        results.push(`Your 7-day average weight is down ${magnitude} ${unitLabel} this week.`);
      }
    }
  }

  // Nutrition: goals hit in the last 7 finished-or-current days.
  const lastWeekStart = shiftDayKey(today, -6);
  const lastWeek = days.filter((d) => d.dayKey >= lastWeekStart && d.dayKey <= today);
  if (lastWeek.length > 0) {
    const bothHit = lastWeek.filter((d) => bothGoalsReached(d, calorieMin, proteinMin)).length;
    results.push(`You reached both nutrition goals on ${bothHit} of the last ${lastWeek.length} days.`);
  }

  // Run of consecutive most-recent logged days below the calorie minimum
  // (ignoring today, which is usually still in progress).
  const finishedDays = days
    .filter((d) => d.dayKey < today)
    .sort((a, b) => (a.dayKey > b.dayKey ? -1 : 1));
  let belowRun = 0;
  for (const day of finishedDays) {
    if (day.calories < calorieMin) belowRun += 1;
    else break;
  }
  if (belowRun >= 2) {
    results.push(`Your calorie intake has been below goal for ${belowRun} days.`);
  }

  return results;
}
