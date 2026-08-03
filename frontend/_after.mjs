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
await p.waitForTimeout(1800);
const s = await p.evaluate(() => {
  const all=document.querySelectorAll("*"); let backdrop=0,willChange=0,filters=0;
  all.forEach(el=>{const cs=getComputedStyle(el);
    if(cs.backdropFilter&&cs.backdropFilter!=="none")backdrop++;
    if(cs.willChange&&cs.willChange!=="auto")willChange++;
    if(cs.filter&&cs.filter!=="none")filters++;});
  return {nodes:all.length, backdropFilterEls:backdrop, willChangeEls:willChange, filterEls:filters,
    moons:document.querySelectorAll(".sun-orbit__moon").length,
    starEls:document.querySelectorAll(".space__star").length,
    starLayers:document.querySelectorAll(".space__layer").length};
});
console.log("AFTER:", JSON.stringify(s));
// interaction latency
for (const [i,name] of [[1,"calendar"],[2,"settings"],[0,"home"]]) {
  const t=Date.now(); await (await p.$$(".tabbar__btn"))[i].click(); await p.waitForTimeout(40);
  console.log(`tab->${name} ~${Date.now()-t}ms`);
}
await p.waitForTimeout(600);
const t=Date.now(); await p.click(".home__add"); await p.waitForSelector(".sheet",{timeout:5000});
console.log(`sheet open ~${Date.now()-t}ms`);
await b.close();
