import { chromium, devices } from "playwright";
const b = await chromium.launch();
const ctx = await b.newContext({ ...devices["iPhone 13"] });
const p = await ctx.newPage();
const cdp = await ctx.newCDPSession(p);
await cdp.send("Emulation.setCPUThrottlingRate", { rate: 4 });
await p.goto("http://localhost:4173/", { waitUntil: "domcontentloaded" });
await p.evaluate(() => localStorage.setItem("revolution.onboarded.v1","1"));
await p.reload({ waitUntil: "domcontentloaded" });
await p.waitForSelector(".sun-orbit", { timeout: 30000 });
await p.waitForTimeout(1500);

// Count DOM nodes, composited layers, animated elements
const stats = await p.evaluate(() => {
  const all = document.querySelectorAll("*");
  let backdrop=0, willChange=0, filters=0, transforms=0;
  all.forEach(el=>{
    const cs=getComputedStyle(el);
    if (cs.backdropFilter && cs.backdropFilter!=="none") backdrop++;
    if (cs.willChange && cs.willChange!=="auto") willChange++;
    if (cs.filter && cs.filter!=="none") filters++;
    if (cs.transform && cs.transform!=="none") transforms++;
  });
  return { nodes: all.length, backdrop, willChange, filters, transforms,
           moons: document.querySelectorAll(".sun-orbit__moon").length,
           stars: document.querySelectorAll(".space__star").length };
});
console.log("DOM/paint profile:", JSON.stringify(stats, null, 0));

// Layout thrash: force reflow measurement during animation
const layout = await cdp.send("Performance.getMetrics");
const m = Object.fromEntries(layout.metrics.map(x=>[x.name,x.value]));
console.log(`LayoutCount=${m.LayoutCount} RecalcStyleCount=${m.RecalcStyleCount} LayoutDuration=${m.LayoutDuration?.toFixed(3)}s RecalcStyleDuration=${m.RecalcStyleDuration?.toFixed(3)}s ScriptDuration=${m.ScriptDuration?.toFixed(3)}s`);
await p.waitForTimeout(3000);
const layout2 = await cdp.send("Performance.getMetrics");
const m2 = Object.fromEntries(layout2.metrics.map(x=>[x.name,x.value]));
console.log(`after 3s idle: +Layout=${m2.LayoutCount-m.LayoutCount} +RecalcStyle=${m2.RecalcStyleCount-m.RecalcStyleCount} +ScriptDur=${(m2.ScriptDuration-m.ScriptDuration).toFixed(3)}s +RecalcDur=${(m2.RecalcStyleDuration-m.RecalcStyleDuration).toFixed(3)}s`);
await b.close();
