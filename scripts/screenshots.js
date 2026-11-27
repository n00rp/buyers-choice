// Tar skärmbilderna i docs/screenshots/. Starta först servern: cd portal && python3 -m http.server 8000
// Kör sedan: node scripts/screenshots.js  (kräver Playwright med Chromium)
const {chromium}=require('playwright');
(async()=>{
const b=await chromium.launch();
const path=require('path');const out=path.join(__dirname,'..','docs','screenshots')+'/';const base=process.env.BASE||'http://localhost:8000';
const p=await b.newPage({viewport:{width:1440,height:900},deviceScaleFactor:2});
p.on('pageerror',e=>console.log('ERR',e.message));
// scroll target: section's first h2 (or a selector) placed just under sticky header
async function scrollTo(sel){await p.evaluate(sel=>{const el=document.querySelector(sel);const hh=document.querySelector('#top').getBoundingClientRect().height;window.scrollTo(0,el.getBoundingClientRect().top+scrollY-hh-(sel.includes("fastighet")?64:24));},sel);await p.waitForTimeout(900);}
const views=[['oversikt','02-oversikt',null],['oversikt','03-karta','#mapwrap'],['fastighet','04-fastighet-och-detaljplan','section[data-view=fastighet] h2'],['miljo','05-miljo-och-risk','section[data-view=miljo] h2'],['omradet','06-planer-i-omradet','section[data-view=omradet] h2'],['narservice','07-narservice','section[data-view=narservice] h2'],['visning','08-fragor-till-visningen','section[data-view=visning] h2'],['kallor','09-kallor','section[data-view=kallor] h2']];
await p.goto(base+'/#start');await p.waitForTimeout(2500);
await p.screenshot({path:out+'01-start.png'});
for(const [h,n,sel] of views){await p.evaluate(h=>{location.hash=h},h);await p.waitForTimeout(1500);
 if(sel)await scrollTo(sel);else{await p.evaluate(()=>window.scrollTo(0,0));await p.waitForTimeout(300);}
 await p.waitForTimeout(1200);await p.screenshot({path:out+n+'.png'});console.log(n);}
await p.evaluate(()=>{location.hash='start'});await p.waitForTimeout(800);
await p.fill('#q2','Kungsportsavenyen 10');await p.waitForTimeout(800);
await p.keyboard.press('ArrowDown');await p.keyboard.press('Enter');await p.waitForTimeout(2500);
await p.evaluate(()=>window.scrollTo(0,0));await p.waitForTimeout(500);
await p.screenshot({path:out+'10-grundrapport.png'});
await p.evaluate(()=>{localStorage.removeItem('bc-cmp');location.hash='jamfor'});await p.waitForTimeout(1200);
await p.click('[data-cmp-ex*="Vildkaprifolen"]');await p.waitForTimeout(2000);
await p.evaluate(()=>window.scrollTo(0,0));await p.waitForTimeout(500);
await p.screenshot({path:out+'14-jamfor.png'});
const mc=await b.newPage({viewport:{width:390,height:844},deviceScaleFactor:2,isMobile:true});
await mc.goto(base+'/'+(await p.evaluate(()=>location.hash)));await mc.waitForTimeout(2500);
await mc.evaluate(()=>{const el=document.querySelector('.cmp-sec');window.scrollTo(0,el.getBoundingClientRect().top+scrollY-260);});await mc.waitForTimeout(600);
await mc.screenshot({path:out+'15-jamfor-mobil.png'});
const m=await b.newPage({viewport:{width:390,height:844},deviceScaleFactor:2,isMobile:true});
await m.goto(base+'/#oversikt');await m.waitForTimeout(2500);await m.screenshot({path:out+'11-mobil.png'});
await m.click('#menu-btn');await m.waitForTimeout(800);await m.screenshot({path:out+'12-mobil-meny.png'});
await b.close();})();
