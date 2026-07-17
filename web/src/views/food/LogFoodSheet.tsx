/* The logging sheet: pick grams (fast), pick a meal, see live totals, add.
   Also edits an existing entry (same UI, prefilled). */

import { useState } from "react";
import { repo } from "../../db/repo";
import { scalePer100g } from "../../logic/nutrition";
import type { LogEntry, MealType } from "../../models/types";
import { MEAL_DISPLAY_NAMES, MEAL_TYPES } from "../../models/types";
import { Format } from "../../support/format";
import { GramChips, MacroStat } from "../../components/progress";
import Sheet from "../../components/Sheet";
import { logPending, saveToLibrary, type PendingFood } from "./pendingFood";

export function SourceBadge({ label }: { label: string }) {
  return <span className="source-badge">{label}</span>;
}

export default function LogFoodSheet({
  pending,
  dayKey,
  initialMeal = "snack",
  editingEntry,
  onClose,
}: {
  pending: PendingFood;
  dayKey: string;
  initialMeal?: MealType;
  /** When set, the sheet edits this existing entry instead of adding. */
  editingEntry?: LogEntry;
  onClose: () => void;
}) {
  const initialGrams = editingEntry?.grams ?? pending.defaultServingGrams ?? 100;
  const [grams, setGrams] = useState(initialGrams);
  const [gramsText, setGramsText] = useState(String(initialGrams));
  const [meal, setMeal] = useState<MealType>(editingEntry?.mealType ?? initialMeal);
  const [savedToLibrary, setSavedToLibrary] = useState(false);

  const totals = scalePer100g(pending.per100g, grams);

  const onGramsText = (text: string) => {
    setGramsText(text);
    const value = Number(text.replace(",", "."));
    if (Number.isFinite(value) && value >= 0) setGrams(value);
  };

  const selectChip = (g: number) => {
    setGrams(g);
    setGramsText(String(g));
  };

  const commit = async () => {
    if (editingEntry) {
      await repo.saveEntry({ ...editingEntry, grams, mealType: meal });
    } else {
      await logPending(pending, grams, meal, dayKey);
    }
    onClose();
  };

  return (
    <Sheet title={editingEntry ? "Edit Entry" : "Log Food"} onClose={onClose}>
      <div className="card">
        <div className="food-sheet-name">{pending.name}</div>
        <div className="row food-sheet-meta">
          {pending.brand && <span className="text-secondary">{pending.brand}</span>}
          <SourceBadge label={pending.sourceLabel} />
        </div>
        <div className="text-tertiary food-sheet-per100">
          Per 100 g: {Format.kcal(pending.per100g.calories)} kcal ·{" "}
          {Format.macroGrams(pending.per100g.protein)} g protein
        </div>
      </div>

      {pending.hasIncompleteNutrition && (
        <div className="card incomplete-warning">
          ⚠️ Incomplete data: missing {pending.missingFields.join(", ")}. Values shown may
          understate what you're eating.
        </div>
      )}

      <div className="card">
        <div className="section-label">Amount</div>
        <div className="row grams-row">
          <input
            className="grams-input"
            type="text"
            inputMode="decimal"
            value={gramsText}
            onChange={(e) => onGramsText(e.target.value)}
            aria-label="Gram amount"
          />
          <span className="grams-unit">g</span>
        </div>
        <GramChips grams={grams} onSelect={selectChip} />
      </div>

      <div className="card">
        <div className="section-label">Meal</div>
        <div className="segmented">
          {MEAL_TYPES.map((type) => (
            <button
              key={type}
              className={meal === type ? "selected" : ""}
              onClick={() => setMeal(type)}
            >
              {MEAL_DISPLAY_NAMES[type]}
            </button>
          ))}
        </div>
      </div>

      <div className="card">
        <div className="log-totals-kcal">
          {Format.kcal(totals.calories)} <span className="goal-card-unit">kcal</span>
        </div>
        <div className="row">
          <MacroStat label="Protein" value={`${Format.macroGrams(totals.protein)} g`} />
          <MacroStat label="Carbs" value={`${Format.macroGrams(totals.carbs)} g`} />
          <MacroStat label="Fat" value={`${Format.macroGrams(totals.fat)} g`} />
        </div>
      </div>

      {pending.isPublicResult && !editingEntry && (
        <button
          className="link-button"
          disabled={savedToLibrary}
          onClick={async () => {
            await saveToLibrary(pending);
            setSavedToLibrary(true);
          }}
        >
          {savedToLibrary ? "✓ Saved to My Foods" : "Save to My Foods"}
        </button>
      )}

      <button className="pill-button primary full-width" disabled={grams <= 0} onClick={commit}>
        {editingEntry ? "Save" : "Add"}
      </button>
    </Sheet>
  );
}
