/* Progress tab: understandable stats, not a dashboard. Range-filtered
   calorie/protein charts with goal lines, goal-hit percentages, streaks,
   weight trend, and deterministic insights. */

import { useState } from "react";
import { useQuery } from "../../db/hooks";
import { repo } from "../../db/repo";
import { useSettings } from "../../db/settings";
import {
  averageCalories,
  averageProtein,
  daySummaries,
  percentageOfDays,
  streaks,
  type DaySummary,
} from "../../logic/dailyStats";
import { insights as computeInsights } from "../../logic/insights";
import { trendPoints } from "../../logic/weightTrend";
import { dayKeyOf, shiftDayKey, todayKey } from "../../models/dayKey";
import { Format } from "../../support/format";
import { DailyBarChart } from "../../components/charts";
import WeightTrendCard from "./WeightTrendCard";
import AddWeightSheet from "./AddWeightSheet";

const RANGES = [
  { id: "7D", days: 7 },
  { id: "30D", days: 30 },
  { id: "90D", days: 90 },
  { id: "All", days: null },
] as const;

export default function ProgressScreen() {
  const settings = useSettings();
  const [rangeId, setRangeId] = useState<(typeof RANGES)[number]["id"]>("7D");
  const [showWeighIn, setShowWeighIn] = useState(false);

  const allEntries = useQuery(() => repo.allEntries(), []) ?? [];
  const allWeights = useQuery(() => repo.allWeights(), []) ?? [];

  const range = RANGES.find((r) => r.id === rangeId)!;
  const rangeStart = range.days ? shiftDayKey(todayKey(), -(range.days - 1)) : null;

  const allSummaries = daySummaries(allEntries);
  const summaries = rangeStart ? allSummaries.filter((s) => s.dayKey >= rangeStart) : allSummaries;
  const rangeWeights = rangeStart
    ? allWeights.filter((w) => dayKeyOf(new Date(w.date)) >= rangeStart)
    : allWeights;

  const insightLines = computeInsights(
    allSummaries,
    trendPoints(allWeights),
    settings.calorieMinimum,
    settings.proteinMinimum,
    settings.weightUnit,
  );

  const isEmpty = summaries.length === 0 && allWeights.length === 0;

  return (
    <div className="screen">
      <h1 className="screen-title">Progress</h1>

      <div className="segmented">
        {RANGES.map((r) => (
          <button
            key={r.id}
            className={r.id === rangeId ? "selected" : ""}
            onClick={() => setRangeId(r.id)}
          >
            {r.id}
          </button>
        ))}
      </div>

      {isEmpty ? (
        <div className="card diary-empty">
          <div className="diary-empty-title">No data yet</div>
          <div className="text-tertiary">
            Log foods and weigh-ins for a few days and your trends will appear here.
          </div>
        </div>
      ) : (
        <>
          {insightLines.length > 0 && (
            <div className="card insights-card">
              {insightLines.map((line) => (
                <div key={line} className="insight-line">
                  💡 {line}
                </div>
              ))}
            </div>
          )}

          <ChartCard
            title="Calories"
            unit="kcal"
            minimum={settings.calorieMinimum}
            summaries={summaries}
            value={(s) => s.calories}
          />
          <ChartCard
            title="Protein"
            unit="g"
            minimum={settings.proteinMinimum}
            summaries={summaries}
            value={(s) => s.protein}
          />

          <StatsGrid summaries={summaries} allSummaries={allSummaries} />

          <WeightTrendCard
            weights={rangeWeights}
            allWeights={allWeights}
            onAddWeight={() => setShowWeighIn(true)}
          />
        </>
      )}

      {showWeighIn && <AddWeightSheet onClose={() => setShowWeighIn(false)} />}
    </div>
  );
}

function ChartCard({
  title,
  unit,
  minimum,
  summaries,
  value,
}: {
  title: string;
  unit: string;
  minimum: number;
  summaries: DaySummary[];
  value: (s: DaySummary) => number;
}) {
  return (
    <div className="card form-card">
      <div className="row">
        <span className="goal-card-title">{title}</span>
        <span className="spacer" />
        <span className="text-tertiary chart-goal-label">
          goal ≥ {Math.round(minimum)} {unit}
        </span>
      </div>
      {summaries.length === 0 ? (
        <div className="text-tertiary">No logged days in this range.</div>
      ) : (
        <DailyBarChart
          points={summaries.map((s) => ({
            dayKey: s.dayKey,
            value: value(s),
            hit: value(s) >= minimum,
          }))}
          minimum={minimum}
        />
      )}
    </div>
  );
}

function StatsGrid({
  summaries,
  allSummaries,
}: {
  summaries: DaySummary[];
  allSummaries: DaySummary[];
}) {
  const settings = useSettings();
  const caloriePct = percentageOfDays(summaries, (s) => s.calories >= settings.calorieMinimum);
  const proteinPct = percentageOfDays(summaries, (s) => s.protein >= settings.proteinMinimum);
  const streak = streaks(allSummaries, settings.calorieMinimum, settings.proteinMinimum);

  const tiles = [
    { title: "Calorie goal hit", value: `${Math.round(caloriePct)}%`, sub: "of logged days" },
    { title: "Protein goal hit", value: `${Math.round(proteinPct)}%`, sub: "of logged days" },
    { title: "Avg calories", value: Format.kcal(averageCalories(summaries)), sub: "kcal per day" },
    { title: "Avg protein", value: Format.macroGrams(averageProtein(summaries)), sub: "g per day" },
    {
      title: "Current streak",
      value: String(streak.current),
      sub: streak.current === 1 ? "day, both goals" : "days, both goals",
    },
    {
      title: "Longest streak",
      value: String(streak.longest),
      sub: streak.longest === 1 ? "day, both goals" : "days, both goals",
    },
  ];

  return (
    <section>
      <div className="section-header">{summaries.length} logged days</div>
      <div className="stats-grid">
        {tiles.map((t) => (
          <div key={t.title} className="card stat-tile">
            <div className="stat-tile-title">{t.title}</div>
            <div className="stat-tile-value">{t.value}</div>
            <div className="stat-tile-sub">{t.sub}</div>
          </div>
        ))}
      </div>
    </section>
  );
}
