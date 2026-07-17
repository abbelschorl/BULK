/* Compact supplement completion summary on Today. Tapping a pill toggles it,
   so most days never need the Supplements tab at all. */

import { repo, newId } from "../../db/repo";
import { completedSupplementIDs, completionFraction } from "../../logic/supplementDay";
import type { Supplement, SupplementLog } from "../../models/types";
import { MiniRing } from "../../components/progress";
import { CheckIcon } from "../../components/icons";

export default function SupplementSummaryCard({
  supplements,
  logs,
  dayKey,
}: {
  supplements: Supplement[];
  logs: SupplementLog[];
  dayKey: string;
}) {
  if (supplements.length === 0) return null;

  const completed = completedSupplementIDs(logs, dayKey);

  const toggle = (supplement: Supplement, done: boolean) => {
    if (done) {
      for (const log of logs) {
        if (log.supplementId === supplement.id && log.dayKey === dayKey) {
          void repo.deleteSupplementLog(log.id);
        }
      }
    } else {
      void repo.saveSupplementLog({
        id: newId(),
        supplementId: supplement.id,
        dayKey,
        loggedAt: new Date().toISOString(),
      });
    }
  };

  return (
    <div className="card supplement-summary">
      <div className="row">
        <MiniRing
          fraction={completionFraction(supplements.length, completed.size)}
          color="var(--goal-reached)"
        />
        <span className="water-strip-title">Supplements</span>
        <span className="spacer" />
        <span className="text-tertiary supplement-count">
          {completed.size}/{supplements.length}
        </span>
      </div>
      <div className="supplement-pills">
        {supplements.map((s) => {
          const done = completed.has(s.id);
          return (
            <button
              key={s.id}
              className={`supplement-pill ${done ? "done" : ""}`}
              onClick={() => toggle(s, done)}
              aria-label={`${s.name}, ${done ? "taken" : "not taken"}`}
            >
              {done ? <CheckIcon size={13} /> : <span className="pill-circle" />}
              {s.name}
            </button>
          );
        })}
      </div>
    </div>
  );
}
