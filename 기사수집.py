# -*- coding: utf-8 -*-
"""
매체 기사 목록 페이지를 직접 훑어 '수집 기간 안에 발행된' 기사만 뽑아낸다.

WebSearch는 날짜 필터가 없어 몇 달~1년 전 기사를 최신인 것처럼 돌려준다.
그래서 검색에 의존하지 않고, 각 매체의 최신 기사 목록을 직접 읽어
기사마다 원문 메타태그에서 발행일을 확인한 뒤 기간 안의 것만 남긴다.

사용법:
    python 기사수집.py 2026-06-29 2026-07-05
    python 기사수집.py 2026-06-29 2026-07-05 --media ktnews,apparelnews

결과: 표준출력에 TSV (발행일 / 매체 / 제목 / URL)
"""
import re, sys, io, subprocess
from concurrent.futures import ThreadPoolExecutor

UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36"

# (매체명, 목록 페이지들, 기사 링크 정규식, 링크 앞에 붙일 prefix)
# 매체 메인·1페이지에는 보통 최근 2~3일치만 걸린다.
# 지난 7일을 보려면 목록을 여러 페이지 넘겨야 하므로 PAGES 만큼 페이지네이션한다.
PAGES = 6

MEDIA = {
    # --- 티어1: 패션 ---
    "한국섬유신문": (
        ["https://www.ktnews.com/news/articleList.html?page=%d&view_type=sm" % p
         for p in range(1, PAGES + 1)],
        r'articleView\.html\?idxno=\d+', "https://www.ktnews.com/news/"),
    "어패럴뉴스": (
        ["https://www.apparelnews.co.kr/news/news_list/?cat=%s&page=%d" % (c, p)
         for c in ("CAT100", "CAT114", "CAT160") for p in range(1, 4)],
        r'news_view/\?idx=\d+', "https://www.apparelnews.co.kr/news/"),
    # --- 티어1: 커머스·경제·IT ---
    "전자신문": (
        ["https://www.etnews.com/"] +
        ["https://www.etnews.com/news/section/economy?page=%d" % p for p in range(1, 4)],
        r'(?<=href=")/2026\d{7}', "https://www.etnews.com"),
    "이투데이": (
        ["https://www.etoday.co.kr/"] +
        ["https://www.etoday.co.kr/news/section/subsection?mid=%d&page=%d" % (m, p)
         for m in (4,) for p in range(1, 4)],
        r'news/view/\d{6,}', "https://www.etoday.co.kr/"),
    "디지털데일리": (
        ["https://www.ddaily.co.kr/"] +
        ["https://www.ddaily.co.kr/page/list/?page=%d" % p for p in range(1, 4)],
        r'page/view/\d{10,}', "https://www.ddaily.co.kr/"),
    "바이라인네트워크": (
        ["https://byline.network/"] +
        ["https://byline.network/page/%d/" % p for p in range(2, PAGES + 1)],
        r'https://byline\.network/2026/\d{2}/[0-9a-z_\-]+/', ""),
    # --- 티어2: 뷰티 전문지 (시장·규제·원료 기사만 채택할 것) ---
    "코스인코리아": (
        ["https://www.cosinkorea.com/news/articleList.html?page=%d&view_type=sm" % p
         for p in range(1, PAGES + 1)],
        r'article\.html\?no=\d+', "https://www.cosinkorea.com/news/"),
    "코스모닝": (
        ["https://www.cosmorning.com/news/articleList.html?page=%d&view_type=sm" % p
         for p in range(1, PAGES + 1)],
        r'article\.html\?no=\d+', "https://www.cosmorning.com/news/"),
}

DATE_META = re.compile(
    r'(?:article:published_time|datePublished|"dateCreated")[^,>]{0,80}', re.I)
DATE_ANY = re.compile(r'20\d{2}[-./]\d{2}[-./]\d{2}')
OG_TITLE = re.compile(r'<meta[^>]+og:title[^>]*content="([^"]*)"', re.I)
TITLE_TAG = re.compile(r'<title[^>]*>([^<]*)</title>', re.I)


def fetch(url, timeout=20):
    """curl로 받는다. 일부 매체가 파이썬 기본 UA/헤더를 막기 때문."""
    out = subprocess.run(
        ["curl", "-sL", "-A", UA, "--max-time", str(timeout), url],
        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    raw = out.stdout
    for enc in ("utf-8", "euc-kr", "cp949"):
        try:
            return raw.decode(enc)
        except UnicodeDecodeError:
            continue
    return raw.decode("utf-8", "replace")


def article_info(url):
    """기사 URL -> (발행일 'YYYY-MM-DD', 제목).  실패 시 (None, None)"""
    try:
        html = fetch(url)
    except Exception:
        return None, None
    d = None
    m = DATE_META.search(html)
    if m:
        dm = DATE_ANY.search(m.group(0))
        if dm:
            d = dm.group(0)
    if not d:
        dm = DATE_ANY.search(html)
        d = dm.group(0) if dm else None
    if d:
        d = d.replace("/", "-").replace(".", "-")
    t = OG_TITLE.search(html) or TITLE_TAG.search(html)
    title = re.sub(r'\s+', ' ', t.group(1)).strip() if t else ""
    return d, title


def collect(media_names, dfrom, dto):
    rows = []
    for name in media_names:
        list_urls, pat, prefix = MEDIA[name]
        links = []
        for lu in list_urls:
            try:
                html = fetch(lu, timeout=25)
            except Exception as e:
                print("  ! 목록 실패 %s (%s)" % (lu, e), file=sys.stderr)
                continue
            for m in re.findall(pat, html):
                u = m if m.startswith("http") else prefix + m
                if u not in links:
                    links.append(u)
        links = links[:120]
        print("  %s: 링크 %d개 검사" % (name, len(links)), file=sys.stderr)

        with ThreadPoolExecutor(max_workers=12) as ex:
            infos = list(ex.map(article_info, links))
        for u, (d, t) in zip(links, infos):
            if d and dfrom <= d <= dto and t:
                rows.append((d, name, t, u))
    rows.sort()
    return rows


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if len(args) < 2:
        print(__doc__)
        sys.exit(1)
    dfrom, dto = args[0], args[1]
    names = list(MEDIA)
    for a in sys.argv[1:]:
        if a.startswith("--media"):
            want = a.split("=", 1)[-1] if "=" in a else ""
            if want:
                names = [n for n in MEDIA if n in want or
                         any(k in want.split(",") for k in [n])]
    print("수집 기간: %s ~ %s" % (dfrom, dto), file=sys.stderr)
    rows = collect(names, dfrom, dto)
    print("\n기간 내 기사 %d건\n" % len(rows), file=sys.stderr)
    out = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
    for d, name, t, u in rows:
        out.write("%s\t%s\t%s\t%s\n" % (d, name, t, u))
    out.flush()


if __name__ == "__main__":
    main()
