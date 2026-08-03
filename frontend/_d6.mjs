import { chromium, devices } from "playwright";
const b = await chromium.launch();
const ctx = await b.newContext({ ...devices["iPhone 13"] });
const p = await ctx.newPage();
await p.goto("http://localhost:4173/", { waitUntil: "domcontentloaded" });
await p.evaluate(() => localStorage.setItem("revolution.onboarded.v1","1"));
await p.reload({ waitUntil: "domcontentloaded" });
await p.waitForTimeout(3000);
const m = await p.evaluate(()=>{
  const main=document.querySelector(".app__main");
  const scr=document.querySelector(".app__screen:not([hidden])");
  const home=document.querySelector(".home");
  const cs=el=>el?getComputedStyle(el):null;
  return {
    main:{h:Math.round(main.getBoundingClientRect().height), scrollH:main.scrollHeight, display:cs(main).display, flexDir:cs(main).flexDirection},
    screen:{h:Math.round(scr.getBoundingClientRect().height), minH:cs(scr).minHeight, flex:cs(scr).flex, display:cs(scr).display},
    home:{h:Math.round(home.getBoundingClientRect().height), minH:cs(home).minHeight},
  };
});
console.log(JSON.stringify(m,null,1));
await b.close();
