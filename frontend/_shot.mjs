import { chromium } from "playwright";
const OUT = "/private/tmp/claude-501/-Users-ranjeev-Documents-projects-revolution/6d98e278-2adc-4734-8ea3-20dc75661780/scratchpad";
const b = await chromium.launch();
const p = await b.newPage({ viewport: { width: 402, height: 874 }, deviceScaleFactor: 2 });
const errs = [];
p.on("console", (m) => m.type() === "error" && errs.push(m.text()));
p.on("pageerror", (e) => errs.push(String(e)));

// ?seed populates demo data locally and skips onboarding
await p.goto("http://localhost:5173/?seed", { waitUntil: "domcontentloaded" });
await p.waitForSelector(".sun-orbit", { timeout: 15000 });
await p.waitForTimeout(2200);
await p.screenshot({ path: OUT + "/ast-default.png" });
const orbit1 = await p.$(".sun-orbit");
if (orbit1) await orbit1.screenshot({ path: OUT + "/ast-default-hero.png" });

const bodies = await p.evaluate(() => ({
  bodies: document.querySelectorAll(".sun-orbit__body").length,
  revealedNow: document.querySelectorAll(".sun-orbit__body.is-revealed").length,
}));
console.log("BEFORE tap:", JSON.stringify(bodies));

// tap the sun -> reveal logos
await p.click(".sun-orbit__sun");
await p.waitForTimeout(1400);
await p.screenshot({ path: OUT + "/ast-revealed.png" });
const orbit2 = await p.$(".sun-orbit");
if (orbit2) await orbit2.screenshot({ path: OUT + "/ast-revealed-hero.png" });

const after = await p.evaluate(
  () => document.querySelectorAll(".sun-orbit__body.is-revealed").length
);
console.log("AFTER tap, revealed bodies:", after);

console.log("ERRORS:", errs.length ? errs.slice(0, 5) : "none");
await b.close();
