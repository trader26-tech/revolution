import "./panda.css";

/**
 * Pip — a cartoon panda that looks genuinely busy taking notes.
 *
 * It's all inline SVG so it stays razor-sharp at any size, and every bit of
 * life is a pure CSS animation (see panda.css) so there's zero JS cost:
 *   • the whole panda bobs and breathes,
 *   • ears give the occasional twitch,
 *   • eyes blink on their own timer,
 *   • the writing paw + pencil scribble left→right in little strokes,
 *   • ink "lines" appear on the pad in time with the scribble (clip-path wipe),
 *   • a cheek-blush + tongue-tip poke give it that focused, happy look.
 *
 * `size` scales the whole thing; the art is authored in a 240×240 viewBox.
 */
export function PandaMascot({ size = 240 }: { size?: number }) {
  return (
    <div
      className="panda"
      style={{ width: size, height: size }}
      role="img"
      aria-label="A cartoon panda happily writing notes"
    >
      <svg viewBox="0 0 240 240" className="panda__svg" aria-hidden>
        <defs>
          <radialGradient id="pandaShadow" cx="50%" cy="50%" r="50%">
            <stop offset="0%" stopColor="rgba(0,0,0,0.35)" />
            <stop offset="100%" stopColor="rgba(0,0,0,0)" />
          </radialGradient>
          <linearGradient id="pandaBody" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="#ffffff" />
            <stop offset="100%" stopColor="#e9e6f5" />
          </linearGradient>
          <linearGradient id="padPaper" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="#fffdf5" />
            <stop offset="100%" stopColor="#fdefc9" />
          </linearGradient>
          <linearGradient id="pencilBody" x1="0" y1="0" x2="1" y2="0">
            <stop offset="0%" stopColor="#ffcf5c" />
            <stop offset="100%" stopColor="#ffb020" />
          </linearGradient>
        </defs>

        {/* ground shadow — squishes as the panda bobs */}
        <ellipse className="panda__shadow" cx="120" cy="214" rx="66" ry="12" fill="url(#pandaShadow)" />

        {/* everything that bobs together */}
        <g className="panda__bob">
          {/* ---- ears ---- */}
          <g className="panda__ear panda__ear--l">
            <circle cx="70" cy="58" r="24" fill="#2b2540" />
            <circle cx="70" cy="58" r="12" fill="#3a3357" />
          </g>
          <g className="panda__ear panda__ear--r">
            <circle cx="170" cy="58" r="24" fill="#2b2540" />
            <circle cx="170" cy="58" r="12" fill="#3a3357" />
          </g>

          {/* ---- head ---- */}
          <circle cx="120" cy="96" r="62" fill="url(#pandaBody)" />
          <ellipse cx="120" cy="100" rx="58" ry="56" fill="#ffffff" opacity="0.6" />

          {/* eye patches */}
          <ellipse className="panda__patch" cx="96" cy="98" rx="20" ry="26" fill="#2b2540" transform="rotate(-14 96 98)" />
          <ellipse className="panda__patch" cx="144" cy="98" rx="20" ry="26" fill="#2b2540" transform="rotate(14 144 98)" />

          {/* eyes (blink by scaling Y) */}
          <g className="panda__eyes">
            <g className="panda__eye">
              <circle cx="99" cy="100" r="9" fill="#1b1730" />
              <circle cx="102" cy="97" r="3" fill="#fff" />
            </g>
            <g className="panda__eye">
              <circle cx="141" cy="100" r="9" fill="#1b1730" />
              <circle cx="144" cy="97" r="3" fill="#fff" />
            </g>
          </g>

          {/* cheek blush */}
          <ellipse cx="82" cy="120" rx="9" ry="6" fill="#ff9db0" opacity="0.65" />
          <ellipse cx="158" cy="120" rx="9" ry="6" fill="#ff9db0" opacity="0.65" />

          {/* nose + happy mouth + tongue tip */}
          <ellipse cx="120" cy="120" rx="8" ry="6" fill="#1b1730" />
          <path d="M120 126 v6" stroke="#1b1730" strokeWidth="3" strokeLinecap="round" />
          <path
            className="panda__smile"
            d="M108 134 q12 12 24 0"
            fill="none"
            stroke="#1b1730"
            strokeWidth="3.4"
            strokeLinecap="round"
          />
          <path className="panda__tongue" d="M117 137 q3 5 6 0 z" fill="#ff7a94" />

          {/* ---- body ---- */}
          <path
            d="M78 150 q42 -20 84 0 q16 34 4 58 q-46 16 -92 0 q-12 -24 4 -58 Z"
            fill="url(#pandaBody)"
          />
          {/* belly patch */}
          <ellipse cx="120" cy="190" rx="30" ry="26" fill="#f3f0fb" />

          {/* left arm holding the pad steady */}
          <path className="panda__arm-l" d="M84 168 q-18 10 -14 34 q10 8 24 2" fill="#2b2540" />

          {/* ---- the notepad ---- */}
          <g className="panda__pad">
            <rect x="118" y="150" width="86" height="66" rx="9" fill="#2b2540" transform="rotate(8 161 183)" />
            <rect x="122" y="150" width="80" height="60" rx="7" fill="url(#padPaper)" transform="rotate(8 161 183)" />
            {/* spiral binding dots */}
            <g transform="rotate(8 161 183)">
              <circle cx="132" cy="150" r="2.4" fill="#8a1cff" />
              <circle cx="148" cy="149" r="2.4" fill="#8a1cff" />
              <circle cx="164" cy="147" r="2.4" fill="#8a1cff" />
              <circle cx="180" cy="146" r="2.4" fill="#8a1cff" />
              <circle cx="196" cy="145" r="2.4" fill="#8a1cff" />

              {/* the "written" ink lines — each wipes in on a loop */}
              <g stroke="#6b5bd6" strokeWidth="3" strokeLinecap="round" className="panda__ink">
                <line className="panda__line panda__line--1" x1="132" y1="163" x2="192" y2="161" />
                <line className="panda__line panda__line--2" x1="132" y1="174" x2="196" y2="172" />
                <line className="panda__line panda__line--3" x1="132" y1="185" x2="184" y2="183" />
                <line className="panda__line panda__line--4" x1="132" y1="196" x2="176" y2="194" />
              </g>
            </g>
          </g>

          {/* ---- writing paw + pencil (scribbles) ---- */}
          <g className="panda__write">
            {/* paw */}
            <ellipse cx="170" cy="196" rx="15" ry="12" fill="#2b2540" transform="rotate(20 170 196)" />
            {/* pencil */}
            <g transform="rotate(46 176 190)">
              <rect x="172" y="150" width="9" height="44" rx="3" fill="url(#pencilBody)" />
              <rect x="172" y="150" width="9" height="8" rx="3" fill="#ff6a2b" />
              <path d="M172 194 h9 l-4.5 10 Z" fill="#f3d6a0" />
              <path d="M174.5 200 h4 l-2 4 Z" fill="#1b1730" />
            </g>
          </g>
        </g>
      </svg>
    </div>
  );
}
