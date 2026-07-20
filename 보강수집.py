# -*- coding: utf-8 -*-
import re, sys, io, subprocess
from concurrent.futures import ThreadPoolExecutor
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36"
MEDIA={
 "뷰티누리":(["https://www.beautynury.com/news/list/cat/10/page/%d"%p for p in range(1,6)]+
            ["https://www.beautynury.com/news/list/cat/1/page/%d"%p for p in range(1,4)],
            r'/news/view/\d+/cat/\d+',"https://www.beautynury.com"),
 "시사저널e":(["https://www.sisajournal-e.com/news/articleList.html?page=%d&view_type=sm"%p for p in range(1,7)],
            r'articleView\.html\?idxno=\d+',"https://www.sisajournal-e.com/news/"),
 "장업신문":(["https://www.jangup.com/news/articleList.html?page=%d&view_type=sm"%p for p in range(1,6)],
            r'articleView\.html\?idxno=\d+',"https://www.jangup.com/news/"),
 "전자신문":(["https://www.etnews.com/news/section/it?page=%d"%p for p in range(1,4)]+
            ["https://www.etnews.com/news/section/economy?page=%d"%p for p in range(1,4)],
            r'(?<=href=")/2026\d{7}',"https://www.etnews.com"),
}
DATE_META=re.compile(r'(?:article:published_time|datePublished|"dateCreated")[^,>]{0,80}',re.I)
DATE_ANY=re.compile(r'20\d{2}[-./]\d{2}[-./]\d{2}')
OG=re.compile(r'<meta[^>]+og:title[^>]*content="([^"]*)"',re.I)
TT=re.compile(r'<title[^>]*>([^<]*)</title>',re.I)
def fetch(u,t=20):
    o=subprocess.run(["curl","-sL","-A",UA,"--max-time",str(t),u],stdout=subprocess.PIPE,stderr=subprocess.DEVNULL)
    r=o.stdout
    for e in ("utf-8","euc-kr","cp949"):
        try: return r.decode(e)
        except UnicodeDecodeError: pass
    return r.decode("utf-8","replace")
def info(u):
    try: h=fetch(u)
    except Exception: return None,None
    d=None; m=DATE_META.search(h)
    if m:
        x=DATE_ANY.search(m.group(0))
        if x: d=x.group(0)
    if not d:
        x=DATE_ANY.search(h); d=x.group(0) if x else None
    if d: d=d.replace("/","-").replace(".","-")
    t=OG.search(h) or TT.search(h)
    return d,(re.sub(r'\s+',' ',t.group(1)).strip() if t else "")
df,dt=sys.argv[1],sys.argv[2]
out=io.TextIOWrapper(sys.stdout.buffer,encoding="utf-8",errors="replace")
for name,(urls,pat,pre) in MEDIA.items():
    links=[]
    for lu in urls:
        try: h=fetch(lu,25)
        except Exception: continue
        for m in re.findall(pat,h):
            u=m if m.startswith("http") else pre+m
            if u not in links: links.append(u)
    links=links[:130]
    print("  %s: %d개 검사"%(name,len(links)),file=sys.stderr)
    with ThreadPoolExecutor(max_workers=12) as ex: infos=list(ex.map(info,links))
    for u,(d,t) in zip(links,infos):
        if d and df<=d<=dt and t: out.write("%s\t%s\t%s\t%s\n"%(d,name,t,u))
    out.flush()
