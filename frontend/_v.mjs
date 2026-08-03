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
await p.screenshot({ path: OUT+"/fix-home.png" });

// switch to Income (the state that looked broken) — orbit must stay intact
await p.evaluate(()=>document.querySelectorAll(".home__seg-btn")[2].click());
await p.waitForTimeout(1000);
await p.screenshot({ path: OUT+"/fix-income.png" });
const a = await p.evaluate(()=>{const m=document.querySelector(".app__main");const o=document.querySelector(".sun-orbit").getBoundingClientRect();return{scrollTop:Math.round(m.scrollTop),orbitTop:Math.round(o.top),orbitH:Math.round(o.height),rows:document.querySelectorAll(".row").length};});
console.log("income view:", JSON.stringify(a));

// tab away and back — scroll must reset, orbit must be visible
await p.evaluate(()=>{const m=document.querySelector(".app__main"); m.scrollTop=m.scrollHeight;});
await p.waitForTimeout(300);
await p.evaluate(()=>document.querySelectorAll(".tabbar__btn")[1].click());
await p.waitForTimeout(700);
await p.evaluate(()=>document.querySelectorAll(".tabbar__btn")[0].click());
await p.waitForTimeout(900);
const bck = await p.evaluate(()=>{const m=document.querySelector(".app__main");const o=document.querySelector(".sun-orbit").getBoundingClientRect();return{scrollTop:Math.round(m.scrollTop),orbitTop:Math.round(o.top)};});
console.log("back to home:", JSON.stringify(bck));
await p.screenshot({ path: OUT+"/fix-back.png" });
console.log("ERRORS:", errs.length?errs.slice(0,3):"none");
await b.close();
