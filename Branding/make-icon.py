import math
def squircle(x0,y0,size,n=5.0,N=360):
    c=size/2; pts=[]
    for i in range(N):
        t=2*math.pi*i/N; ct,st=math.cos(t),math.sin(t)
        x=abs(ct)**(2/n)*(1 if ct>=0 else -1); y=abs(st)**(2/n)*(1 if st>=0 else -1)
        pts.append((x0+c+c*x,y0+c+c*y))
    return 'M'+' L'.join(f'{a:.2f} {b:.2f}' for a,b in pts)+' Z'
T=squircle(100,100,824)
bolt='M566 188 L326 566 L486 566 L448 836 L700 446 L536 446 Z'
tiles=''
pos=[(250,250),(530,250),(250,530),(530,530)]
for i,(x,y) in enumerate(pos):
    tiles+=f'<rect x="{x}" y="{y}" width="244" height="244" rx="62" fill="url(#tileG)" stroke="#fff" stroke-opacity=".35" stroke-width="3"/>'
svg=f'''<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024"><defs>
<linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#FF5A8A"/><stop offset=".55" stop-color="#FF6A3D"/><stop offset="1" stop-color="#FF9A1F"/></linearGradient>
<radialGradient id="hl" cx="300" cy="180" r="620" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#fff" stop-opacity=".28"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient>
<linearGradient id="tileG" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".30"/><stop offset="1" stop-color="#fff" stop-opacity=".12"/></linearGradient>
<linearGradient id="w" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFFFFF"/><stop offset="1" stop-color="#FFE7D9"/></linearGradient>
<linearGradient id="side" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFC9A8"/><stop offset="1" stop-color="#E8572B"/></linearGradient>
<filter id="ts" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="12" stdDeviation="14" flood-color="#000" flood-opacity=".3"/></filter>
<filter id="lift" x="-40%" y="-40%" width="180%" height="180%"><feDropShadow dx="0" dy="22" stdDeviation="22" flood-color="#7A1A08" flood-opacity=".45"/></filter>
<filter id="blur"><feGaussianBlur stdDeviation="2"/></filter>
<clipPath id="clip"><path d="{T}"/></clipPath></defs>
<path d="{T}" fill="url(#bg)" filter="url(#ts)"/>
<g clip-path="url(#clip)">
  <rect width="1024" height="1024" fill="url(#hl)"/>
  {tiles}
  <g filter="url(#lift)">
    <path d="{bolt}" fill="url(#side)" stroke="url(#side)" stroke-width="22" stroke-linejoin="round" transform="translate(10 18)"/>
    <path d="{bolt}" fill="url(#w)" stroke="url(#w)" stroke-width="22" stroke-linejoin="round"/>
  </g>
  <path d="M566 188 L326 566 L380 566 L566 236 Z" fill="#fff" opacity=".55" filter="url(#blur)"/>
</g>
<path d="{T}" fill="none" stroke="#fff" stroke-opacity=".2" stroke-width="3"/></svg>'''
open('icon.svg','w').write(svg)
mb='''<svg xmlns="http://www.w3.org/2000/svg" width="72" height="72" viewBox="0 0 18 18">
<mask id="m"><rect width="18" height="18" fill="#fff"/><path d="M10.2 1.6 L5.2 9.6 L8.6 9.6 L7.8 16.4 L13 8.2 L9.6 8.2 Z" fill="#000" stroke="#000" stroke-width="3" stroke-linejoin="round"/></mask>
<g mask="url(#m)" fill="none" stroke="#000" stroke-width="1.3">
<rect x="1.6" y="1.6" width="6.4" height="6.4" rx="1.8"/><rect x="10" y="1.6" width="6.4" height="6.4" rx="1.8"/>
<rect x="1.6" y="10" width="6.4" height="6.4" rx="1.8"/><rect x="10" y="10" width="6.4" height="6.4" rx="1.8"/></g>
<path d="M10.2 1.6 L5.2 9.6 L8.6 9.6 L7.8 16.4 L13 8.2 L9.6 8.2 Z" fill="#000" stroke="#000" stroke-width="0.8" stroke-linejoin="round"/>
</svg>'''
open('menubar-icon.svg','w').write(mb)
