/* Saved meal sheets: log a whole meal in one tap, and create/edit reusable
   meals whose components snapshot their nutrition. */

import { useState } from "react";
import { repo, newId } from "../../db/repo";
import { useQuery } from "../../db/hooks";
import { dayTotals, scalePer100g } from "../../logic/nutrition";
import type { MealType, SavedMeal, SavedMealComponent } from "../../models/types";
import { FOOD_SOURCE_LABELS, MEAL_DISPLAY_NAMES, MEAL_TYPES } from "../../models/types";
import { Format } from "../../support/format";
import Sheet from "../../components/Sheet";
import { TrashIcon } from "../../components/icons";

/** Logs every component of a saved meal into the diary in one tap. */
export function LogSavedMealSheet({
  meal,
  dayKey,
  initialMeal = "snack",
  onClose,
}: {
  meal: SavedMeal;
  dayKey: string;
  initialMeal?: MealType;
  onClose: (didLog: boolean) => void;
}) {
  const [mealType, setMealType] = useState<MealType>(initialMeal);
  const components = [...meal.components].sort((a, b) => a.sortOrder - b.sortOrder);
  const totals = dayTotals(
    components.map((c) => ({
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

  const logAll = async () => {
    for (const c of components) {
      await repo.saveEntry({
        id: newId(),
        loggedAt: new Date().toISOString(),
        dayKey,
        mealType,
        grams: c.grams,
        foodName: c.foodName,
        foodBrand: c.foodBrand,
        per100g: { ...c.per100g },
        sourceLabel: c.sourceLabel,
      });
    }
    onClose(true);
  };

  return (
    <Sheet title="Log Meal" onClose={() => onClose(false)}>
      <div className="card">
        <div className="food-sheet-name">{meal.name}</div>
        <div className="text-secondary food-sheet-per100">
          {Format.kcal(totals.calories)} kcal · {Format.macroGrams(totals.protein)} g protein ·{" "}
          {Format.macroGrams(totals.carbs)} g carbs · {Format.macroGrams(totals.fat)} g fat
        </div>
      </div>

      <div className="card list-card">
        {components.map((c, i) => {
          const scaled = scalePer100g(c.per100g, c.grams);
          return (
            <div key={i} className="food-row static">
              <span className="food-row-left">
                <span className="food-row-name">{c.foodName}</span>
                <span className="food-row-detail">{Format.portionGrams(c.grams)}</span>
              </span>
              <span className="food-row-detail">{Format.kcal(scaled.calories)} kcal</span>
            </div>
          );
        })}
      </div>

      <div className="card">
        <div className="section-label">Log as</div>
        <div className="segmented">
          {MEAL_TYPES.map((type) => (
            <button
              key={type}
              className={mealType === type ? "selected" : ""}
              onClick={() => setMealType(type)}
            >
              {MEAL_DISPLAY_NAMES[type]}
            </button>
          ))}
        </div>
      </div>

      <button
        className="pill-button primary full-width"
        disabled={components.length === 0}
        onClick={logAll}
      >
        Add All
      </button>
    </Sheet>
  );
}

/** Create or edit a reusable meal. Changing a meal never rewrites past
    diary entries. */
export function SavedMealEditor({
  editingMeal,
  onClose,
}: {
  editingMeal?: SavedMeal;
  onClose: () => void;
}) {
  const allFoods = useQuery(() => repo.allFoods(), []) ?? [];
  const [name, setName] = useState(editingMeal?.name ?? "");
  const [components, setComponents] = useState<SavedMealComponent[]>(
    editingMeal ? [...editingMeal.components].sort((a, b) => a.sortOrder - b.sortOrder) : [],
  );
  const [showPicker, setShowPicker] = useState(false);

  const isValid = name.trim() !== "" && components.length > 0;

  const totals = dayTotals(
    components.map((c) => ({
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

  const save = async () => {
    if (!isValid) return;
    await repo.saveMeal({
      id: editingMeal?.id ?? newId(),
      name: name.trim(),
      createdAt: editingMeal?.createdAt ?? new Date().toISOString(),
      components: components.map((c, i) => ({ ...c, sortOrder: i })),
    });
    onClose();
  };

  return (
    <Sheet title={editingMeal ? "Edit Meal" : "New Meal"} onClose={onClose}>
      <div className="card form-card">
        <label className="field">
          <span>Name</span>
          <input
            placeholder="e.g. Morning oats"
            value={name}
            onChange={(e) => setName(e.target.value)}
          />
        </label>
      </div>

      <div className="card form-card">
        <div className="section-label">Foods</div>
        {components.map((c, i) => (
          <div key={i} className="row meal-component-row">
            <span className="food-row-left">
              <span className="food-row-name">{c.foodName}</span>
              <span className="food-row-detail">
                {Format.kcal(scalePer100g(c.per100g, c.grams).calories)} kcal
              </span>
            </span>
            <span className="spacer" />
            <input
              className="grams-input small"
              type="text"
              inputMode="decimal"
              value={String(c.grams)}
              onChange={(e) => {
                const v = Number(e.target.value.replace(",", "."));
                if (Number.isFinite(v) && v >= 0) {
                  setComponents(components.map((x, j) => (j === i ? { ...x, grams: v } : x)));
                }
              }}
              aria-label={`Grams of ${c.foodName}`}
            />
            <span className="text-tertiary">g</span>
            <button
              className="diary-row-delete"
              onClick={() => setComponents(components.filter((_, j) => j !== i))}
              aria-label={`Remove ${c.foodName}`}
            >
              <TrashIcon size={15} />
            </button>
          </div>
        ))}
        <button className="link-button" onClick={() => setShowPicker(true)}>
          + Add food from library
        </button>
        {components.length > 0 && (
          <div className="text-tertiary form-footnote">
            Total: {Format.kcal(totals.calories)} kcal · {Format.macroGrams(totals.protein)} g
            protein
          </div>
        )}
      </div>

      <button className="pill-button primary full-width" disabled={!isValid} onClick={save}>
        Save
      </button>

      {showPicker && (
        <Sheet title="Pick Food" onClose={() => setShowPicker(false)}>
          {allFoods.length === 0 ? (
            <div className="card diary-empty">
              <div className="diary-empty-title">No foods yet</div>
              <div className="text-tertiary">
                Create custom foods or save public foods to your library first.
              </div>
            </div>
          ) : (
            <div className="card list-card">
              {allFoods
                .sort((a, b) => a.name.localeCompare(b.name))
                .map((food) => (
                  <button
                    key={food.id}
                    className="food-row"
                    onClick={() => {
                      setComponents([
                        ...components,
                        {
                          foodName: food.name,
                          foodBrand: food.brand,
                          grams: food.defaultServingGrams ?? 100,
                          per100g: { ...food.per100g },
                          sourceLabel: FOOD_SOURCE_LABELS[food.source],
                          sortOrder: components.length,
                        },
                      ]);
                      setShowPicker(false);
                    }}
                  >
                    <span className="food-row-left">
                      <span className="food-row-name">{food.name}</span>
                      <span className="food-row-detail">
                        {Format.kcal(food.per100g.calories)} kcal / 100 g
                      </span>
                    </span>
                  </button>
                ))}
            </div>
          )}
        </Sheet>
      )}
    </Sheet>
  );
}
