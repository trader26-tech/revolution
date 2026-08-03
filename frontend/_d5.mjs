import { chromium, devices } from "playwright";
const OUT="/private/tmp/claude-501/-Users-ranjeev-Documents-projects-revolution/6d98e278-2adc-4734-8ea3-20dc75661780/scratchpad";
const b = await chromium.launch();
const ctx = await b.newContext({ ...devices["iPhone 13"] });
const p = await ctx.newPage();
await p.goto("http://localhost:4173/", { waitUntil: "domcontentloaded" });
await p.evaluate(() => localStorage.setItem("revolution.onboarded.v1","1"));
await p.reload({ waitUntil: "domcontentloaded" });
await p.waitForTimeout(3000);

// Scroll to bottom, then flip the filter WITHOUT a real click (avoids
// actionability timeouts) by dispatching on the element directly.
await p.evaluate(()=>{ const m=document.querySelector(".app__main"); m.scrollTop = m.scrollHeight; });
await p.waitForTimeout(500);
const before = await p.evaluate(()=>{const m=document.querySelector(".app__main");return {scrollTop:Math.round(m.scrollTop),scrollH:m.scrollHeight,clientH:m.clientHeight,rows:document.querySelectorAll(".row").length};});
console.log("BEFORE:", JSON.stringify(before));

await p.evaluate(()=>{ document.querySelectorAll(".home__seg-btn")[2].click(); }); // Income
await p.waitForTimeout(900);
const after = await p.evaluate(()=>{const m=document.querySelector(".app__main");return {scrollTop:Math.round(m.scrollTop),scrollH:m.scrollHeight,clientH:m.clientHeight,rows:document.querySelectorAll(".row").length};});
console.log("AFTER :", JSON.stringify(after));
console.log("=> orphaned scroll?", after.scrollTop > (after.scrollH - after.clientH) + 2 ? "YES (scrolled past content)" : "no");
await p.screenshot({ path: OUT+"/bug-repro.png" });
await b.close();
