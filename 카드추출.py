# -*- coding: utf-8 -*-
import re,subprocess,io,sys
from concurrent.futures import ThreadPoolExecutor
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36"
URLS=[u.strip() for u in open("카드URL.txt",encoding="utf-8") if u.strip()]
OGI=re.compile(r'<meta[^>]+property=["\']og:image["\'][^>]*content=["\']([^"\']+)["\']',re.I)
OGI2=re.compile(r'<meta[^>]+content=["\']([^"\']+)["\'][^>]*property=["\']og:image["\']',re.I)
OGD=re.compile(r'<meta[^>]+property=["\']og:description["\'][^>]*content=["\']([^"\']*)["\']',re.I)
DM=re.compile(r'(?:article:published_time|datePublished)[^,>]{0,80}',re.I)
DA=re.compile(r'20\d{2}[-./]\d{2}[-./]\d{2}')
def fetch(u):
    o=subprocess.run(["curl","-sL","-A",UA,"--max-time","30",u],stdout=subprocess.PIPE,stderr=subprocess.DEVNULL)
    r=o.stdout
    for e in ("utf-8","euc-kr","cp949"):
        try: return r.decode(e)
        except UnicodeDecodeError: pass
    return r.decode("utf-8","replace")
def one(u):
    h=fetch(u)
    m=OGI.search(h) or OGI2.search(h); img=m.group(1) if m else ""
    d=OGD.search(h); desc=re.sub(r'\s+',' ',d.group(1)).strip() if d else ""
    dt=""; mm=DM.search(h)
    if mm:
        x=DA.search(mm.group(0))
        if x: dt=x.group(0).replace("/","-").replace(".","-")
    body=re.sub(r'<script.*?</script>|<style.*?</style>','',h,flags=re.S|re.I)
    body=re.sub(r'<[^>]+>',' ',body); body=re.sub(r'&[a-z]+;',' ',body); body=re.sub(r'\s+',' ',body)
    return u,dt,img,desc,body[:2600]
out=io.TextIOWrapper(sys.stdout.buffer,encoding="utf-8",errors="replace")
with ThreadPoolExecutor(max_workers=8) as ex: res=list(ex.map(one,URLS))
for u,dt,img,desc,body in res:
    out.write("### %s\nDATE: %s\nIMG: %s\nDESC: %s\nBODY: %s\n\n"%(u,dt,img,desc,body))
