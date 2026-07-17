/* Large minimum-goal card for calories or protein. Red-orange while below the
   minimum, green once reached — no upper range, ever. */

import { evaluateGoal, goalProgress } from "../../logic/goalState";
import { GoalProgressBar } from "../../components/progress";
import { CheckIcon } from "../../components/icons";

export default function GoalCard({
  title,
  unit,
  consumed,
  minimum,
  remainingText,
  reachedText,
  valueText,
}: {
  title: string;
  unit: string;
  consumed: number;
  minimum: number;
  remainingText: (remaining: number) => string;
  reachedText: string;
  valueText: string;
}) {
  const state = evaluateGoal(consumed, minimum);
  const color = state.reached ? "var(--goal-reached)" : "var(--below-goal)";

  return (
    <div className="card goal-card">
      <div className="row">
        <span className="goal-card-title">{title}</span>
        <span className="spacer" />
        <span className="goal-card-status" style={{ color }}>
          {state.reached ? (
            <>
              <CheckIcon size={14} /> {reachedText}
            </>
          ) : (
            remainingText(state.remaining)
          )}
        </span>
      </div>
      <div className="goal-card-value">
        {valueText} <span className="goal-card-unit">{unit}</span>
      </div>
      <GoalProgressBar fraction={goalProgress(consumed, minimum)} color={color} />
    </div>
  );
}
