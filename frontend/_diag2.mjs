import { chromium, devices } from "playwright";
const OUT="/private/tmp/claude-501/-Users-ranjeev-Documents-projects-revolution/6d98e278-2adc-4734-8ea3-20dc75661780/scratchpad";
const b = await chromium.launch();
const ctx = await b.newContext({ ...devices["iPhone 13"] });
const p = await ctx.newPage();
const errs=[]; p.on("pageerror",e=>errs.push(String(e))); p.on("console",m=>m.type()==="error"&&errs.push(m.text()));
await p.goto("http://localhost:4173/", { waitUntil: "domcontentloaded" });
await p.evaluate(() => localStorage.setItem("revolution.onboarded.v1","1"));
await p.reload({ waitUntil: "domcontentloaded" });
await p.waitForTimeout(3000);
await p.screenshot({ path: OUT+"/bug-top.png" });

// now click the "Expenses" filter like the user's screenshot shows
const segs = await p.$$(".home__seg-btn");
console.log("seg buttons:", segs.length);
if (segs[1]) { await segs[1].click(); await p.waitForTimeout(900); }
await p.screenshot({ path: OUT+"/bug-expenses.png" });

const info = await p.evaluate(() => {
  const main=document.querySelector(".app__main");
  const home=document.querySelector(".home");
  return {
    rows: document.querySelectorAll(".row").length,
    subsSeen: document.querySelectorAll(".sun-orbit__moon").length,
    mainScrollTop: main?.scrollTop, mainScrollH: main?.scrollHeight, mainClientH: main?.clientHeight,
    homeH: Math.round(home?.getBoundingClientRect().height||0),
    emptyMsg: document.querySelector(".home__empty")?.textContent?.trim()||null,
  };
});
console.log(JSON.stringify(info));
console.log("ERRORS:", errs.length?errs.slice(0,3):"none");
await b.close();
