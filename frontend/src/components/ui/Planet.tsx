import type { Flow } from "@/lib/types";

/** The Revolution planet mark — an original recreation of the Orbit look:
 *  a purple gradient sphere with glossy 3D orbit bands, a soft-lit moon,
 *  a pink/orange crescent world, a dusting of stars, specular sheen and rim light.
 *
 *  `flow` tints the light striking the planet: income catches a soft green
 *  highlight, expense a soft red one. Everything else stays identical, so the
 *  silhouette reads the same across the app.
 */
export function Planet({
  size = 44,
  glow = false,
  flow,
  seed = 0,
}: {
  size?: number;
  glow?: boolean;
  flow?: Flow;
  seed?: number;
}) {
  // unique gradient ids so multiple planets can coexist on one page
  const id = `pl${size}-${flow ?? "n"}-${seed}`;

  const light =
    flow === "income"
      ? { key: "#8affc4", mid: "#31d68f", glowRGBA: "55,224,166" }
      : flow === "expense"
      ? { key: "#ffb3c1", mid: "#ff5f7e", glowRGBA: "255,77,109" }
      : { key: "#ffffff", mid: "#c9a6ff", glowRGBA: "138,28,255" };

  const dropShadow = glow
    ? `drop-shadow(0 ${size * 0.14}px ${size * 0.42}px rgba(${light.glowRGBA},0.45))`
    : undefined;

  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 100 100"
      style={{ display: "block", filter: dropShadow, overflow: "visible" }}
      aria-hidden
    >
      <defs>
        {/* sphere body: lit from upper-left, falling to deep purple shadow */}
        <radialGradient id={`${id}-body`} cx="34%" cy="26%" r="92%">
          <stop offset="0%" stopColor="#b478ff" />
          <stop offset="30%" stopColor="#8b3ceb" />
          <stop offset="62%" stopColor="#6a17cf" />
          <stop offset="100%" stopColor="#33076e" />
        </radialGradient>

        {/* flow-coloured key light where the sun strikes the planet */}
        <radialGradient id={`${id}-key`} cx="30%" cy="22%" r="50%">
          <stop offset="0%" stopColor={light.key} stopOpacity={flow ? 0.55 : 0.34} />
          <stop offset="45%" stopColor={light.mid} stopOpacity={flow ? 0.2 : 0.1} />
          <stop offset="100%" stopColor={light.mid} stopOpacity="0" />
        </radialGradient>

        {/* cool bounce light on the shadow side for depth */}
        <radialGradient id={`${id}-bounce`} cx="78%" cy="82%" r="46%">
          <stop offset="0%" stopColor="#ff5fa8" stopOpacity="0.22" />
          <stop offset="100%" stopColor="#ff5fa8" stopOpacity="0" />
        </radialGradient>

        {/* terminator shading — darkens the lower-right limb */}
        <radialGradient id={`${id}-shade`} cx="32%" cy="24%" r="86%">
          <stop offset="55%" stopColor="#000000" stopOpacity="0" />
          <stop offset="100%" stopColor="#12002e" stopOpacity="0.62" />
        </radialGradient>

        {/* glossy band: bright top edge, saturated core, dark underside */}
        <linearGradient id={`${id}-band`} x1="0" y1="0" x2="0.25" y2="1">
          <stop offset="0%" stopColor="#f3d9ff" />
          <stop offset="28%" stopColor="#d89bff" />
          <stop offset="70%" stopColor="#a855f7" />
          <stop offset="100%" stopColor="#7215c7" />
        </linearGradient>

        {/* crescent world, bottom-left */}
        <linearGradient id={`${id}-hot`} x1="0.1" y1="0" x2="0.9" y2="1">
          <stop offset="0%" stopColor="#ff2d78" />
          <stop offset="55%" stopColor="#ff4f52" />
          <stop offset="100%" stopColor="#ff8a2b" />
        </linearGradient>

        <radialGradient id={`${id}-moon`} cx="34%" cy="28%" r="78%">
          <stop offset="0%" stopColor="#ffffff" />
          <stop offset="62%" stopColor="#f3ecff" />
          <stop offset="100%" stopColor="#cdbaf0" />
        </radialGradient>

        {/* specular sheen across the top-left */}
        <linearGradient id={`${id}-sheen`} x1="0" y1="0" x2="0.7" y2="1">
          <stop offset="0%" stopColor="#ffffff" stopOpacity="0.4" />
          <stop offset="45%" stopColor="#ffffff" stopOpacity="0.07" />
          <stop offset="100%" stopColor="#ffffff" stopOpacity="0" />
        </linearGradient>

        <clipPath id={`${id}-clip`}>
          <circle cx="50" cy="50" r="48" />
        </clipPath>
      </defs>

      {/* ---- sphere ---- */}
      <circle cx="50" cy="50" r="48" fill={`url(#${id}-body)`} />

      <g clipPath={`url(#${id}-clip)`}>
        {/* star field, layered for depth */}
        {STARS.map(([x, y, r, o], i) => (
          <circle key={i} cx={x} cy={y} r={r} fill="#ffffff" opacity={o} />
        ))}

        {/* glossy orbit bands — drawn as tapered strokes with a highlight pass */}
        <g fill="none" strokeLinecap="round">
          {BANDS.map(([d, w], i) => (
            <g key={i}>
              <path d={d} stroke={`url(#${id}-band)`} strokeWidth={w} />
              {/* top-edge highlight gives the band its 3D roll */}
              <path
                d={d}
                stroke="#ffffff"
                strokeWidth={w * 0.24}
                opacity="0.5"
                transform={`translate(0,${-w * 0.3})`}
              />
              {/* dark underside */}
              <path
                d={d}
                stroke="#4a0b93"
                strokeWidth={w * 0.22}
                opacity="0.45"
                transform={`translate(0,${w * 0.34})`}
              />
            </g>
          ))}
        </g>

        {/* crescent world with its own shading */}
        <circle cx="6" cy="88" r="35" fill={`url(#${id}-hot)`} />
        <circle cx="6" cy="88" r="35" fill="#3a0060" opacity="0.16" />

        {/* moon: body, contact shadow, tiny terminator */}
        <ellipse cx="71" cy="33" rx="13.6" ry="13.2" fill="#2a0a5e" opacity="0.4" />
        <circle cx="70" cy="31" r="13" fill={`url(#${id}-moon)`} />
        <circle cx="70" cy="31" r="13" fill={`url(#${id}-shade)`} opacity="0.5" />

        {/* lighting passes, above surface detail */}
        <circle cx="50" cy="50" r="48" fill={`url(#${id}-bounce)`} />
        <circle cx="50" cy="50" r="48" fill={`url(#${id}-key)`} />
        <circle cx="50" cy="50" r="48" fill={`url(#${id}-shade)`} />

        {/* specular sheen */}
        <ellipse
          cx="34"
          cy="26"
          rx="34"
          ry="26"
          transform="rotate(-28 34 26)"
          fill={`url(#${id}-sheen)`}
        />
      </g>

      {/* rim light picks up the flow colour */}
      <circle
        cx="50"
        cy="50"
        r="47.4"
        fill="none"
        stroke={light.key}
        strokeWidth="1.1"
        opacity={flow ? 0.5 : 0.28}
      />
      <circle
        cx="50"
        cy="50"
        r="47.8"
        fill="none"
        stroke="rgba(255,255,255,0.16)"
        strokeWidth="0.8"
      />
    </svg>
  );
}

/** Orbit bands: [path, strokeWidth] — sweeping arcs matching the Orbit mark. */
const BANDS: [string, number][] = [
  ["M20 10 C 44 21, 63 35, 95 70", 5.4],
  ["M4 39 C 30 52, 47 68, 76 104", 6.6],
  ["M74 45 C 83 54, 90 66, 99 86", 5],
];

/** [cx, cy, r, opacity] — varied sizes read as depth. */
const STARS: [number, number, number, number][] = [
  [30, 20, 1.1, 0.55], [58, 15, 1.4, 0.45], [80, 44, 1.1, 0.5], [66, 60, 1.6, 0.5],
  [44, 40, 1.0, 0.4], [24, 62, 1.1, 0.4], [86, 74, 1.4, 0.45], [38, 78, 1.0, 0.38],
  [54, 70, 1.0, 0.32], [72, 84, 1.2, 0.42], [18, 34, 1.0, 0.4], [90, 26, 1.1, 0.38],
  [48, 28, 0.8, 0.3], [62, 44, 0.8, 0.28], [34, 52, 0.9, 0.3], [78, 58, 0.8, 0.3],
  [26, 46, 0.7, 0.26], [56, 88, 0.9, 0.3], [88, 52, 0.8, 0.28], [42, 64, 0.7, 0.26],
];
