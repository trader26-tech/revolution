import { useMemo } from "react";
import { BRANDS, matchBrand } from "@/lib/brands";
import type { Brand } from "@/lib/brands";
import "./brand-logo.css";

const bySlug = new Map(BRANDS.map((b) => [b.slug, b]));

/** Resolve a subscription-ish record to its bundled brand (by stored slug,
 *  else by matching its name). Exposed so callers can pre-fill colour/slug. */
export function resolveBrand({
  brandSlug,
  name,
}: {
  brandSlug?: string;
  name?: string;
}): Brand | null {
  if (brandSlug && bySlug.has(brandSlug)) return bySlug.get(brandSlug)!;
  if (name) return matchBrand(name);
  return null;
}

/** A logo chip: the real brand SVG (white glyph on the brand colour) when a
 *  brand is known, otherwise a tinted initial on `fallbackColor`. Always a
 *  rounded square filling its box; the parent controls size and outer shape. */
export function BrandLogo({
  brandSlug,
  name,
  mark,
  fallbackColor = "#8a1cff",
  size,
  radius,
  className,
}: {
  brandSlug?: string;
  name: string;
  mark?: string;
  fallbackColor?: string;
  size: number;
  /** corner radius; defaults to a squircle-ish 28% */
  radius?: number;
  className?: string;
}) {
  const brand = useMemo(
    () => resolveBrand({ brandSlug, name }),
    [brandSlug, name]
  );
  const r = radius ?? size * 0.28;
  const bg = brand ? brand.hex : fallbackColor;
  const glyph = (mark && mark.trim()) || name.trim().charAt(0).toUpperCase();

  return (
    <div
      className={"brand-logo" + (className ? " " + className : "")}
      style={{
        width: size,
        height: size,
        borderRadius: r,
        background: bg,
      }}
    >
      {brand ? (
        <svg
          viewBox="0 0 24 24"
          width={size * 0.58}
          height={size * 0.58}
          fill="#fff"
          aria-hidden
        >
          <path d={brand.path} />
        </svg>
      ) : (
        <span
          className="brand-logo__initial"
          style={{ fontSize: size * 0.44 }}
        >
          {glyph}
        </span>
      )}
    </div>
  );
}
