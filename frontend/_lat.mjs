import { chromium, devices } from "playwright";
const b = await chromium.launch();
const ctx = await b.newContext({ ...devices["iPhone 13"] });
const p = await ctx.newPage();
const cdp = await ctx.newCDPSession(p);
await cdp.send("Emulation.setCPUThrottlingRate", { rate: 4 });
await p.goto("http://localhost:4173/?seed", { waitUntil: "domcontentloaded" });
await p.evaluate(() => localStorage.setItem("revolution.onboarded.v1","1"));
await p.reload({ waitUntil: "domcontentloaded" });
await p.waitForSelector(".sun-orbit", { timeout: 30000 });
await p.waitForTimeout(1500);

// Measure IN-PAGE: dispatch click, then time until the next painted frame.
const results = await p.evaluate(async () => {
  const out = [];
  const btns = [...document.querySelectorAll(".tabbar__btn")];
  const order = [1,2,0,1,2,0];
  for (const i of order) {
    await new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r)));
    const t0 = performance.now();
    btns[i].click();
    // wait for the frame that reflects the new screen
    await new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r)));
    out.push(Math.round(performance.now() - t0));
    await new Promise(r => setTimeout(r, 250));
  }
  return out;
});
console.log("click->painted frame (ms):", results.join(", "));
const avg = (results.reduce((a,c)=>a+c,0)/results.length).toFixed(1);
console.log("avg:", avg, "ms");
await b.close();
