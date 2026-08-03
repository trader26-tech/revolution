import { chromium, devices } from "playwright";

const URL = "http://localhost:4173/";
const b = await chromium.launch();
const ctx = await b.newContext({ ...devices["iPhone 13"] });
const p = await ctx.newPage();

// Throttle CPU 4x to emulate a real mid-range phone
const cdp = await ctx.newCDPSession(p);
await cdp.send("Emulation.setCPUThrottlingRate", { rate: 4 });

await p.goto(URL, { waitUntil: "domcontentloaded" });
await p.evaluate(() => localStorage.setItem("revolution.onboarded.v1", "1"));
await p.reload({ waitUntil: "domcontentloaded" });
await p.waitForSelector(".sun-orbit", { timeout: 30000 });
await p.waitForTimeout(2000);

// Instrument: count frames + long tasks over a window
async function measure(label, action) {
  await p.evaluate(() => {
    window.__f = 0;
    window.__long = [];
    window.__raf = true;
    const tick = () => { window.__f++; if (window.__raf) requestAnimationFrame(tick); };
    requestAnimationFrame(tick);
    window.__po = new PerformanceObserver((l) => {
      for (const e of l.getEntries()) window.__long.push(Math.round(e.duration));
    });
    try { window.__po.observe({ entryTypes: ["longtask"] }); } catch {}
  });
  const t0 = Date.now();
  if (action) await action();
  await p.waitForTimeout(3000);
  const r = await p.evaluate(() => {
    window.__raf = false;
    try { window.__po.disconnect(); } catch {}
    return { frames: window.__f, long: window.__long };
  });
  const secs = (Date.now() - t0) / 1000;
  const fps = (r.frames / secs).toFixed(1);
  const longTotal = r.long.reduce((a, c) => a + c, 0);
  console.log(
    `${label.padEnd(22)} fps=${String(fps).padStart(5)}  longTasks=${String(r.long.length).padStart(3)}  blockedMs=${String(longTotal).padStart(5)}  worst=${r.long.length ? Math.max(...r.long) : 0}ms`
  );
  return Number(fps);
}

console.log("--- CPU throttled 4x (mid-range phone) ---");
await measure("idle: orbit home");
await measure("after sun reveal", async () => {
  await p.click(".sun-orbit__sun");
});

// tab switch latency
const tabs = await p.$$(".tabbar__btn");
for (const [i, name] of [[1, "calendar"], [2, "settings"], [0, "home"]]) {
  const t = Date.now();
  await (await p.$$(".tabbar__btn"))[i].click();
  await p.waitForTimeout(50);
  console.log(`tab->${name} click-to-paint ~${Date.now() - t}ms`);
}
await p.waitForTimeout(800);

// sheet open latency
const t = Date.now();
await p.click(".home__add");
await p.waitForSelector(".sheet", { timeout: 5000 });
console.log(`add sheet open ~${Date.now() - t}ms`);
await measure("with sheet open");

await b.close();
