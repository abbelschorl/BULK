/* Home screen: answers "have I eaten enough today?" at a glance. */

import { useState } from "react";
import { useQuery } from "../../db/hooks";
import { repo } from "../../db/repo";
import { useSettings } from "../../db/settings";
import { dayTotals } from "../../logic/nutrition";
import { totalML } from "../../logic/waterMath";
import { dayKeyDisplayName, dayKeyToDate, shiftDayKey, todayKey } from "../../models/dayKey";
import type { LogEntry, MealType } from "../../models/types";
import { Format } from "../../support/format";
import { ChevronLeftIcon, ChevronRightIcon, PlusIcon } from "../../components/icons";
import { MacroStat } from "../../components/progress";
import Sheet from "../../components/Sheet";
import GoalCard from "./GoalCard";
import WaterStrip from "./WaterStrip";
import SupplementSummaryCard from "./SupplementSummaryCard";
import DiarySection from "./DiarySection";
import FoodCatalog from "../food/FoodCatalog";
import LogFoodSheet from "../food/LogFoodSheet";
import AddWeightSheet from "../progress/AddWeightSheet";
import { pendingFromEntry } from "../food/pendingFood";

/** Picks a sensible default meal from the current time of day. */
function suggestedMeal(): MealType {
  const hour = new Date().getHours();
  if (hour >= 4 && hour < 11) return "breakfast";
  if (hour >= 11 && hour < 15) return "lunch";
  if (hour >= 17 && hour < 22) return "dinner";
  return "snack";
}

export default function TodayView() {
  const settings = useSettings();
  const [selectedDay, setSelectedDay] = useState(todayKey());
  const [addFoodMeal, setAddFoodMeal] = useState<MealType | null>(null);
  const [editingEntry, setEditingEntry] = useState<LogEntry | null>(null);
  const [showWeighIn, setShowWeighIn] = useState(false);

  const dayEntries = useQuery(() => repo.entriesForDay(selectedDay), [selectedDay]) ?? [];
  const dayWater = useQuery(() => repo.waterForDay(selectedDay), [selectedDay]) ?? [];
  const supplements = useQuery(() => repo.allSupplements(), []) ?? [];
  const supplementLogs = useQuery(() => repo.supplementLogsForDay(selectedDay), [selectedDay]) ?? [];

  const activeSupplements = supplements.filter((s) => !s.isArchived);
  const totals = dayTotals(dayEntries);
  const isToday = selectedDay === todayKey();

  return (
    <div className="screen today">
      <div className="row today-topbar">
        <h1 className="screen-title">Bulk</h1>
        <span className="spacer" />
        <button
          className="pill-button"
          onClick={() => setShowWeighIn(true)}
          aria-label="Add weigh-in"
        >
          ⚖️ Weigh-in
        </button>
      </div>

      <div className="day-header">
        <button onClick={() => setSelectedDay(shiftDayKey(selectedDay, -1))} aria-label="Previous day">
          <ChevronLeftIcon />
        </button>
        <div className="day-header-center">
          <div className="day-header-name">{dayKeyDisplayName(selectedDay)}</div>
          {isToday ? (
            <div className="text-tertiary day-header-sub">
              {dayKeyToDate(selectedDay).toLocaleDateString(undefined, {
                month: "short",
                day: "numeric",
                year: "numeric",
              })}
            </div>
          ) : (
            <button className="day-header-back" onClick={() => setSelectedDay(todayKey())}>
              Back to today
            </button>
          )}
        </div>
        <button onClick={() => setSelectedDay(shiftDayKey(selectedDay, 1))} aria-label="Next day">
          <ChevronRightIcon />
        </button>
      </div>

      <GoalCard
        title="Calories"
        unit="kcal"
        consumed={totals.calories}
        minimum={settings.calorieMinimum}
        remainingText={(r) => `${Format.kcal(r)} kcal remaining`}
        reachedText="Calorie goal reached"
        valueText={`${Format.kcal(totals.calories)} / ${settings.calorieMinimum}`}
      />

      <GoalCard
        title="Protein"
        unit="g"
        consumed={totals.protein}
        minimum={settings.proteinMinimum}
        remainingText={(r) => `${Format.macroGrams(r)} g remaining`}
        reachedText="Protein goal reached"
        valueText={`${Format.macroGrams(totals.protein)} / ${settings.proteinMinimum} g`}
      />

      <div className="card macro-row">
        <MacroStat label="Carbs" value={`${Format.macroGrams(totals.carbs)} g`} />
        <div className="macro-divider" />
        <MacroStat label="Fat" value={`${Format.macroGrams(totals.fat)} g`} />
      </div>

      <WaterStrip dayKey={selectedDay} totalML={totalML(dayWater)} />

      <SupplementSummaryCard
        supplements={activeSupplements}
        logs={supplementLogs}
        dayKey={selectedDay}
      />

      <DiarySection
        entries={dayEntries}
        onAdd={(meal) => setAddFoodMeal(meal)}
        onEdit={(entry) => setEditingEntry(entry)}
        onDelete={(entry) => void repo.deleteEntry(entry.id)}
      />

      <button
        className="fab"
        onClick={() => setAddFoodMeal(suggestedMeal())}
        aria-label={`Add food to ${dayKeyDisplayName(selectedDay)}`}
      >
        <PlusIcon size={16} /> Add Food
      </button>

      {addFoodMeal && (
        <Sheet title="Add Food" onClose={() => setAddFoodMeal(null)}>
          <FoodCatalog
            dayKey={selectedDay}
            initialMeal={addFoodMeal}
            onLogged={() => setAddFoodMeal(null)}
          />
        </Sheet>
      )}

      {editingEntry && (
        <LogFoodSheet
          pending={pendingFromEntry(editingEntry)}
          dayKey={editingEntry.dayKey}
          editingEntry={editingEntry}
          onClose={() => setEditingEntry(null)}
        />
      )}

      {showWeighIn && <AddWeightSheet onClose={() => setShowWeighIn(false)} />}
    </div>
  );
}
