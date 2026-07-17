/* The food diary grouped by meal, with per-meal calorie/protein totals and
   always-visible edit/delete controls. */

import { useState } from "react";
import { dayTotals, entryTotals } from "../../logic/nutrition";
import type { LogEntry, MealType } from "../../models/types";
import { MEAL_DISPLAY_NAMES, MEAL_TYPES } from "../../models/types";
import { Format } from "../../support/format";
import { PlusIcon, TrashIcon } from "../../components/icons";

export default function DiarySection({
  entries,
  onAdd,
  onEdit,
  onDelete,
}: {
  entries: LogEntry[];
  onAdd: (meal: MealType) => void;
  onEdit: (entry: LogEntry) => void;
  onDelete: (entry: LogEntry) => void;
}) {
  return (
    <section className="diary">
      <div className="section-header">Diary</div>
      {entries.length === 0 ? (
        <div className="card diary-empty">
          <div className="diary-empty-title">Nothing logged yet</div>
          <div className="text-tertiary">Add your first food to start filling today's goals.</div>
        </div>
      ) : (
        MEAL_TYPES.map((meal) => {
          const mealEntries = entries
            .filter((e) => e.mealType === meal)
            .sort((a, b) => a.loggedAt.localeCompare(b.loggedAt));
          if (mealEntries.length === 0) return null;
          return (
            <MealGroupCard
              key={meal}
              meal={meal}
              entries={mealEntries}
              onAdd={() => onAdd(meal)}
              onEdit={onEdit}
              onDelete={onDelete}
            />
          );
        })
      )}
    </section>
  );
}

function MealGroupCard({
  meal,
  entries,
  onAdd,
  onEdit,
  onDelete,
}: {
  meal: MealType;
  entries: LogEntry[];
  onAdd: () => void;
  onEdit: (entry: LogEntry) => void;
  onDelete: (entry: LogEntry) => void;
}) {
  const [expanded, setExpanded] = useState(true);
  const totals = dayTotals(entries);

  return (
    <div className="card meal-group">
      <button className="meal-group-header" onClick={() => setExpanded(!expanded)}>
        <span className="meal-group-name">{MEAL_DISPLAY_NAMES[meal]}</span>
        <span className="spacer" />
        <span className="meal-group-totals">
          {Format.kcal(totals.calories)} kcal · {Format.macroGrams(totals.protein)} g protein
        </span>
        <span className={`chevron ${expanded ? "open" : ""}`}>▾</span>
      </button>

      {expanded && (
        <>
          <div className="meal-group-rows">
            {entries.map((entry) => (
              <div key={entry.id} className="diary-row">
                <button className="diary-row-main" onClick={() => onEdit(entry)}>
                  <span className="diary-row-name">{entry.foodName}</span>
                  <span className="diary-row-detail">
                    {Format.portionGrams(entry.grams)} ·{" "}
                    {Format.macroGrams(entryTotals(entry).protein)} g protein
                  </span>
                </button>
                <span className="diary-row-kcal">
                  {Format.kcal(entryTotals(entry).calories)} kcal
                </span>
                <button
                  className="diary-row-delete"
                  onClick={() => onDelete(entry)}
                  aria-label={`Delete ${entry.foodName}`}
                >
                  <TrashIcon size={15} />
                </button>
              </div>
            ))}
          </div>
          <button className="meal-group-add" onClick={onAdd}>
            <PlusIcon size={13} /> Add to {MEAL_DISPLAY_NAMES[meal]}
          </button>
        </>
      )}
    </div>
  );
}
