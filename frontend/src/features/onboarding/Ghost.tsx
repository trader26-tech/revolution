import { motion } from "framer-motion";

/** The friendly iridescent "ghost" mascot used on the stat / reveal screens.
 *  A soft blob with two eyes, gently bobbing and breathing. Original artwork. */
export function Ghost({ size = 120 }: { size?: number }) {
  return (
    <motion.div
      style={{ width: size, height: size }}
      animate={{ y: [0, -10, 0] }}
      transition={{ duration: 4, ease: "easeInOut", repeat: Infinity }}
      aria-hidden
    >
      <motion.svg
        viewBox="0 0 120 120"
        width={size}
        height={size}
        animate={{ scale: [1, 1.04, 1] }}
        transition={{ duration: 5, ease: "easeInOut", repeat: Infinity }}
      >
        <defs>
          <radialGradient id="ghost-body" cx="38%" cy="32%" r="80%">
            <stop offset="0%" stopColor="#ffffff" />
            <stop offset="42%" stopColor="#dcd6ff" />
            <stop offset="70%" stopColor="#9fd8ff" />
            <stop offset="100%" stopColor="#b6a7ff" />
          </radialGradient>
          <filter id="ghost-glow" x="-60%" y="-60%" width="220%" height="220%">
            <feGaussianBlur stdDeviation="10" result="b" />
            <feMerge>
              <feMergeNode in="b" />
              <feMergeNode in="SourceGraphic" />
            </feMerge>
          </filter>
        </defs>

        {/* soft aura */}
        <ellipse cx="60" cy="62" rx="40" ry="40" fill="#a9c6ff" opacity="0.22" filter="url(#ghost-glow)" />

        {/* body — a rounded blob with a slightly wavy bottom */}
        <path
          d="M60 18
             C82 18 96 34 96 58
             C96 74 96 84 90 92
             C86 97 82 92 78 96
             C74 100 70 96 66 99
             C62 102 58 102 54 99
             C50 96 46 100 42 96
             C38 92 34 97 30 92
             C24 84 24 74 24 58
             C24 34 38 18 60 18 Z"
          fill="url(#ghost-body)"
        />

        {/* eyes */}
        <ellipse cx="49" cy="56" rx="5" ry="7.5" fill="#1a1030" />
        <ellipse cx="71" cy="56" rx="5" ry="7.5" fill="#1a1030" />
        {/* tiny catch-lights */}
        <circle cx="47.6" cy="53" r="1.5" fill="#fff" />
        <circle cx="69.6" cy="53" r="1.5" fill="#fff" />
      </motion.svg>
    </motion.div>
  );
}
