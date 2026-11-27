/* Bevakning av adresser.
   Läser portal/bevakning/handelser.json och planarbete.json, som byggs varje dag av
   scripts/bevakning/hamta.py. Bevakade adresser sparas i webbläsaren (localStorage). Mejl
   skickas av scripts/bevakning/skicka.py för bevakningar som lagts in i GitHub.
   Bygger på index.html: D, curA, mode, loadData, go, esc, fmtD, $ och $$ finns där. */
(()=>{
const BV_KEY="bc-bevakning";
const UK='<span class="bv-uk">Under konstruktion</span>';
const RADIER=[500,1000,2000];
const AKTIVA=new Set(["tidigt","samrad","granskning","antagande","overklagad","bygge"]);
const TYP={nytt_planarbete:"Nytt planarbete",nytt_skede:"Nytt skede",synpunkter:"Öppet för synpunkter",ny_plan:"Ny gällande plan",notis:"Uppdatering från staden"};
const FAS_C={tidigt:"#8A7F6E",samrad:"#B7791F",granskning:"#B7791F",antagande:"#2F5D50",overklagad:"#9B4D3A",lagakraft:"#2F5D50",bygge:"#3559C7"};
const MAN=["januari","februari","mars","april","maj","juni","juli","augusti","september","oktober","november","december"];
const dText=iso=>{const [y,m,d]=String(iso).slice(0,10).split("-");return `${+d} ${MAN[+m-1]} ${y}`;};
const fmtR=m=>m<1000?m+" m":(m/1000+" km").replace(".",",");
const today=()=>new Date().toISOString().slice(0,10);

/* ---- sparade bevakningar ---- */
let mem=null;
function list(){if(mem)return mem;try{mem=JSON.parse(localStorage.getItem(BV_KEY)||"[]");}catch(e){mem=[];}if(!Array.isArray(mem))mem=[];return mem;}
function save(){try{localStorage.setItem(BV_KEY,JSON.stringify(mem));}catch(e){}}
const kmOf=a=>a&&a.km||0;
const same=(b,a)=>b.l===a.l&&(b.km||0)===kmOf(a);
const findA=a=>list().find(b=>same(b,a));
const inGbg=a=>kmOf(a)===0;
const kNamn=a=>typeof KOM!=="undefined"&&KOM[kmOf(a)]?KOM[kmOf(a)].namn:"";

/* ---- data ---- */
let Hp=null;
function data(){if(Hp)return Hp;
  Hp=Promise.all(["bevakning/handelser.json","bevakning/planarbete.json"].map(u=>fetch(u).then(r=>{if(!r.ok)throw new Error(u);return r.json();})))
    .then(([h,p])=>{const K={};p.kol.forEach((k,i)=>K[k]=i);
      return {H:h.h,upd:h.uppdaterad,F:p.faser,P:p.p.map(r=>({namn:r[K.namn],slag:r[K.slag],steg:r[K.steg],fas:r[K.fas],x:r[K.x],y:r[K.y],lank:r[K.lank],syn:r[K.synpunkter],ungefar:r[K.ungefar]}))};});
  Hp.catch(()=>{Hp=null;});return Hp;}
const dist=(o,a)=>Math.round(Math.hypot(o.x-a.e,o.y-a.n));
function near(B,a,r){
  const seen=new Set(),h=B.H.filter(x=>{if(x.x==null)return false;const k=[x.typ,x.rubrik,x.datum,x.text].join("|");if(seen.has(k))return false;seen.add(k);return true;})
    .map(x=>({...x,m:dist(x,a)})).filter(x=>x.m<=r);
  const p=B.P.filter(x=>AKTIVA.has(x.fas)).map(x=>({...x,m:dist(x,a)})).filter(x=>x.m<=r).sort((x,y)=>x.m-y.m);
  return {h,p};}

/* ---- stil ---- */
const css=`
#bv-basic,#bv-full{display:grid;gap:40px;min-width:0}
.bv-uk{display:inline-flex;vertical-align:middle;margin-left:10px;font-family:var(--f-body);font-size:.8rem;font-weight:600;letter-spacing:0;color:#8A5A12;background:#F7ECD7;border-radius:999px;padding:3px 12px}
.bv-card{background:var(--card,#fff);border:1px solid var(--line);border-radius:var(--r-card,20px);padding:26px 28px;display:grid;gap:18px;box-shadow:var(--shadow-card,none)}
.bv-top{display:flex;flex-wrap:wrap;gap:14px 24px;align-items:center;justify-content:space-between}
.bv-state{display:grid;gap:4px}
.bv-state b{font-family:var(--f-display);font-weight:500;font-size:1.3rem;letter-spacing:-.01em}
.bv-radius{display:flex;flex-wrap:wrap;gap:8px;align-items:center}
.bv-radius span{font-size:.88rem;color:var(--muted);margin-right:4px}
.bv-radius .chip[aria-pressed="true"]{background:var(--fg);border-color:var(--fg);color:#fff}
.bv-mail{border-top:1px solid var(--line);padding-top:16px;font-size:.92rem;color:var(--muted);max-width:72ch}
.bv-mail b{color:var(--fg)}
.bv-ev .when{font-size:.84rem;color:var(--muted)}
.bv-new{display:inline-block;font-size:.72rem;font-weight:600;color:#fff;background:var(--accent);border-radius:999px;padding:1px 8px;margin-left:8px;vertical-align:2px}
.bv-fas{display:inline-flex;align-items:center;gap:6px;font-size:.8rem;font-weight:500;color:var(--fg);background:var(--subtle);border-radius:999px;padding:2px 10px;white-space:nowrap}
.bv-fas i{width:8px;height:8px;border-radius:50%;background:var(--c)}
.bv-empty{color:var(--muted);padding:16px 0;border-top:1px solid var(--line)}
.bv-head-btn{all:unset;box-sizing:border-box;display:inline-flex;align-items:center;gap:7px;cursor:pointer;font-size:.86rem;font-weight:500;padding:6px 14px;border-radius:999px;border:1px solid var(--line);background:var(--card,#fff);color:var(--fg)}
.bv-head-btn:hover{background:var(--subtle)}
.bv-head-btn:focus-visible{outline:2px solid var(--accent);outline-offset:2px}
.bv-head-btn[aria-pressed="true"]{background:var(--accent-soft);border-color:var(--accent-soft);color:var(--accent)}
.bv-dot{display:inline-grid;place-items:center;min-width:18px;height:18px;padding:0 5px;border-radius:999px;background:var(--accent);color:#fff;font-size:.7rem;font-weight:600;margin-left:6px;vertical-align:1px}
.bv-start{max-width:800px;margin:0;display:grid;gap:10px;background:var(--card,#fff);border:1px solid var(--line);border-radius:var(--r-card,20px);padding:20px 24px}
.bv-start ul li:last-child{border-bottom:0}
.bv-start ul{list-style:none;margin:0;padding:0;border-top:1px solid var(--line)}
.bv-start li{display:flex;justify-content:space-between;gap:12px;padding:12px 0;border-bottom:1px solid var(--line)}
@media (max-width:560px){.bv-card{padding:20px}}`;
const st=document.createElement("style");st.textContent=css;document.head.appendChild(st);

const bell='<svg width="15" height="15" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M4 11.5V7a4 4 0 0 1 8 0v4.5l1 1H3Z"/><path d="M6.6 14a1.5 1.5 0 0 0 2.8 0"/></svg>';

/* ---- vilken adress visas ---- */
function curIdx(){if(!D)return -1;return mode==="basic"?curA:mode==="full"?D.full:-1;}
const hashOf=k=>k===D.full?"#bevakning":"#a"+k+"-bevakning";

function toggle(k,r){const a=D.A[k],L=list(),i=L.findIndex(b=>same(b,a));
  if(i>=0){L.splice(i,1);save();refresh();return;}
  r=r||1000;
  data().then(B=>{L.push({l:a.l,km:kmOf(a),k,r,sparad:today(),sett:near(B,a,r).h.map(x=>x.id)});save();refresh();})
    .catch(()=>{L.push({l:a.l,km:kmOf(a),k,r,sparad:today(),sett:null});save();refresh();});}
function setRadius(k,r){const b=findA(D.A[k]);if(b){b.r=r;save();}render(r);}
function markRead(k){const b=findA(D.A[k]);if(!b)return;data().then(B=>{b.sett=near(B,D.A[k],b.r).h.map(x=>x.id);save();refresh();});}
function newFor(b,B){const a=D.A[b.k];if(!a||!same(b,a))return [];const seen=new Set(b.sett||[]);return near(B,a,b.r).h.filter(x=>b.sett&&!seen.has(x.id));}

/* ---- knappen i rapportens sidhuvud ---- */
function headBtn(){const k=curIdx();if(k<0)return;
  const host=mode==="basic"?$("#b-head .bhead .row"):$("#full-head .prop-actions");if(!host)return;
  let b=host.querySelector(".bv-head-btn");
  if(!inGbg(D.A[k])){if(b)b.remove();return;}
  if(!b){b=document.createElement("button");b.type="button";b.className="bv-head-btn";host.appendChild(b);
    b.addEventListener("click",()=>{const k=curIdx();if(findA(D.A[k]))go("bevakning");else{toggle(k);go("bevakning");}});}
  const on=!!findA(D.A[k]);b.setAttribute("aria-pressed",on);b.innerHTML=bell+(on?"Bevakas":"Bevaka adressen");}

/* ---- antal nya i menyn ---- */
function navDot(){const a=$('.sidenav [data-tab="bevakning"]');if(!a)return;let d=a.querySelector(".bv-dot");
  const k=curIdx(),b=k>=0&&findA(D.A[k]);
  if(!b){if(d)d.remove();return;}
  data().then(B=>{const n=newFor(b,B).length;d=a.querySelector(".bv-dot");
    if(!n){if(d)d.remove();return;}if(!d){d=document.createElement("span");d.className="bv-dot";a.appendChild(d);}d.textContent=n;}).catch(()=>{});}

/* ---- själva vyn ---- */
function evLi(x,isNew){const link=x.lank&&/^https:\/\//.test(x.lank);
  return `<li class="bv-ev"><span class="nm">${link?`<a href="${esc(x.lank)}" target="_blank" rel="noopener" style="color:inherit">${esc(x.rubrik)}</a>`:esc(x.rubrik)}${isNew?'<span class="bv-new">Nytt</span>':""}</span>
    <span class="meta"><span class="when">${TYP[x.typ]||"Händelse"} · ${dText(x.datum)} · ${x.ungefar?"cirka ":""}${fmtD(x.m)} bort</span><br>${esc(x.text)}</span>
    <span class="act">${link?`<a class="btn sm" href="${esc(x.lank)}" target="_blank" rel="noopener">${x.typ==="ny_plan"?"Plankarta (PDF)":"Projektsidan"} <span class="arr">↗</span></a>`:""}</span></li>`;}
function prLi(p,F){return `<li><span class="nm">${esc(p.namn)}</span>
    <span class="meta"><span class="bv-fas" style="--c:${FAS_C[p.fas]||"#8A7F6E"}"><i></i>${esc(F[p.fas]||p.fas)}</span> &nbsp;${esc(p.slag)} · ${p.ungefar?"cirka ":""}${fmtD(p.m)} bort${p.syn&&p.syn[1]>=today().replace(/-/g,"")?` · synpunkter till ${dText(p.syn[1].replace(/(\d{4})(\d\d)(\d\d)/,"$1-$2-$3"))}`:""}</span>
    <span class="act">${p.lank?`<a class="btn sm" href="${esc(p.lank)}" target="_blank" rel="noopener">Projektsidan <span class="arr">↗</span></a>`:""}</span></li>`;}

let showAll=false;
function render(rOverride){const k=curIdx();if(k<0)return;
  const host=mode==="basic"?$("#bv-basic"):$("#bv-full");if(!host)return;
  const a=D.A[k],b=findA(a),r=rOverride||(b?b.r:1000);
  if(!inGbg(a)){host.innerHTML=`<div class="block"><h2>Bevakning ${UK}</h2><p class="lead">Bevakning av planarbete finns än så länge bara för adresser i Göteborg. Där hämtas stadens plan- och byggprojekt varje morgon.</p></div>
    <div class="notice">${esc(kNamn(a))} publicerar inte sina pågående planarbeten som data som går att hämta varje dag. Se kommunens egen lista${typeof KOM!=="undefined"&&KOM[kmOf(a)].plansida?`: <a href="${esc(KOM[kmOf(a)].plansida)}" target="_blank" rel="noopener">pågående detaljplanering hos ${esc(kNamn(a))}</a>`:"."}</div>`;return;}
  host.innerHTML=`<div class="block"><h2>Bevakning ${UK}</h2><p class="lead">Följ vad som händer runt ${esc(a.l)}: nya planarbeten, samråd och granskning, beslut om antagande och laga kraft, och nya gällande planer.</p></div><p class="muted">Laddar …</p>`;
  data().then(B=>{if(curIdx()!==k)return;
    const N=near(B,a,r),seen=b&&b.sett?new Set(b.sett):null;
    const isNew=x=>seen&&!seen.has(x.id),nNew=N.h.filter(isNew).length;
    const others=list().filter(o=>!same(o,a));
    const ev=N.h.slice().sort((x,y)=>(isNew(y)-isNew(x))||y.datum.localeCompare(x.datum));
    const pr=showAll?N.p:N.p.slice(0,10);
    host.innerHTML=`
    <div class="block"><h2>Bevakning ${UK}</h2><p class="lead">Följ vad som händer runt ${esc(a.l)}: nya planarbeten, samråd och granskning, beslut om antagande och laga kraft, och nya gällande planer.</p></div>
    <div class="bv-card">
      <div class="bv-top">
        <div class="bv-state">${b?`<b>Du bevakar adressen</b><span class="muted small">Sedan ${dText(b.sparad)}. ${nNew?`${nNew===1?"En ny händelse":nNew+" nya händelser"} sedan du senast tittade.`:"Inget nytt sedan du senast tittade."}</span>`:`<b>Bevaka adressen</b><span class="muted small">Spara adressen så markeras nya händelser i närheten när du kommer tillbaka.</span>`}</div>
        <div class="prop-actions" style="margin:0">${b?`${nNew?'<button class="btn" type="button" data-bv="read">Markera som läst</button>':""}<button class="linkbtn" type="button" data-bv="toggle">Sluta bevaka</button>`:`<button class="btn primary" type="button" data-bv="toggle">${bell} Bevaka adressen</button>`}</div>
      </div>
      <div class="bv-radius" role="group" aria-label="Avstånd"><span>Inom</span>${RADIER.map(x=>`<button class="chip" type="button" data-bv-r="${x}" aria-pressed="${x===r}">${fmtR(x)}</button>`).join("")}</div>
      <div class="bv-mail"><b>Under konstruktion.</b> Bevakningen byggs fortfarande. Mejl om nyheter skickas inte än. Det du sparar här finns bara i den här webbläsaren, och uppgifterna om planarbete kan ändras när tjänsten blir klar.</div>
    </div>
    <div class="block"><div class="block-head"><h3>${b?"Händelser i närheten":"Senaste händelserna i närheten"}</h3><span class="src">Inom ${fmtR(r)}, senaste året</span></div>
      ${ev.length?`<ul class="plist">${ev.map(x=>evLi(x,isNew(x))).join("")}</ul>`:`<p class="bv-empty">Inga registrerade händelser inom ${fmtR(r)} det senaste året. Nya händelser samlas in varje dag från och med ${dText(B.upd)}.</p>`}
    </div>
    <div class="block"><div class="block-head"><h3>Pågående planarbete i närheten</h3><span class="src">${N.p.length} inom ${fmtR(r)}</span></div>
      ${N.p.length?`<ul class="plist">${pr.map(p=>prLi(p,B.F)).join("")}</ul>${N.p.length>pr.length?`<div><button class="btn" type="button" data-bv="all">Visa alla ${N.p.length}</button></div>`:""}`:`<p class="bv-empty">Staden har inget pågående planarbete inom ${fmtR(r)} i sin projektlista.</p>`}
    </div>
    ${others.length?`<div class="block"><h3>Andra adresser du bevakar</h3><ul class="plist">${others.map(o=>{const n=newFor(o,B).length;return `<li><span class="nm"><a href="${hashOf(o.k)}" style="color:inherit">${esc(o.l)}</a>${n?`<span class="bv-new">${n} ${n===1?"ny":"nya"}</span>`:""}</span><span class="meta">Inom ${fmtR(o.r)} · sedan ${dText(o.sparad)}</span></li>`;}).join("")}</ul></div>`:""}
    <p class="src">Källor: Göteborgs Stads lista över plan- och byggprojekt (samma uppgifter som projektsidorna på goteborg.se) och stadsbyggnadskontorets register över gällande planer. Uppdaterad ${dText(B.upd)}. Avstånd fågelvägen till den punkt staden angett för projektet. Där staden saknar punkt används gatan i projektets namn, märkt "cirka". Bygglov ingår inte än, eftersom staden inte publicerar dem som öppna data.</p>`;
  }).catch(()=>{host.innerHTML=`<div class="block"><h2>Bevakning ${UK}</h2></div><div class="notice">Uppgifterna om planarbete kunde inte laddas. Ladda om sidan och försök igen.</div>`;});}

/* ---- startsidan: lista över bevakningar ---- */
function renderStart(){const host=$("#bv-start");if(!host)return;const L=list();
  if(!L.length){host.hidden=true;return;}
  host.hidden=false;host.innerHTML=`<div class="bv-start"><span class="eyebrow">Dina bevakningar</span><ul>${L.map(o=>`<li><a href="${D?hashOf(o.k):"#a"+o.k+"-bevakning"}">${esc(o.l)}</a><span class="muted small" data-bv-n="${esc(o.l)}">inom ${fmtR(o.r)}</span></li>`).join("")}</ul></div>`;
  Promise.all([loadData(),data()]).then(([,B])=>{L.forEach(o=>{const el=host.querySelector(`[data-bv-n="${CSS.escape(o.l)}"]`),n=newFor(o,B).length;
    if(el&&n)el.innerHTML=`<span class="bv-new" style="margin:0">${n} ${n===1?"ny":"nya"}</span>`;});
    host.querySelectorAll("a").forEach((x,i)=>x.setAttribute("href",hashOf(L[i].k)));}).catch(()=>{});}

function refresh(){headBtn();navDot();if(document.body.contains($("#bv-start")))renderStart();
  const sec=mode==="basic"?$('section[data-bview="bevakning"]'):$('section[data-view="bevakning"]');if(sec&&!sec.hidden)render();}

document.addEventListener("click",e=>{const t=e.target.closest("[data-bv],[data-bv-r]");if(!t)return;const k=curIdx();if(k<0)return;
  if(t.dataset.bvR){setRadius(k,+t.dataset.bvR);return;}
  const act=t.dataset.bv;if(act==="toggle")toggle(k,(+($('.bv-radius [aria-pressed="true"]')||{}).dataset?.bvR)||1000);else if(act==="read")markRead(k);else if(act==="all"){showAll=true;render();}});

/* bevakningar ändrade i en annan flik */
addEventListener("storage",e=>{if(e.key===BV_KEY){mem=null;if(D)refresh();}});

/* kopplas in i portalens navigering */
const _go=go;go=function(view,opts){showAll=false;_go(view,opts);if(mode!=="start"&&D){headBtn();navDot();if(view==="bevakning")render();}};
const _open=openBasic;openBasic=function(k){_open(k);headBtn();navDot();};
const _start=showStart;showStart=function(){_start();renderStart();};
if(mode==="start")renderStart();else if(D)refresh();else loadData().then(refresh).catch(()=>{});
})();
