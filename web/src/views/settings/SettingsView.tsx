/* Settings: goals, units, library management, USDA key, backup, danger zone.
   Everything Bulk stores lives in this browser. */

import { useRef, useState } from "react";
import { repo } from "../../db/repo";
import { updateSettings, useSettings } from "../../db/settings";
import { waterDisplay } from "../../logic/waterMath";
import { Format } from "../../support/format";
import { exportBackupJSON, restoreBackup, ImportError } from "../../services/backup";
import Sheet from "../../components/Sheet";
import { ManageFoodsSheet, ManageMealsSheet, ManageSupplementsSheet } from "./ManageSheets";

function Stepper({
  label,
  valueText,
  onStep,
}: {
  label: string;
  valueText: string;
  onStep: (direction: 1 | -1) => void;
}) {
  return (
    <div className="row stepper-row">
      <span className="stepper-label">{label}</span>
      <span className="spacer" />
      <span className="stepper-value">{valueText}</span>
      <button className="stepper-button" onClick={() => onStep(-1)} aria-label={`Decrease ${label}`}>
        −
      </button>
      <button className="stepper-button" onClick={() => onStep(1)} aria-label={`Increase ${label}`}>
        +
      </button>
    </div>
  );
}

const clamp = (v: number, lo: number, hi: number) => Math.min(Math.max(v, lo), hi);

export default function SettingsView() {
  const settings = useSettings();
  const [openSheet, setOpenSheet] = useState<"foods" | "meals" | "supplements" | "usda" | null>(null);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const [deleteText, setDeleteText] = useState("");
  const [importJSON, setImportJSON] = useState<string | null>(null);
  const [status, setStatus] = useState<string | null>(null);
  const fileInput = useRef<HTMLInputElement>(null);

  const exportBackup = async () => {
    const json = await exportBackupJSON();
    const blob = new Blob([json], { type: "application/json" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `Bulk-backup-${new Date().toISOString().slice(0, 10)}.json`;
    a.click();
    URL.revokeObjectURL(url);
    setStatus("Backup exported.");
  };

  const onImportFile = async (file: File) => {
    const text = await file.text();
    try {
      // Validate before asking to replace; restore happens on confirm.
      const { decodeBackup } = await import("../../services/backup");
      decodeBackup(text);
      setImportJSON(text);
    } catch (e) {
      setStatus(e instanceof ImportError ? e.message : String(e));
    }
  };

  return (
    <div className="screen">
      <h1 className="screen-title">Settings</h1>

      <section>
        <div className="section-header">Nutrition Goals</div>
        <div className="card form-card">
          <Stepper
            label="Calorie minimum"
            valueText={`${settings.calorieMinimum} kcal`}
            onStep={(d) =>
              updateSettings({ calorieMinimum: clamp(settings.calorieMinimum + d * 50, 1000, 8000) })
            }
          />
          <Stepper
            label="Protein minimum"
            valueText={`${settings.proteinMinimum} g`}
            onStep={(d) =>
              updateSettings({ proteinMinimum: clamp(settings.proteinMinimum + d * 5, 40, 400) })
            }
          />
          <Stepper
            label="Desired weekly gain"
            valueText={Format.weeklyRate(settings.desiredWeeklyGainKg, settings.weightUnit)}
            onStep={(d) =>
              updateSettings({
                desiredWeeklyGainKg: clamp(
                  Math.round((settings.desiredWeeklyGainKg + d * 0.05) * 100) / 100,
                  0,
                  1,
                ),
              })
            }
          />
          <div className="text-tertiary form-footnote">
            Both goals are minimums. Progress shows red until you reach them, then green. There is
            no upper limit or warning range.
          </div>
        </div>
      </section>

      <section>
        <div className="section-header">Units & Water</div>
        <div className="card form-card">
          <div className="row stepper-row">
            <span className="stepper-label">Weight unit</span>
            <span className="spacer" />
            <div className="segmented compact">
              <button
                className={settings.weightUnit === "kilograms" ? "selected" : ""}
                onClick={() => updateSettings({ weightUnit: "kilograms" })}
              >
                kg
              </button>
              <button
                className={settings.weightUnit === "pounds" ? "selected" : ""}
                onClick={() => updateSettings({ weightUnit: "pounds" })}
              >
                lb
              </button>
            </div>
          </div>
          <div className="row stepper-row">
            <span className="stepper-label">Water unit</span>
            <span className="spacer" />
            <div className="segmented compact">
              <button
                className={settings.waterUnit === "milliliters" ? "selected" : ""}
                onClick={() => updateSettings({ waterUnit: "milliliters" })}
              >
                ml
              </button>
              <button
                className={settings.waterUnit === "fluidOunces" ? "selected" : ""}
                onClick={() => updateSettings({ waterUnit: "fluidOunces" })}
              >
                fl oz
              </button>
            </div>
          </div>
          <Stepper
            label="Daily water goal"
            valueText={waterDisplay(settings.waterGoalML, settings.waterUnit)}
            onStep={(d) =>
              updateSettings({ waterGoalML: clamp(settings.waterGoalML + d * 250, 500, 8000) })
            }
          />
        </div>
      </section>

      <section>
        <div className="section-header">Food & Data</div>
        <div className="card list-card">
          <button className="settings-row" onClick={() => setOpenSheet("foods")}>
            Manage custom foods <span className="chevron-right">›</span>
          </button>
          <button className="settings-row" onClick={() => setOpenSheet("meals")}>
            Manage saved meals <span className="chevron-right">›</span>
          </button>
          <button className="settings-row" onClick={() => setOpenSheet("supplements")}>
            Manage supplements <span className="chevron-right">›</span>
          </button>
          <button className="settings-row" onClick={() => setOpenSheet("usda")}>
            USDA API key{" "}
            <span className="text-tertiary">{settings.usdaAPIKey ? "set" : "not set"}</span>
          </button>
          <button className="settings-row" onClick={exportBackup}>
            Export backup (JSON)
          </button>
          <button className="settings-row" onClick={() => fileInput.current?.click()}>
            Import backup
          </button>
          <button className="settings-row destructive" onClick={() => setShowDeleteConfirm(true)}>
            Delete all data
          </button>
        </div>
        <div className="text-tertiary settings-footnote">
          Everything Bulk stores lives in this browser. Food search uses Open Food Facts
          (openfoodfacts.org, ODbL) and USDA FoodData Central (public domain); only your search text
          is sent to them, never your diary. Backups are compatible with the Bulk iOS app.
        </div>
      </section>

      <input
        ref={fileInput}
        type="file"
        accept="application/json,.json"
        hidden
        onChange={(e) => {
          const file = e.target.files?.[0];
          if (file) void onImportFile(file);
          e.target.value = "";
        }}
      />

      {openSheet === "foods" && <ManageFoodsSheet onClose={() => setOpenSheet(null)} />}
      {openSheet === "meals" && <ManageMealsSheet onClose={() => setOpenSheet(null)} />}
      {openSheet === "supplements" && <ManageSupplementsSheet onClose={() => setOpenSheet(null)} />}
      {openSheet === "usda" && <USDAKeySheet onClose={() => setOpenSheet(null)} />}

      {importJSON && (
        <Sheet title="Replace all data?" onClose={() => setImportJSON(null)}>
          <div className="card">
            Importing a backup replaces everything currently in Bulk with the backup's contents.
          </div>
          <button
            className="pill-button primary full-width"
            onClick={async () => {
              await restoreBackup(importJSON);
              setImportJSON(null);
              setStatus("Backup imported.");
            }}
          >
            Import & Replace
          </button>
          <button className="pill-button full-width" onClick={() => setImportJSON(null)}>
            Cancel
          </button>
        </Sheet>
      )}

      {showDeleteConfirm && (
        <Sheet
          title="Delete all data?"
          onClose={() => {
            setShowDeleteConfirm(false);
            setDeleteText("");
          }}
        >
          <div className="card">
            This permanently erases every food, log entry, meal, weigh-in, water entry, and
            supplement in this browser. There is no undo. Type DELETE to confirm.
          </div>
          <input
            autoFocus
            placeholder="Type DELETE to confirm"
            value={deleteText}
            onChange={(e) => setDeleteText(e.target.value)}
          />
          <button
            className="pill-button primary full-width destructive-bg"
            disabled={deleteText.trim().toUpperCase() !== "DELETE"}
            onClick={async () => {
              await repo.deleteAllData();
              setShowDeleteConfirm(false);
              setDeleteText("");
              setStatus("All data deleted.");
            }}
          >
            Delete Everything
          </button>
        </Sheet>
      )}

      {status && (
        <div className="toast" onClick={() => setStatus(null)}>
          {status}
        </div>
      )}

      <div className="text-tertiary settings-footnote">
        Bulk is private by design: no accounts, no analytics, no cloud. Food data © Open Food Facts
        contributors (ODbL) and USDA FoodData Central. Version 1.0.
      </div>
    </div>
  );
}

function USDAKeySheet({ onClose }: { onClose: () => void }) {
  const settings = useSettings();
  const [key, setKey] = useState(settings.usdaAPIKey);

  return (
    <Sheet title="USDA API Key" onClose={onClose}>
      <div className="card form-card">
        <label className="field">
          <span>API key</span>
          <input
            autoCapitalize="none"
            autoCorrect="off"
            spellCheck={false}
            value={key}
            onChange={(e) => setKey(e.target.value)}
          />
        </label>
        <div className="text-tertiary form-footnote">
          USDA search finds raw and cooked ingredients like "chicken breast, cooked" or "rice,
          dry". It needs a free API key: open api.data.gov/signup, enter your name and email — the
          key arrives by email — then paste it here. The key is stored only in this browser.
          Without it, Open Food Facts search and everything local still work.
        </div>
      </div>
      <button
        className="pill-button primary full-width"
        onClick={() => {
          updateSettings({ usdaAPIKey: key.trim() });
          onClose();
        }}
      >
        Save
      </button>
      {settings.usdaAPIKey && (
        <button
          className="pill-button full-width destructive"
          onClick={() => {
            updateSettings({ usdaAPIKey: "" });
            onClose();
          }}
        >
          Remove key
        </button>
      )}
    </Sheet>
  );
}
