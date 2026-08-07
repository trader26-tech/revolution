import math, itertools, random
random.seed(31)
side=300.0
LOGOS=[[("Netflix",42),("Spotify",44),("YouTube",40)],
       [("Groww",38),("DigiLocker",36),("Upstox",36)],
       [("LIC",46),("HDFC",38),("SBI",38)]]
LIMIT=0.5*side-3
PAD=0.020   # gap between ring outlines (fraction)

def evaluate(p):
    # p = [c0x,c0y,r0,ph0,  c1x,c1y,r1,ph1,  c2x,c2y,r2,ph2]
    rings=[(p[0],p[1],p[2]),(p[4],p[5],p[6]),(p[8],p[9],p[10])]
    phases=[p[3],p[7],p[11]]
    if rings[0][2]<0.20 or rings[1][2]<0.14 or rings[2][2]<0.17: return None
    if rings[0][2]<=rings[1][2] or rings[0][2]<=rings[2][2]: return None
    # composition: big upper-left, small upper-right, mid lower-right
    if not (rings[0][0]<-0.02 and rings[0][1]<0.03): return None
    if not (rings[1][0]> 0.02 and rings[1][1]<0.00): return None
    if not (rings[2][0]> 0.00 and rings[2][1]>0.05): return None
    # rings disjoint
    for (x1,y1,r1),(x2,y2,r2) in itertools.combinations(rings,2):
        if math.hypot(x1-x2,y1-y2) < r1+r2+PAD: return None
    pts=[]; placed=[]
    for i,((cx,cy,r),ph) in enumerate(zip(rings,phases)):
        pts.append((f"hub{i}",cx*side,cy*side,r*side*0.62))
        for k,(ln,ls) in enumerate(LOGOS[i]):
            a=math.radians(ph+k*120.0)
            x=(cx+r*math.cos(a))*side; y=(cy+r*math.sin(a))*side
            pts.append((ln,x,y,ls)); placed.append((i,ln,x,y,ls))
    for n,x,y,s in pts:
        if abs(x)+s/2>LIMIT or abs(y)+s/2>LIMIT: return None
    for i,ln,x,y,ls in placed:
        for j,(cx2,cy2,r2) in enumerate(rings):
            if j==i: continue
            d=math.hypot(x-cx2*side,y-cy2*side)
            if abs(d-r2*side) < ls/2+5: return None
    clear=min(math.hypot(x1-x2,y1-y2)-(s1+s2)/2
              for (n1,x1,y1,s1),(n2,x2,y2,s2) in itertools.combinations(pts,2))
    area=sum(r*r for _,_,r in rings)
    return clear + area*6      # prefer clearance, keep rings big

best=None;bestS=-1e9
for _ in range(1500000):
    p=[random.uniform(-.32,-.05), random.uniform(-.32,.02), random.uniform(.20,.27), random.uniform(0,120),
       random.uniform(.05,.34),  random.uniform(-.34,-.02), random.uniform(.14,.21), random.uniform(0,120),
       random.uniform(.02,.30),  random.uniform(.06,.32),  random.uniform(.17,.25), random.uniform(0,120)]
    s=evaluate(p)
    if s is not None and s>bestS: bestS,best=s,p[:]
for _ in range(600000):
    c=[v+random.gauss(0,0.008 if (i%4)!=3 else 2.5) for i,v in enumerate(best)]
    s=evaluate(c)
    if s is not None and s>bestS: bestS,best=s,c[:]

names=["Subs","Invest","Insure"]
rings=[(best[0],best[1],best[2]),(best[4],best[5],best[6]),(best[8],best[9],best[10])]
phases=[best[3],best[7],best[11]]
print(f"score={bestS:.3f}")
for i,n in enumerate(names):
    cx,cy,r=rings[i]; ph=phases[i]%360
    print(f"  {n:7s} cxF={cx:+.3f} cyF={cy:+.3f} rF={r:.3f} phase={ph:.1f}")
    for k,(ln,ls) in enumerate(LOGOS[i]):
        print(f"        {ln:11s} angle={(ph+k*120)%360:6.1f}")
for (n1,(x1,y1,r1)),(n2,(x2,y2,r2)) in itertools.combinations(list(zip(names,rings)),2):
    print(f"  {n1}<->{n2} outline gap={math.hypot(x1-x2,y1-y2)-r1-r2:+.3f}")
# report true min clearance
pts=[]
for i,((cx,cy,r),ph) in enumerate(zip(rings,phases)):
    pts.append((f"hub{i}",cx*side,cy*side,r*side*0.62))
    for k,(ln,ls) in enumerate(LOGOS[i]):
        a=math.radians(ph+k*120.0)
        pts.append((ln,(cx+r*math.cos(a))*side,(cy+r*math.sin(a))*side,ls))
print("min clearance:", round(min(math.hypot(x1-x2,y1-y2)-(s1+s2)/2
      for (n1,x1,y1,s1),(n2,x2,y2,s2) in itertools.combinations(pts,2)),1),"px")
