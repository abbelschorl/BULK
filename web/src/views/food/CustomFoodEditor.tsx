/* Create or edit a custom food. All nutrition is entered per 100 g. Editing
   an existing food never touches past log entries (they hold snapshots). */

import { useState } from "react";
import { repo, newId } from "../../db/repo";
import type { FoodItem } from "../../models/types";
import Sheet from "../../components/Sheet";

function parseNum(text: string): number | null {
  const normalized = text.replace(",", ".").trim();
  if (!normalized) return null;
  const value = Number(normalized);
  return Number.isFinite(value) && value >= 0 ? value : null;
}

export default function CustomFoodEditor({
  prefillName = "",
  editingFood,
  onClose,
}: {
  prefillName?: string;
  editingFood?: FoodItem;
  onClose: () => void;
}) {
  const [name, setName] = useState(editingFood?.name ?? prefillName);
  const [brand, setBrand] = useState(editingFood?.brand ?? "");
  const [calories, setCalories] = useState(editingFood ? String(editingFood.per100g.calories) : "");
  const [protein, setProtein] = useState(editingFood ? String(editingFood.per100g.protein) : "");
  const [carbs, setCarbs] = useState(editingFood ? String(editingFood.per100g.carbs) : "");
  const [fat, setFat] = useState(editingFood ? String(editingFood.per100g.fat) : "");
  const [serving, setServing] = useState(
    editingFood?.defaultServingGrams != null ? String(editingFood.defaultServingGrams) : "",
  );
  const [barcode, setBarcode] = useState(editingFood?.barcode ?? "");
  const [notes, setNotes] = useState(editingFood?.notes ?? "");
  const [isFavorite, setIsFavorite] = useState(editingFood?.isFavorite ?? false);

  const parsed = {
    calories: parseNum(calories),
    protein: parseNum(protein),
    carbs: parseNum(carbs),
    fat: parseNum(fat),
  };
  const isValid =
    name.trim() !== "" &&
    parsed.calories !== null &&
    parsed.protein !== null &&
    parsed.carbs !== null &&
    parsed.fat !== null;

  const save = async () => {
    if (!isValid) return;
    const food: FoodItem = {
      id: editingFood?.id ?? newId(),
      name: name.trim(),
      brand: brand.trim() || undefined,
      per100g: {
        calories: parsed.calories!,
        protein: parsed.protein!,
        carbs: parsed.carbs!,
        fat: parsed.fat!,
      },
      defaultServingGrams: parseNum(serving) ?? undefined,
      barcode: barcode.trim() || undefined,
      notes: notes.trim() || undefined,
      isFavorite,
      source: editingFood?.source ?? "myFood",
      createdAt: editingFood?.createdAt ?? new Date().toISOString(),
      lastLoggedAt: editingFood?.lastLoggedAt,
    };
    await repo.saveFood(food);
    onClose();
  };

  const nutritionField = (
    label: string,
    unit: string,
    value: string,
    set: (v: string) => void,
  ) => (
    <label className="field-inline">
      <span>{label}</span>
      <input
        type="text"
        inputMode="decimal"
        placeholder="0"
        value={value}
        onChange={(e) => set(e.target.value)}
        aria-label={`${label} per 100 grams`}
      />
      <span className="text-tertiary">{unit}</span>
    </label>
  );

  return (
    <Sheet title={editingFood ? "Edit Food" : "New Food"} onClose={onClose}>
      <div className="card form-card">
        <label className="field">
          <span>Name</span>
          <input value={name} onChange={(e) => setName(e.target.value)} />
        </label>
        <label className="field">
          <span>Brand (optional)</span>
          <input value={brand} onChange={(e) => setBrand(e.target.value)} />
        </label>
      </div>

      <div className="card form-card">
        <div className="section-label">Nutrition per 100 g</div>
        {nutritionField("Calories", "kcal", calories, setCalories)}
        {nutritionField("Protein", "g", protein, setProtein)}
        {nutritionField("Carbs", "g", carbs, setCarbs)}
        {nutritionField("Fat", "g", fat, setFat)}
        <div className="text-tertiary form-footnote">
          Values come straight from the label. Raw and cooked versions of the same food should be
          separate entries — they are not interchangeable.
        </div>
      </div>

      <div className="card form-card">
        <label className="field-inline">
          <span>Default serving (optional)</span>
          <input
            type="text"
            inputMode="decimal"
            value={serving}
            onChange={(e) => setServing(e.target.value)}
          />
          <span className="text-tertiary">g</span>
        </label>
        <label className="field">
          <span>Barcode (optional)</span>
          <input inputMode="numeric" value={barcode} onChange={(e) => setBarcode(e.target.value)} />
        </label>
        <label className="field-inline checkbox">
          <span>Favorite</span>
          <input
            type="checkbox"
            checked={isFavorite}
            onChange={(e) => setIsFavorite(e.target.checked)}
          />
        </label>
        <label className="field">
          <span>Notes (optional)</span>
          <textarea rows={2} value={notes} onChange={(e) => setNotes(e.target.value)} />
        </label>
      </div>

      <button className="pill-button primary full-width" disabled={!isValid} onClick={save}>
        Save
      </button>
    </Sheet>
  );
}
