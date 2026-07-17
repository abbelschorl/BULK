/* Daily supplement checklist. Simple and satisfying: tap to check off,
   completion ring up top, management lives in Settings. */

import { useQuery } from "../../db/hooks";
import { repo, newId } from "../../db/repo";
import { completedSupplementIDs, completionFraction } from "../../logic/supplementDay";
import { todayKey } from "../../models/dayKey";
import type { Supplement } from "../../models/types";
import { MiniRing } from "../../components/progress";
import { CheckIcon } from "../../components/icons";

export default function SupplementsView() {
  const today = todayKey();
  const supplements = useQuery(() => repo.allSupplements(), []) ?? [];
  const logs = useQuery(() => repo.supplementLogsForDay(today), [today]) ?? [];

  const active = supplements.filter((s) => !s.isArchived);
  const completed = completedSupplementIDs(logs, today);
  const fraction = completionFraction(active.length, completed.size);
  const allDone = active.length > 0 && completed.size === active.length;

  const toggle = (supplement: Supplement, done: boolean) => {
    if (done) {
      for (const log of logs) {
        if (log.supplementId === supplement.id) void repo.deleteSupplementLog(log.id);
      }
    } else {
      void repo.saveSupplementLog({
        id: newId(),
        supplementId: supplement.id,
        dayKey: today,
        loggedAt: new Date().toISOString(),
      });
    }
  };

  return (
    <div className="screen">
      <h1 className="screen-title">Supplements</h1>

      {active.length === 0 ? (
        <div className="card diary-empty">
          <div className="diary-empty-title">No active supplements</div>
          <div className="text-tertiary">
            Add or re-activate supplements in Settings → Manage supplements.
          </div>
        </div>
      ) : (
        <>
          <div className="card row supplement-completion">
            <MiniRing
              fraction={fraction}
              color={allDone ? "var(--goal-reached)" : "var(--text-secondary)"}
              size={54}
              lineWidth={6}
            />
            <div>
              <div
                className="supplement-completion-title"
                style={allDone ? { color: "var(--goal-reached)" } : undefined}
              >
                {allDone ? "All done for today" : `${completed.size} of ${active.length} taken`}
              </div>
              <div className="text-tertiary supplement-completion-sub">
                {Math.round(fraction * 100)}% complete
              </div>
            </div>
          </div>

          <div className="card list-card">
            {active.map((supplement) => {
              const done = completed.has(supplement.id);
              return (
                <button
                  key={supplement.id}
                  className="supplement-row"
                  onClick={() => toggle(supplement, done)}
                  aria-label={`${supplement.name}, ${done ? "taken" : "not taken"}`}
                >
                  <span className={`supplement-check ${done ? "done" : ""}`}>
                    {done && <CheckIcon size={14} />}
                  </span>
                  <span className="food-row-left">
                    <span
                      className="supplement-row-name"
                      style={done ? { textDecoration: "line-through", color: "var(--text-tertiary)" } : undefined}
                    >
                      {supplement.name}
                    </span>
                    {(supplement.dose || supplement.timeOfDayLabel) && (
                      <span className="food-row-detail">
                        {[supplement.dose, supplement.timeOfDayLabel].filter(Boolean).join(" · ")}
                      </span>
                    )}
                  </span>
                </button>
              );
            })}
          </div>
        </>
      )}
    </div>
  );
}
