/* Hand-authored logo paths for popular brands that simple-icons has removed
 * (trademark policy) — so the app still shows a real, recognisable mark for the
 * services users add most. Each `path` is a single glyph in a 0 0 24 24 viewBox,
 * rendered in white on the brand `hex`. Simplified but on-brand (not the exact
 * registered logo), which keeps them legally safe while reading correctly.
 *
 * Slugs here are namespaced with `x-` so they never collide with simple-icons.
 */
export const SUPPLEMENT = [
  // Disney+ — the stylised "D+" is trademarked; use a clean plus-in-circle.
  { name: "Disney+", category: "Streaming", slug: "x-disneyplus", hex: "#0E47B8",
    path: "M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm1 6v3h3v2h-3v3h-2v-3H8v-2h3V8h2z" },
  // Hulu — bold rounded wordmark reduced to an "h".
  { name: "Hulu", category: "Streaming", slug: "x-hulu", hex: "#1CE783",
    path: "M6 5h2.4v5.1c.5-.6 1.3-1 2.3-1 2 0 3.3 1.3 3.3 3.4V19h-2.4v-6c0-1-.6-1.6-1.5-1.6S8.4 12 8.4 13v6H6V5zm11.6 4.3H20V19h-2.4v-.7c-.5.6-1.3 1-2.3 1-2 0-3.3-1.3-3.3-3.4V9.3h2.4v6c0 1 .6 1.6 1.5 1.6s1.5-.6 1.5-1.6V9.3z" },
  // Prime Video — a play triangle inside a smile-swoosh.
  { name: "Prime Video", category: "Streaming", slug: "x-primevideo", hex: "#00A8E1",
    path: "M10 8.5v7l6-3.5-6-3.5zM3 16.5c5.4 3 12 3 17.4.2l.6 1c-6 3.3-13.4 3.2-19-.2l1-1z" },
  // Xbox — the sphere with crossed arcs, reduced to an "X" in a circle.
  { name: "Xbox", category: "Gaming", slug: "x-xbox", hex: "#107C10",
    path: "M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zM8 6.2c1.2-.8 2.5-1.2 4-1.2s2.8.4 4 1.2C14.8 7.6 13.4 9.3 12 11 10.6 9.3 9.2 7.6 8 6.2zM6.2 8C7.6 9.2 9.3 10.6 11 12c-1.7 1.4-3.4 3.1-4.8 4.5A8 8 0 0 1 6.2 8zm11.6 0a8 8 0 0 1-.4 8.5C16 15 14.3 13.4 12.9 12c1.7-1.4 3.4-2.8 4.9-4z" },
  // Adobe — the classic "A" stylised as a triangle.
  { name: "Adobe", category: "Productivity", slug: "x-adobe", hex: "#FF0000",
    path: "M3 3h6.2L21 21h-4.6l-1.7-4.2H9.9L12 12l1.8 4.4-2.9-7L6.6 21H3L3 3z" },
  // Microsoft — the four squares.
  { name: "Microsoft", category: "Productivity", slug: "x-microsoft", hex: "#5E5E5E",
    path: "M3 3h8.5v8.5H3V3zm9.5 0H21v8.5h-8.5V3zM3 12.5h8.5V21H3v-8.5zm9.5 0H21V21h-8.5v-8.5z" },
  // ChatGPT — a stylised six-spoke knot, reduced to a hexagon ring.
  { name: "ChatGPT", category: "AI", slug: "x-chatgpt", hex: "#10A37F",
    path: "M12 2 4 6.5v9L12 20l8-4.5v-9L12 2zm0 2.3 5.5 3.1v6.2L12 16.7l-5.5-3.1V7.4L12 4.3zm0 3.2a2.5 2.5 0 1 0 0 5 2.5 2.5 0 0 0 0-5z" },
  // Amazon (Prime) — the smile arrow under an "a".
  { name: "Amazon Prime", category: "Streaming", slug: "x-amazonprime", hex: "#FF9900",
    path: "M4 15.5c4.7 3 11.3 3 16-.2l.7 1c-5.2 3.4-12.3 3.4-17.5.1l.8-.9zM12 5c2.2 0 3.6 1 3.6 3v3.3c0 .5.2.9.5 1.2l-1.4 1c-.3-.3-.5-.6-.7-1-.7.7-1.6 1.1-2.8 1.1-1.7 0-2.9-1-2.9-2.6 0-1.8 1.4-2.7 3.6-2.7h1.4V9c0-.9-.5-1.3-1.5-1.3-.9 0-1.6.4-1.9 1.2l-1.7-.5C9.1 5.9 10.3 5 12 5zm.9 4.9c-1.3 0-2 .4-2 1.3 0 .7.5 1.1 1.3 1.1 1 0 1.7-.6 1.7-1.6v-.8h-1z" },
  // LinkedIn — the "in" block.
  { name: "LinkedIn", category: "Other", slug: "x-linkedin", hex: "#0A66C2",
    path: "M4.5 3.5a2 2 0 1 1 0 4 2 2 0 0 1 0-4zM3 9h3v12H3V9zm5 0h2.9v1.6h.05c.4-.75 1.4-1.6 2.95-1.6 3.15 0 3.7 2 3.7 4.7V21h-3v-5.6c0-1.35-.02-3.1-1.9-3.1-1.9 0-2.2 1.5-2.2 3v5.7H8V9z" },
  // Nintendo Switch — the two joy-con halves.
  { name: "Nintendo Switch", category: "Gaming", slug: "x-nintendoswitch", hex: "#E60012",
    path: "M10.5 3H8a5 5 0 0 0-5 5v8a5 5 0 0 0 5 5h2.5V3zM8 5h.5v14H8a3 3 0 0 1-3-3V8a3 3 0 0 1 3-3zm-.5 2.5A1.5 1.5 0 1 0 7.5 10a1.5 1.5 0 0 0 0-2.5zM16 3h-2.5v18H16a5 5 0 0 0 5-5V8a5 5 0 0 0-5-5zm.5 6.5a1.5 1.5 0 1 1 0 3 1.5 1.5 0 0 1 0-3z" },
  // Google One — the four-colour "G" simplified to a ring gap.
  { name: "Google One", category: "Cloud", slug: "x-googleone", hex: "#4285F4",
    path: "M12 4a8 8 0 1 0 7.4 5H12v3h4.9A5 5 0 1 1 12 7c1.2 0 2.3.4 3.2 1.1l2.1-2.1A8 8 0 0 0 12 4z" },
];
