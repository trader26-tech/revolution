import { chromium } from "playwright";
const OUT = "/private/tmp/claude-501/-Users-ranjeev-Documents-projects-revolution/6d98e278-2adc-4734-8ea3-20dc75661780/scratchpad";
const b = await chromium.launch();
const p = await b.newPage({ viewport: { width: 402, height: 874 }, deviceScaleFactor: 2 });
const errs = [];
p.on("console", (m) => m.type() === "error" && errs.push(m.text()));
p.on("pageerror", (e) => errs.push(String(e)));

await p.goto("http://localhost:5173/", { waitUntil: "domcontentloaded" });
await p.waitForSelector(".orbit-hero", { timeout: 15000 });
await p.waitForTimeout(2500);
await p.screenshot({ path: OUT + "/v2-home.png" });

// close-up of the planet + orbit
const hero = await p.$(".orbit-hero");
if (hero) await hero.screenshot({ path: OUT + "/v2-hero.png" });

console.log("ERRORS:", errs.length ? errs.slice(0, 5) : "none");
await b.close();
