import { chromium, devices } from "playwright";
const OUT="/private/tmp/claude-501/-Users-ranjeev-Documents-projects-revolution/6d98e278-2adc-4734-8ea3-20dc75661780/scratchpad";
const b = await chromium.launch();
const ctx = await b.newContext({ ...devices["iPhone 13"] });
const p = await ctx.newPage();
await p.goto("http://localhost:4173/", { waitUntil: "domcontentloaded" });
await p.evaluate(() => localStorage.setItem("revolution.onboarded.v1","1"));
await p.reload({ waitUntil: "domcontentloaded" });
await p.waitForTimeout(3000);

// scroll to the bottom of the list (as a user browsing would)
await p.evaluate(()=>{ const m=document.querySelector(".app__main"); m.scrollTop = m.scrollHeight; });
await p.waitForTimeout(600);
const before = await p.evaluate(()=>{const m=document.querySelector(".app__main");return {scrollTop:Math.round(m.scrollTop),scrollH:m.scrollHeight,clientH:m.clientHeight};});
console.log("scrolled to bottom:", JSON.stringify(before));

// now switch to a filter with FEWER/zero results -> content shrinks under us
const segs = await p.$$(".home__seg-btn");
await segs[2].click();           // Income (fewer rows)
await p.waitForTimeout(900);
const after = await p.evaluate(()=>{const m=document.querySelector(".app__main");return {scrollTop:Math.round(m.scrollTop),scrollH:m.scrollHeight,clientH:m.clientHeight,rows:document.querySelectorAll(".row").length};});
console.log("after switching filter:", JSON.stringify(after));
await p.screenshot({ path: OUT+"/bug-repro.png" });
await b.close();
