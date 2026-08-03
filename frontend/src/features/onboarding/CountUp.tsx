import { useEffect, useState } from "react";

interface Props {
  to: number;
  /** milliseconds for the whole count */
  duration?: number;
  format: (n: number) => string;
}

/** Animates a number from 0 → `to` with an ease-out curve. Used for the
 *  headline figures so they land with a satisfying tick-up. */
export function CountUp({ to, duration = 1000, format }: Props) {
  const [value, setValue] = useState(0);

  useEffect(() => {
    let raf = 0;
    let start: number | null = null;
    const tick = (t: number) => {
      if (start === null) start = t;
      const p = Math.min((t - start) / duration, 1);
      // ease-out cubic
      const eased = 1 - Math.pow(1 - p, 3);
      setValue(to * eased);
      if (p < 1) raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [to, duration]);

  return <span className="tabnum">{format(value)}</span>;
}
