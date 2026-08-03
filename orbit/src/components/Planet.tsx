/** The Orbit "planet" mark, recreated as original SVG:
 *  a purple gradient sphere with orbit-ring stripes, a white moon,
 *  a pink/orange crescent, and a dusting of stars. */
export function Planet({ size = 44, glow = false }: { size?: number; glow?: boolean }) {
  const id = "p" + size;
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 100 100"
      style={{
        display: "block",
        filter: glow ? "drop-shadow(0 8px 26px rgba(138,28,255,0.6))" : undefined,
      }}
      aria-hidden
    >
      <defs>
        <radialGradient id={`${id}-body`} cx="38%" cy="30%" r="85%">
          <stop offset="0%" stopColor="#a855ff" />
          <stop offset="45%" stopColor="#7c1fe0" />
          <stop offset="100%" stopColor="#4b0f9e" />
        </radialGradient>
        <linearGradient id={`${id}-hot`} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stopColor="#ff2d78" />
          <stop offset="100%" stopColor="#ff6a2b" />
        </linearGradient>
        <radialGradient id={`${id}-moon`} cx="35%" cy="30%" r="75%">
          <stop offset="0%" stopColor="#ffffff" />
          <stop offset="100%" stopColor="#e6ddff" />
        </radialGradient>
        <clipPath id={`${id}-clip`}>
          <circle cx="50" cy="50" r="48" />
        </clipPath>
      </defs>

      <circle cx="50" cy="50" r="48" fill={`url(#${id}-body)`} />

      <g clipPath={`url(#${id}-clip)`}>
        {/* stars */}
        {STARS.map((s, i) => (
          <circle key={i} cx={s[0]} cy={s[1]} r={s[2]} fill="#ffffff" opacity={s[3]} />
        ))}
        {/* orbit-ring stripes */}
        <g stroke="#c77bff" fill="none" strokeLinecap="round" opacity="0.95">
          <path d="M22 12 C 45 22, 62 34, 92 66" strokeWidth="5" opacity="0.85" />
          <path d="M6 40 C 30 52, 46 66, 74 100" strokeWidth="6" />
          <path d="M74 46 C 82 54, 88 64, 96 82" strokeWidth="5" opacity="0.8" />
        </g>
        {/* pink/orange crescent planet, bottom-left */}
        <circle cx="8" cy="86" r="34" fill={`url(#${id}-hot)`} />
        {/* white moon */}
        <circle cx="70" cy="30" r="13" fill={`url(#${id}-moon)`} />
      </g>

      <circle
        cx="50"
        cy="50"
        r="47.5"
        fill="none"
        stroke="rgba(255,255,255,0.18)"
        strokeWidth="1"
      />
    </svg>
  );
}

const STARS: [number, number, number, number][] = [
  [30, 20, 1, 0.5], [58, 16, 1.2, 0.4], [80, 44, 1, 0.5], [66, 60, 1.4, 0.55],
  [44, 40, 1, 0.4], [24, 62, 1, 0.4], [86, 74, 1.3, 0.5], [38, 78, 1, 0.4],
  [54, 70, 1, 0.35], [72, 84, 1.1, 0.45], [18, 34, 1, 0.4], [90, 26, 1, 0.4],
];
