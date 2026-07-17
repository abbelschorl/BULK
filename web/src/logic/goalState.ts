/* Ported from Bulk/Logic/GoalState.swift. Minimum-style goals only: below the
   minimum reads warm/muted, at or above reads green. There is deliberately no
   upper warning range. */

export interface GoalState {
  reached: boolean;
  /** Amount still missing to the minimum; 0 once reached. */
  remaining: number;
}

export function evaluateGoal(consumed: number, minimum: number): GoalState {
  if (consumed >= minimum) return { reached: true, remaining: 0 };
  return { reached: false, remaining: minimum - consumed };
}

/** Progress fraction toward the minimum, clamped to 0...1 for display. */
export function goalProgress(consumed: number, minimum: number): number {
  if (minimum <= 0) return consumed > 0 ? 1 : 0;
  return Math.min(Math.max(consumed / minimum, 0), 1);
}
