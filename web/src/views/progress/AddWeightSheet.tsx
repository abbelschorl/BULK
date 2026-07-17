/* Weigh-in entry: value in the user's unit, stored canonically in kg. */

import { useState } from "react";
import { repo, newId } from "../../db/repo";
import { useSettings } from "../../db/settings";
import { WEIGHT_UNIT_LABELS, weightToKg } from "../../models/units";
import Sheet from "../../components/Sheet";

export default function AddWeightSheet({ onClose }: { onClose: () => void }) {
  const settings = useSettings();
  const [text, setText] = useState("");
  const [note, setNote] = useState("");

  const value = Number(text.replace(",", "."));
  const isValid = Number.isFinite(value) && value > 0;

  const save = async () => {
    if (!isValid) return;
    await repo.saveWeight({
      id: newId(),
      date: new Date().toISOString(),
      weightKg: weightToKg(value, settings.weightUnit),
      note: note.trim() || undefined,
    });
    onClose();
  };

  return (
    <Sheet title="Add Weigh-In" onClose={onClose}>
      <div className="card form-card">
        <label className="field-inline">
          <span>Weight</span>
          <input
            type="text"
            inputMode="decimal"
            autoFocus
            placeholder="0.0"
            value={text}
            onChange={(e) => setText(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && save()}
          />
          <span className="text-tertiary">{WEIGHT_UNIT_LABELS[settings.weightUnit]}</span>
        </label>
        <label className="field">
          <span>Note (optional)</span>
          <input value={note} onChange={(e) => setNote(e.target.value)} />
        </label>
      </div>
      <button className="pill-button primary full-width" disabled={!isValid} onClick={save}>
        Save
      </button>
    </Sheet>
  );
}
