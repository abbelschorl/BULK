/* Lightweight inline-SVG charts standing in for Swift Charts: daily bars with
   a dashed minimum line, and a weight scatter + moving-average line. */

import { dayKeyDiff, dayKeyToDate } from "../models/dayKey";

const W = 320;

function xLabels(dayKeys: string[], count = 4): { key: string; label: string }[] {
  if (dayKeys.length === 0) return [];
  const step = Math.max(1, Math.floor(dayKeys.length / count));
  const picked: { key: string; label: string }[] = [];
  for (let i = 0; i < dayKeys.length; i += step) {
    const d = dayKeyToDate(dayKeys[i]);
    picked.push({
      key: dayKeys[i],
      label: d.toLocaleDateString(undefined, { day: "numeric", month: "short" }),
    });
  }
  return picked;
}

/** Daily bars vs a minimum goal line. Green when the goal was hit. */
export function DailyBarChart({
  points,
  minimum,
  height = 150,
}: {
  points: { dayKey: string; value: number; hit: boolean }[];
  minimum: number;
  height?: number;
}) {
  const chartH = height - 18; // leave room for x labels
  const yMax = Math.max(minimum, ...points.map((p) => p.value)) * 1.08 || 1;
  const n = points.length;
  const slot = W / n;
  const barW = Math.min(22, Math.max(3, slot * 0.65));
  const y = (v: number) => chartH - (v / yMax) * chartH;
  const labels = xLabels(points.map((p) => p.dayKey));

  return (
    <svg viewBox={`0 0 ${W} ${height}`} className="chart" role="img">
      {points.map((p, i) => (
        <rect
          key={p.dayKey}
          x={i * slot + (slot - barW) / 2}
          y={y(p.value)}
          width={barW}
          height={Math.max(0, chartH - y(p.value))}
          rx={3}
          fill={p.hit ? "var(--goal-reached)" : "rgba(250, 115, 77, 0.75)"}
        />
      ))}
      <line
        x1={0}
        x2={W}
        y1={y(minimum)}
        y2={y(minimum)}
        stroke="rgba(255,255,255,0.62)"
        strokeWidth={1.5}
        strokeDasharray="5 4"
      />
      {labels.map(({ key, label }) => {
        const i = points.findIndex((p) => p.dayKey === key);
        return (
          <text key={key} x={i * slot + slot / 2} y={height - 4} className="chart-label" textAnchor="middle">
            {label}
          </text>
        );
      })}
    </svg>
  );
}

/** Weigh-ins as dots plus the 7-day moving average as a line. */
export function WeightChart({
  points,
  line,
  height = 170,
}: {
  points: { dayKey: string; value: number }[];
  line: { dayKey: string; value: number }[];
  height?: number;
}) {
  const chartH = height - 18;
  const all = [...points, ...line];
  if (all.length === 0) return null;

  const keys = all.map((p) => p.dayKey).sort();
  const first = keys[0];
  const last = keys[keys.length - 1];
  const span = Math.max(1, dayKeyDiff(first, last));
  const values = all.map((p) => p.value);
  const vMin = Math.min(...values);
  const vMax = Math.max(...values);
  const pad = Math.max((vMax - vMin) * 0.15, 0.5);
  const lo = vMin - pad;
  const hi = vMax + pad;

  const x = (dayKey: string) => (dayKeyDiff(first, dayKey) / span) * (W - 30) + 4;
  const y = (v: number) => chartH - ((v - lo) / (hi - lo)) * (chartH - 8) - 4;

  const path = line.map((p, i) => `${i === 0 ? "M" : "L"}${x(p.dayKey)},${y(p.value)}`).join(" ");
  const labels = xLabels([...new Set(keys)]);

  return (
    <svg viewBox={`0 0 ${W} ${height}`} className="chart" role="img">
      <text x={W - 2} y={y(vMax) + 3} className="chart-label" textAnchor="end">
        {vMax.toFixed(1)}
      </text>
      <text x={W - 2} y={y(vMin) + 3} className="chart-label" textAnchor="end">
        {vMin.toFixed(1)}
      </text>
      {points.map((p, i) => (
        <circle key={i} cx={x(p.dayKey)} cy={y(p.value)} r={2.6} fill="rgba(255,255,255,0.45)" />
      ))}
      {line.length > 1 && (
        <path d={path} fill="none" stroke="var(--accent-blue)" strokeWidth={2.5} strokeLinecap="round" strokeLinejoin="round" />
      )}
      {labels.map(({ key, label }) => (
        <text key={key} x={x(key)} y={height - 4} className="chart-label" textAnchor="middle">
          {label}
        </text>
      ))}
    </svg>
  );
}
