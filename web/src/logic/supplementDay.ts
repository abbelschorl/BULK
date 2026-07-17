/* Ported from Bulk/Logic/SupplementDay.swift. History lives in SupplementLog
   rows, so "resetting" for a new day is just querying a new dayKey — past
   days keep their logs untouched. */

import type { SupplementLog } from "../models/types";

export function completedSupplementIDs(logs: SupplementLog[], dayKey: string): Set<string> {
  return new Set(logs.filter((l) => l.dayKey === dayKey).map((l) => l.supplementId));
}

export function completionFraction(activeCount: number, completedCount: number): number {
  if (activeCount <= 0) return 0;
  return Math.min(Math.max(completedCount / activeCount, 0), 1);
}
