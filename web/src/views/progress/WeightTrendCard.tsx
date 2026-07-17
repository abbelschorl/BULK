/* Weight chart: individual weigh-ins as points, 7-day moving average as a
   line, weekly rate, and a neutral comparison to the desired rate. */

import { useSettings } from "../../db/settings";
import {
  assessTrend,
  movingAverage7,
  trendPoints,
  weeklyRateKg,
} from "../../logic/weightTrend";
import { dayKeyOf, shiftDayKey } from "../../models/dayKey";
import { weightFromKg } from "../../models/units";
import type { WeightEntry } from "../../models/types";
import { Format } from "../../support/format";
import { WeightChart } from "../../components/charts";

export default function WeightTrendCard({
  weights,
  allWeights,
  onAddWeight,
}: {
  /** Weigh-ins inside the selected range (chart). */
  weights: WeightEntry[];
  /** Full history (trend math needs data beyond the visible range edge). */
  allWeights: WeightEntry[];
  onAddWeight: () => void;
}) {
  const settings = useSettings();
  const unit = settings.weightUnit;

  const fullMA = movingAverage7(trendPoints(allWeights));
  const rangeStart = weights.length > 0 ? dayKeyOf(new Date(weights[0].date)) : null;
  const visibleMA = rangeStart ? fullMA.filter((p) => p.dayKey >= rangeStart) : [];

  // Rate over the trailing 4 weeks (or what exists) for stability.
  let weeklyRate: number | null = null;
  if (fullMA.length > 0) {
    const cutoff = shiftDayKey(fullMA[fullMA.length - 1].dayKey, -28);
    weeklyRate = weeklyRateKg(fullMA.filter((p) => p.dayKey >= cutoff));
  }

  const latest = allWeights[allWeights.length - 1];

  return (
    <section className="weight-section">
      <div className="section-header">Weight</div>
      <div className="card form-card">
        <div className="row">
          {latest && (
            <div>
              <div className="weight-latest">{Format.weight(latest.weightKg, unit)}</div>
              <div className="text-tertiary weight-latest-date">
                latest ·{" "}
                {new Date(latest.date).toLocaleDateString(undefined, {
                  day: "numeric",
                  month: "short",
                  year: "numeric",
                })}
              </div>
            </div>
          )}
          <span className="spacer" />
          <button className="pill-button" onClick={onAddWeight} aria-label="Add weigh-in">
            + Weigh in
          </button>
        </div>

        {weights.length === 0 ? (
          <div className="diary-empty">
            <div className="diary-empty-title">No weigh-ins in this range</div>
            <button className="link-button" onClick={onAddWeight}>
              Add weigh-in
            </button>
          </div>
        ) : (
          <>
            <WeightChart
              points={weights.map((w) => ({
                dayKey: dayKeyOf(new Date(w.date)),
                value: weightFromKg(w.weightKg, unit),
              }))}
              line={visibleMA.map((p) => ({ dayKey: p.dayKey, value: weightFromKg(p.kg, unit) }))}
            />
            {weeklyRate !== null && <TrendSummary rate={weeklyRate} />}
          </>
        )}
      </div>
    </section>
  );
}

function TrendSummary({ rate }: { rate: number }) {
  const settings = useSettings();
  const desired = settings.desiredWeeklyGainKg;
  const assessment = assessTrend(rate, desired);
  const description = {
    belowDesired: "below your desired rate",
    nearDesired: "near your desired rate",
    aboveDesired: "above your desired rate",
  }[assessment];

  return (
    <div>
      <div className="trend-rate">
        Trending {Format.weeklyRate(rate, settings.weightUnit)}
      </div>
      <div className="text-tertiary trend-desc">
        That's {description} of {Format.weeklyRate(desired, settings.weightUnit)}, based on the
        7-day average over the last month.
      </div>
    </div>
  );
}
