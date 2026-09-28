# -*- coding: utf-8 -*-
"""
아카이브생성.py — 리포트/ 폴더를 훑어 archive.json(주차 목록)을 만든다.

- weeknav.js 가 이 파일을 읽어 모든 리포트 페이지 상단에 주차 이동 바를 그린다.
- 자동생성.ps1 / 리포트생성.ps1 이 회차 생성 후 자동 호출한다. (수동: python 아카이브생성.py)
- 파일명 규칙 "YYYY년 N월 M주차 업계 동향 및 주요 이슈.html" 에 맞는 파일만 포함한다.
"""
import json
import re
import sys
from pathlib import Path

BASE = Path(__file__).resolve().parent
REPORT_DIR = BASE / "리포트"
OUT = BASE / "archive.json"

PAT = re.compile(r"^(\d{4})년 (\d{1,2})월 (\d)주차 .+\.html$")


def main():
    items = []
    for f in REPORT_DIR.glob("*.html"):
        m = PAT.match(f.name)
        if not m:
            continue  # report_2026-06-24.html 같은 구형 파일명은 제외
        y, mo, w = int(m.group(1)), int(m.group(2)), int(m.group(3))
        items.append({
            "label": f"{y}년 {mo}월 {w}주차",
            "file": f"리포트/{f.name}",
            "y": y, "m": mo, "w": w,
        })
    # 최신이 앞으로 오게 정렬
    items.sort(key=lambda x: (x["y"], x["m"], x["w"]), reverse=True)
    OUT.write_text(json.dumps({"reports": items}, ensure_ascii=False, indent=1), encoding="utf-8")
    # 콘솔 cp949 크래시 방지: ASCII 로만 출력
    sys.stdout.write("archive.json OK (%d reports)\n" % len(items))


if __name__ == "__main__":
    main()
