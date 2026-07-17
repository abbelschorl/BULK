/* Management sheets: personal food library, saved meals, supplements.
   Deleting/editing never touches past log entries — they carry snapshots. */

import { useState } from "react";
import { useQuery } from "../../db/hooks";
import { repo, newId } from "../../db/repo";
import type { FoodItem, SavedMeal, Supplement } from "../../models/types";
import { FOOD_SOURCE_LABELS } from "../../models/types";
import { dayTotals } from "../../logic/nutrition";
import { Format } from "../../support/format";
import Sheet from "../../components/Sheet";
import { StarIcon, TrashIcon } from "../../components/icons";
import CustomFoodEditor from "../food/CustomFoodEditor";
import { SavedMealEditor } from "../food/SavedMealSheets";

export function ManageFoodsSheet({ onClose }: { onClose: () => void }) {
  const foods = useQuery(() => repo.allFoods(), []) ?? [];
  const [editing, setEditing] = useState<FoodItem | null>(null);
  const [showNew, setShowNew] = useState(false);
  const sorted = [...foods].sort((a, b) => a.name.localeCompare(b.name));

  return (
    <Sheet title="My Foods" onClose={onClose}>
      {sorted.length === 0 && (
        <div className="card diary-empty">
          <div className="diary-empty-title">No foods yet</div>
          <div className="text-tertiary">Foods you create or save from search appear here.</div>
        </div>
      )}
      {sorted.length > 0 && (
        <div className="card list-card">
          {sorted.map((food) => (
            <div key={food.id} className="food-row static manage-row">
              <button className="food-row-left" onClick={() => setEditing(food)}>
                <span className="food-row-name">{food.name}</span>
                <span className="food-row-detail">
                  {Format.kcal(food.per100g.calories)} kcal ·{" "}
                  {Format.macroGrams(food.per100g.protein)} g protein / 100 g ·{" "}
                  {FOOD_SOURCE_LABELS[food.source]}
                </span>
              </button>
              <button
                className="manage-icon-button"
                style={food.isFavorite ? { color: "#e8c34a" } : undefined}
                onClick={() => void repo.saveFood({ ...food, isFavorite: !food.isFavorite })}
                aria-label={food.isFavorite ? `Unfavorite ${food.name}` : `Favorite ${food.name}`}
              >
                <StarIcon size={16} filled={food.isFavorite} />
              </button>
              <button
                className="diary-row-delete"
                onClick={() => void repo.deleteFood(food.id)}
                aria-label={`Delete ${food.name}`}
              >
                <TrashIcon size={15} />
              </button>
            </div>
          ))}
        </div>
      )}
      <button className="link-button" onClick={() => setShowNew(true)}>
        + Create custom food
      </button>

      {editing && <CustomFoodEditor editingFood={editing} onClose={() => setEditing(null)} />}
      {showNew && <CustomFoodEditor onClose={() => setShowNew(false)} />}
    </Sheet>
  );
}

export function ManageMealsSheet({ onClose }: { onClose: () => void }) {
  const meals = useQuery(() => repo.allMeals(), []) ?? [];
  const [editing, setEditing] = useState<SavedMeal | null>(null);
  const [showNew, setShowNew] = useState(false);
  const sorted = [...meals].sort((a, b) => a.name.localeCompare(b.name));

  return (
    <Sheet title="Saved Meals" onClose={onClose}>
      {sorted.length === 0 && (
        <div className="card diary-empty">
          <div className="diary-empty-title">No saved meals</div>
          <div className="text-tertiary">
            Save combinations you eat often, like “Morning oats”, and log them in one tap.
          </div>
        </div>
      )}
      {sorted.length > 0 && (
        <div className="card list-card">
          {sorted.map((meal) => {
            const totals = dayTotals(
              meal.components.map((c) => ({
                id: "",
                loggedAt: "",
                dayKey: "",
                mealType: "snack" as const,
                grams: c.grams,
                foodName: c.foodName,
                per100g: c.per100g,
                sourceLabel: c.sourceLabel,
              })),
            );
            return (
              <div key={meal.id} className="food-row static manage-row">
                <button className="food-row-left" onClick={() => setEditing(meal)}>
                  <span className="food-row-name">{meal.name}</span>
                  <span className="food-row-detail">
                    {meal.components.length} foods · {Format.kcal(totals.calories)} kcal
                  </span>
                </button>
                <button
                  className="diary-row-delete"
                  onClick={() => void repo.deleteMeal(meal.id)}
                  aria-label={`Delete ${meal.name}`}
                >
                  <TrashIcon size={15} />
                </button>
              </div>
            );
          })}
        </div>
      )}
      <button className="link-button" onClick={() => setShowNew(true)}>
        + Create saved meal
      </button>

      {editing && <SavedMealEditor editingMeal={editing} onClose={() => setEditing(null)} />}
      {showNew && <SavedMealEditor onClose={() => setShowNew(false)} />}
    </Sheet>
  );
}

export function ManageSupplementsSheet({ onClose }: { onClose: () => void }) {
  const supplements = useQuery(() => repo.allSupplements(), []) ?? [];
  const [editing, setEditing] = useState<Supplement | null>(null);
  const [showNew, setShowNew] = useState(false);

  const activeList = supplements.filter((s) => !s.isArchived);
  const archivedList = supplements.filter((s) => s.isArchived);

  const row = (s: Supplement) => (
    <div key={s.id} className="food-row static manage-row">
      <button className="food-row-left" onClick={() => setEditing(s)}>
        <span className="food-row-name">{s.name}</span>
        {(s.dose || s.timeOfDayLabel) && (
          <span className="food-row-detail">
            {[s.dose, s.timeOfDayLabel].filter(Boolean).join(" · ")}
          </span>
        )}
      </button>
      <button
        className="link-button inline"
        onClick={() => void repo.saveSupplement({ ...s, isArchived: !s.isArchived })}
      >
        {s.isArchived ? "Restore" : "Archive"}
      </button>
      <button
        className="diary-row-delete"
        onClick={() => void repo.deleteSupplement(s.id)}
        aria-label={`Delete ${s.name} and its history`}
      >
        <TrashIcon size={15} />
      </button>
    </div>
  );

  return (
    <Sheet title="Supplements" onClose={onClose}>
      {supplements.length === 0 && (
        <div className="card diary-empty">
          <div className="diary-empty-title">No supplements yet</div>
          <div className="text-tertiary">Add what you take daily — creatine, vitamin D, fish oil…</div>
        </div>
      )}
      {activeList.length > 0 && <div className="card list-card">{activeList.map(row)}</div>}
      {archivedList.length > 0 && (
        <>
          <div className="section-header">Archived</div>
          <div className="card list-card">{archivedList.map(row)}</div>
        </>
      )}
      <button className="link-button" onClick={() => setShowNew(true)}>
        + Add supplement
      </button>

      {(editing || showNew) && (
        <SupplementEditor
          editing={editing ?? undefined}
          nextSortOrder={supplements.length}
          onClose={() => {
            setEditing(null);
            setShowNew(false);
          }}
        />
      )}
    </Sheet>
  );
}

function SupplementEditor({
  editing,
  nextSortOrder,
  onClose,
}: {
  editing?: Supplement;
  nextSortOrder: number;
  onClose: () => void;
}) {
  const [name, setName] = useState(editing?.name ?? "");
  const [dose, setDose] = useState(editing?.dose ?? "");
  const [time, setTime] = useState(editing?.timeOfDayLabel ?? "");
  const [notes, setNotes] = useState(editing?.notes ?? "");

  const save = async () => {
    if (!name.trim()) return;
    await repo.saveSupplement({
      id: editing?.id ?? newId(),
      name: name.trim(),
      dose: dose.trim() || undefined,
      timeOfDayLabel: time.trim() || undefined,
      notes: notes.trim() || undefined,
      isArchived: editing?.isArchived ?? false,
      sortOrder: editing?.sortOrder ?? nextSortOrder,
      createdAt: editing?.createdAt ?? new Date().toISOString(),
    });
    onClose();
  };

  return (
    <Sheet title={editing ? "Edit Supplement" : "New Supplement"} onClose={onClose}>
      <div className="card form-card">
        <label className="field">
          <span>Name</span>
          <input autoFocus value={name} onChange={(e) => setName(e.target.value)} />
        </label>
        <label className="field">
          <span>Dose (optional)</span>
          <input placeholder="e.g. 5 g" value={dose} onChange={(e) => setDose(e.target.value)} />
        </label>
        <label className="field">
          <span>Time of day (optional)</span>
          <input placeholder="e.g. morning" value={time} onChange={(e) => setTime(e.target.value)} />
        </label>
        <label className="field">
          <span>Notes (optional)</span>
          <input value={notes} onChange={(e) => setNotes(e.target.value)} />
        </label>
      </div>
      <button className="pill-button primary full-width" disabled={!name.trim()} onClick={save}>
        Save
      </button>
    </Sheet>
  );
}
