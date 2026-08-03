import { chromium, devices } from "playwright";
const OUT="/private/tmp/claude-501/-Users-ranjeev-Documents-projects-revolution/6d98e278-2adc-4734-8ea3-20dc75661780/scratchpad";
const b = await chromium.launch();
const ctx = await b.newContext({ ...devices["iPhone 13"] });
const p = await ctx.newPage();
const errs=[]; p.on("pageerror",e=>errs.push(String(e))); p.on("console",m=>m.type()==="error"&&errs.push(m.text()));
const cdp = await ctx.newCDPSession(p);
await cdp.send("Emulation.setCPUThrottlingRate", { rate: 4 });
await p.goto("http://localhost:4173/?seed", { waitUntil: "domcontentloaded" });
await p.evaluate(() => localStorage.setItem("revolution.onboarded.v1","1"));
await p.reload({ waitUntil: "domcontentloaded" });
await p.waitForSelector(".sun-orbit", { timeout: 30000 });
await p.waitForTimeout(2200);
await p.screenshot({ path: OUT+"/perf-home.png" });

// scroll jank test: measure frames during a programmatic scroll
const fps = await p.evaluate(async () => {
  const main = document.querySelector(".app__main");
  let frames=0, raf=true;
  const tick=()=>{frames++; if(raf) requestAnimationFrame(tick);};
  requestAnimationFrame(tick);
  const t0=performance.now();
  for (let i=0;i<40;i++){ main.scrollTop += 14; await new Promise(r=>requestAnimationFrame(r)); }
  raf=false;
  return Math.round(frames/((performance.now()-t0)/1000));
});
console.log("scroll fps (4x throttle):", fps);

// reveal logos then screenshot
await p.evaluate(()=>document.querySelector(".app__main").scrollTop=0);
await p.click(".sun-orbit__sun"); await p.waitForTimeout(1600);
await p.screenshot({ path: OUT+"/perf-reveal.png" });
// tab screens still render?
const tabs = await p.$$(".tabbar__btn");
await tabs[1].click(); await p.waitForTimeout(700);
console.log("calendar visible:", await p.evaluate(()=>!!document.querySelector(".cal") && !document.querySelector(".cal").closest("[hidden]")));
await tabs[2].click(); await p.waitForTimeout(700);
console.log("settings visible:", await p.evaluate(()=>!!document.querySelector(".set") && !document.querySelector(".set").closest("[hidden]")));
await tabs[0].click(); await p.waitForTimeout(700);
await p.screenshot({ path: OUT+"/perf-back-home.png" });
console.log("ERRORS:", errs.length?errs.slice(0,4):"none");
await b.close();
