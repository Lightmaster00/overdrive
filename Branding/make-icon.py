import math
def squircle(x0,y0,size,n=5.0,N=360):
    c=size/2; pts=[]
    for i in range(N):
        t=2*math.pi*i/N; ct,st=math.cos(t),math.sin(t)
        x=abs(ct)**(2/n)*(1 if ct>=0 else -1); y=abs(st)**(2/n)*(1 if st>=0 else -1)
        pts.append((x0+c+c*x,y0+c+c*y))
    return 'M'+' L'.join(f'{a:.2f} {b:.2f}' for a,b in pts)+' Z'
tile=squircle(100,100,824)
cx,cy=512,575; R=300
def pol(r,deg):  # deg: 0 = right, counterclockwise, svg y down
    a=math.radians(deg); return cx+r*math.cos(a), cy-r*math.sin(a)
def arcpath(r,a0,a1):
    x0,y0=pol(r,a0); x1,y1=pol(r,a1)
    large=1 if abs(a0-a1)>180 else 0
    return f'M{x0:.1f} {y0:.1f} A{r} {r} 0 {large} 1 {x1:.1f} {y1:.1f}'
ticks=''
for i in range(0,13):
    deg=210-i*20
    major = i%2==0
    r0 = R-46 if major else R-34
    x0,y0=pol(r0,deg); x1,y1=pol(R-14,deg)
    red = deg<=10
    col = '#FF4D3D' if red else '#E9E6F2'
    ticks+=f'<line x1="{x0:.1f}" y1="{y0:.1f}" x2="{x1:.1f}" y2="{y1:.1f}" stroke="{col}" stroke-width="{14 if major else 8}" stroke-linecap="round" opacity="{1 if red else .85}"/>\n'
needle_deg=18
nx,ny=pol(R-40,needle_deg)
bx1,by1=pol(22,needle_deg+90); bx2,by2=pol(22,needle_deg-90); tx,ty=pol(60,needle_deg+180)
svg=f'''<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
<defs>
  <linearGradient id="tile" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#2E313B"/><stop offset="1" stop-color="#121318"/></linearGradient>
  <linearGradient id="scale" gradientUnits="userSpaceOnUse" x1="{cx-R}" y1="0" x2="{cx+R}" y2="0">
    <stop offset="0" stop-color="#36C5F0"/><stop offset=".55" stop-color="#FFB020"/><stop offset=".8" stop-color="#FF6A1A"/><stop offset="1" stop-color="#FF2D55"/>
  </linearGradient>
  <radialGradient id="glow" cx="{pol(R,20)[0]:.0f}" cy="{pol(R,20)[1]:.0f}" r="330" gradientUnits="userSpaceOnUse">
    <stop offset="0" stop-color="#FF3B30" stop-opacity=".55"/><stop offset="1" stop-color="#FF3B30" stop-opacity="0"/>
  </radialGradient>
  <linearGradient id="needle" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#FF8A3D"/><stop offset="1" stop-color="#FF2D55"/></linearGradient>
  <radialGradient id="cap" cx="{cx-14}" cy="{cy-18}" r="70" gradientUnits="userSpaceOnUse">
    <stop offset="0" stop-color="#FFFFFF"/><stop offset=".55" stop-color="#C9CBD3"/><stop offset="1" stop-color="#6E717C"/>
  </radialGradient>
  <linearGradient id="sheen" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".12"/><stop offset=".45" stop-color="#fff" stop-opacity="0"/></linearGradient>
  <filter id="tileShadow" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="12" stdDeviation="14" flood-color="#000" flood-opacity=".35"/></filter>
  <filter id="soft" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="10" stdDeviation="10" flood-color="#000" flood-opacity=".5"/></filter>
  <filter id="neon" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation="9" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
  <clipPath id="clip"><path d="{tile}"/></clipPath>
</defs>
<path d="{tile}" fill="url(#tile)" filter="url(#tileShadow)"/>
<g clip-path="url(#clip)">
  <rect width="1024" height="1024" fill="url(#glow)"/>
  <path d="{arcpath(R,210,-30)}" fill="none" stroke="#000" stroke-opacity=".35" stroke-width="40" stroke-linecap="round"/>
  <path d="{arcpath(R,210,-30)}" fill="none" stroke="url(#scale)" stroke-width="30" stroke-linecap="round" filter="url(#neon)"/>
  {ticks}
  <g filter="url(#soft)">
    <path d="M{bx1:.1f} {by1:.1f} L{nx:.1f} {ny:.1f} L{bx2:.1f} {by2:.1f} L{tx:.1f} {ty:.1f} Z" fill="url(#needle)" stroke="#FF2D55" stroke-width="4" stroke-linejoin="round"/>
    <circle cx="{cx}" cy="{cy}" r="58" fill="url(#cap)"/>
    <circle cx="{cx}" cy="{cy}" r="58" fill="none" stroke="#fff" stroke-opacity=".5" stroke-width="3"/>
    <circle cx="{cx}" cy="{cy}" r="16" fill="#2E313B"/>
  </g>
  <rect width="1024" height="1024" fill="url(#sheen)"/>
</g>
<path d="{tile}" fill="none" stroke="#fff" stroke-opacity=".12" stroke-width="3"/>
</svg>'''
open('icon.svg','w').write(svg)
