/* Progress primitives ported from Bulk/DesignSystem/ProgressComponents.swift. */

export function GoalProgressBar({ fraction, color }: { fraction: number; color: string }) {
  return (
    <div className="goal-bar" aria-hidden>
      <div
        className="goal-bar-fill"
        style={{ width: `${Math.max(4, fraction * 100)}%`, background: color }}
      />
    </div>
  );
}

/** Compact circular progress ring (water, supplements). */
export function MiniRing({
  fraction,
  color,
  size = 30,
  lineWidth = 4,
}: {
  fraction: number;
  color: string;
  size?: number;
  lineWidth?: number;
}) {
  const r = (size - lineWidth) / 2;
  const c = 2 * Math.PI * r;
  return (
    <svg width={size} height={size} aria-hidden style={{ flexShrink: 0 }}>
      <circle
        cx={size / 2}
        cy={size / 2}
        r={r}
        fill="none"
        stroke="rgba(255,255,255,0.1)"
        strokeWidth={lineWidth}
      />
      <circle
        cx={size / 2}
        cy={size / 2}
        r={r}
        fill="none"
        stroke={color}
        strokeWidth={lineWidth}
        strokeLinecap="round"
        strokeDasharray={c}
        strokeDashoffset={c * (1 - Math.min(Math.max(fraction, 0), 1))}
        transform={`rotate(-90 ${size / 2} ${size / 2})`}
        style={{ transition: "stroke-dashoffset 0.4s ease" }}
      />
    </svg>
  );
}

/** Quick-select gram chips (50–300 g) for fast portion entry. */
export function GramChips({
  grams,
  onSelect,
  options = [50, 100, 150, 200, 250, 300],
}: {
  grams: number;
  onSelect: (g: number) => void;
  options?: number[];
}) {
  return (
    <div className="gram-chips">
      {options.map((option) => (
        <button
          key={option}
          className={grams === option ? "selected" : ""}
          onClick={() => onSelect(option)}
          aria-label={`${option} grams`}
        >
          {option}
        </button>
      ))}
    </div>
  );
}

/** A labeled macro value used in the neutral carbs/fat row. */
export function MacroStat({ label, value }: { label: string; value: string }) {
  return (
    <div className="macro-stat">
      <div className="macro-stat-value">{value}</div>
      <div className="macro-stat-label">{label}</div>
    </div>
  );
}
