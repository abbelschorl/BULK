/* Deliberately understated water tracker: one compact row with quick-adds. */

import { useState } from "react";
import { repo, newId } from "../../db/repo";
import { useSettings } from "../../db/settings";
import { waterDisplay, waterProgress } from "../../logic/waterMath";
import { waterFromML, waterToML } from "../../models/units";
import { MiniRing } from "../../components/progress";
import { PlusIcon } from "../../components/icons";
import Sheet from "../../components/Sheet";

export default function WaterStrip({ dayKey, totalML }: { dayKey: string; totalML: number }) {
  const settings = useSettings();
  const [showCustom, setShowCustom] = useState(false);
  const [customText, setCustomText] = useState("");

  const add = (ml: number) => {
    void repo.saveWater({ id: newId(), date: new Date().toISOString(), dayKey, amountML: ml });
  };

  const quickAddLabel = (ml: number) =>
    settings.waterUnit === "milliliters"
      ? `+${ml}`
      : `+${Math.round(waterFromML(ml, settings.waterUnit))} oz`;

  const submitCustom = () => {
    const value = Number(customText.replace(",", "."));
    if (Number.isFinite(value) && value > 0) {
      add(waterToML(value, settings.waterUnit));
    }
    setCustomText("");
    setShowCustom(false);
  };

  return (
    <div className="card water-strip">
      <MiniRing
        fraction={waterProgress(totalML, settings.waterGoalML)}
        color="var(--accent-blue)"
      />
      <div>
        <div className="water-strip-title">Water</div>
        <div className="water-strip-amount">
          {waterDisplay(totalML, settings.waterUnit)} of{" "}
          {waterDisplay(settings.waterGoalML, settings.waterUnit)}
        </div>
      </div>
      <span className="spacer" />
      <button className="water-chip" onClick={() => add(250)} aria-label="Add 250 ml of water">
        {quickAddLabel(250)}
      </button>
      <button className="water-chip" onClick={() => add(500)} aria-label="Add 500 ml of water">
        {quickAddLabel(500)}
      </button>
      <button
        className="water-plus"
        onClick={() => setShowCustom(true)}
        aria-label="Add custom water amount"
      >
        <PlusIcon size={14} />
      </button>

      {showCustom && (
        <Sheet title="Add Water" onClose={() => setShowCustom(false)}>
          <label className="field">
            <span>Amount in {settings.waterUnit === "milliliters" ? "ml" : "fl oz"}</span>
            <input
              type="number"
              inputMode="decimal"
              autoFocus
              value={customText}
              onChange={(e) => setCustomText(e.target.value)}
              onKeyDown={(e) => e.key === "Enter" && submitCustom()}
            />
          </label>
          <button className="pill-button primary full-width" onClick={submitCustom}>
            Add
          </button>
        </Sheet>
      )}
    </div>
  );
}
