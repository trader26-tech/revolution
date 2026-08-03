import { chromium, devices } from "playwright";
const OUT="/private/tmp/claude-501/-Users-ranjeev-Documents-projects-revolution/6d98e278-2adc-4734-8ea3-20dc75661780/scratchpad";
const b = await chromium.launch();
const ctx = await b.newContext({ ...devices["iPhone 13"] });
const p = await ctx.newPage();
const errs=[]; p.on("pageerror",e=>errs.push(String(e))); p.on("console",m=>m.type()==="error"&&errs.push(m.text()));
await p.goto("http://localhost:4173/", { waitUntil: "domcontentloaded" });
await p.evaluate(() => localStorage.setItem("revolution.onboarded.v1","1"));
await p.reload({ waitUntil: "domcontentloaded" });
await p.waitForTimeout(3500);
await p.screenshot({ path: OUT+"/bug-top.png" });
const info = await p.evaluate(() => ({
  hasHome: !!document.querySelector(".home"),
  hasOrbit: !!document.querySelector(".sun-orbit"),
  moons: document.querySelectorAll(".sun-orbit__moon").length,
  rows: document.querySelectorAll(".row").length,
  segBtns: document.querySelectorAll(".home__seg-btn").length,
  chips: document.querySelectorAll(".chip").length,
  banner: document.querySelector(".connection-banner")?.textContent?.trim()?.slice(0,80) || null,
  screens: [...document.querySelectorAll(".app__screen")].map(s=>s.hasAttribute("hidden")),
  bodyTxt: document.body.innerText.replace(/\s+/g," ").slice(0,180),
}));
console.log(JSON.stringify(info,null,1));
console.log("ERRORS:", errs.length?errs.slice(0,3):"none");
await b.close();
