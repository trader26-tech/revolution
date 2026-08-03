import { chromium } from "playwright";
const OUT = "/private/tmp/claude-501/-Users-ranjeev-Documents-projects-revolution/6d98e278-2adc-4734-8ea3-20dc75661780/scratchpad";
const b = await chromium.launch();
const p = await b.newPage({ viewport: { width: 402, height: 874 }, deviceScaleFactor: 2 });
const errs=[]; p.on("pageerror",e=>errs.push(String(e))); p.on("console",m=>m.type()==="error"&&errs.push(m.text()));

await p.goto("http://localhost:5173/", { waitUntil: "domcontentloaded" });
await p.evaluate(() => localStorage.setItem("revolution.onboarded.v1", "1"));
await p.reload({ waitUntil: "domcontentloaded" });
await p.waitForSelector(".sun-orbit", { timeout: 15000 });
await p.waitForTimeout(2200);

// 1) reveal moons -> real logos
await p.click(".sun-orbit__sun");
await p.waitForTimeout(1500);
const orbit = await p.$(".sun-orbit");
await orbit.screenshot({ path: OUT + "/brand-reveal.png" });

// 2) open Add -> expense picker with real logos
await p.click(".tabbar__add");
await p.waitForTimeout(900);
await p.screenshot({ path: OUT + "/brand-picker.png" });

// 3) type a custom name and confirm auto-match logo appears in the tiles
const input = await p.$(".ae__search input");
if (input) { await input.fill("spotify"); await p.waitForTimeout(500); }
await p.screenshot({ path: OUT + "/brand-search.png" });

// 4) switch to Income tab
const incomeBtn = await p.$("button:has-text('+ Income')");
if (incomeBtn) { await incomeBtn.click(); await p.waitForTimeout(500); }
await p.screenshot({ path: OUT + "/brand-income.png" });

// count how many tiles rendered a real <svg> logo vs initial
const stats = await p.evaluate(() => ({
  tiles: document.querySelectorAll(".ae__tile").length,
  svgLogos: document.querySelectorAll(".ae__tile .brand-logo svg").length,
  initials: document.querySelectorAll(".ae__tile .brand-logo__initial").length,
}));
console.log("PICKER:", JSON.stringify(stats));
console.log("ERRORS:", errs.length?errs.slice(0,5):"none");
await b.close();
