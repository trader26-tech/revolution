import { chromium, devices } from "playwright";
const OUT="/private/tmp/claude-501/-Users-ranjeev-Documents-projects-revolution/6d98e278-2adc-4734-8ea3-20dc75661780/scratchpad";
const b = await chromium.launch();
const ctx = await b.newContext({ ...devices["iPhone 13"] });
const p = await ctx.newPage();
const errs=[]; p.on("pageerror",e=>errs.push(String(e))); p.on("console",m=>m.type()==="error"&&errs.push(m.text()));
await p.goto("http://localhost:4173/?seed", { waitUntil: "domcontentloaded" });
await p.evaluate(() => localStorage.setItem("revolution.onboarded.v1","1"));
await p.reload({ waitUntil: "domcontentloaded" });
await p.waitForTimeout(2500);
await p.screenshot({ path: OUT+"/bug-home.png" });

const info = await p.evaluate(() => {
  const main=document.querySelector(".app__main");
  const screens=[...document.querySelectorAll(".app__screen")];
  const home=document.querySelector(".home");
  const orbit=document.querySelector(".sun-orbit");
  const r=el=>{ if(!el) return null; const b=el.getBoundingClientRect(); return {t:Math.round(b.top),h:Math.round(b.height),w:Math.round(b.width)}; };
  return {
    mainRect:r(main), mainScrollH: main?.scrollHeight, mainClientH: main?.clientHeight,
    screenCount: screens.length,
    screens: screens.map(s=>({hidden:s.hasAttribute("hidden"), rect:r(s), disp:getComputedStyle(s).display})),
    homeRect:r(home), orbitRect:r(orbit),
    rows: document.querySelectorAll(".row").length,
  };
});
console.log(JSON.stringify(info,null,1));
console.log("ERRORS:", errs.length?errs.slice(0,4):"none");
await b.close();
