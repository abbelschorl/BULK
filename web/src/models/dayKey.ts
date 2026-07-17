/* Day keys ported from Bulk/Support/DayKey.swift. All diary grouping uses
   local-timezone calendar days, serialized as "YYYY-MM-DD". Arithmetic goes
   through local Date construction so DST transitions can't skip days. */

function pad(n: number): string {
  return n < 10 ? `0${n}` : String(n);
}

/** Local-timezone day key for a Date. */
export function dayKeyOf(date: Date): string {
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

export function todayKey(now: Date = new Date()): string {
  return dayKeyOf(now);
}

/** Noon local time on the keyed day — a DST-safe anchor for date math. */
export function dayKeyToDate(key: string): Date {
  const [y, m, d] = key.split("-").map(Number);
  return new Date(y, m - 1, d, 12);
}

export function shiftDayKey(key: string, days: number): string {
  const date = dayKeyToDate(key);
  date.setDate(date.getDate() + days);
  return dayKeyOf(date);
}

/** Whole calendar days from `a` to `b` (positive when b is later). */
export function dayKeyDiff(a: string, b: string): number {
  const ms = dayKeyToDate(b).getTime() - dayKeyToDate(a).getTime();
  return Math.round(ms / 86_400_000);
}

/** "Today", "Yesterday", "Tomorrow", or a medium formatted date. */
export function dayKeyDisplayName(key: string, now: Date = new Date()): string {
  const today = todayKey(now);
  if (key === today) return "Today";
  if (key === shiftDayKey(today, -1)) return "Yesterday";
  if (key === shiftDayKey(today, 1)) return "Tomorrow";
  return dayKeyToDate(key).toLocaleDateString(undefined, {
    month: "short",
    day: "numeric",
    year: "numeric",
  });
}
