# ============================================================
#  미디어커머스 업계 동향 - 주간 리포트 생성 (수동 실행)
#  사용법: 같은 폴더의 "리포트생성.bat" 더블클릭 (또는 이 .ps1 직접 실행)
#  동작:  이 폴더에서 Claude를 대화형으로 열어 CLAUDE.md 지시문대로
#         지난 7일 동향을 수집해 '리포트' 폴더에 카드뉴스 리포트를 생성합니다.
# ============================================================

$ErrorActionPreference = "Stop"
chcp 65001 > $null   # 한글 출력 깨짐 방지(UTF-8)

# 이 스크립트가 있는 폴더 = 작업 폴더 (CLAUDE.md 가 있는 곳)
$workDir = $PSScriptRoot
Set-Location $workDir

# 리포트 저장 폴더 (없으면 생성)
$reportDir = Join-Path $workDir "리포트"
if (-not (Test-Path $reportDir)) { New-Item -ItemType Directory -Path $reportDir | Out-Null }

# 7일 수집창(시작일~시작일+6)에서 '더 많은 날을 차지하는 달'을 "YYYY-MM" 으로 반환
# (월 경계에 걸친 주는 다수결로 한쪽 달에 귀속. 7일은 항상 한 달이 과반)
function Get-OwningMonthKey([datetime]$start) {
    $counts = @{}
    for ($i = 0; $i -lt 7; $i++) {
        $d = $start.AddDays($i)
        $k = "{0:0000}-{1:00}" -f $d.Year, $d.Month
        if ($counts.ContainsKey($k)) { $counts[$k]++ } else { $counts[$k] = 1 }
    }
    ($counts.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1).Key
}

# 날짜 계산: 오늘 / 수집 창(지난 7일 = 시작일 ~ 시작일+6)
$today     = Get-Date
$todayStr  = $today.ToString("yyyy-MM-dd")
$startDate = $today.AddDays(-7)
$endDate   = $startDate.AddDays(6)
$fromStr   = $startDate.ToString("yyyy-MM-dd")
$toStr     = $endDate.ToString("yyyy-MM-dd")

# 이 주가 '속한 달' = 7일 중 더 많은 날을 차지하는 달 (월 경계는 다수결)
$ownKey   = Get-OwningMonthKey $startDate
$ownYear  = [int]$ownKey.Substring(0,4)
$ownMonth = [int]$ownKey.Substring(5,2)
# 주차 = 같은 달에 속한 직전 주들을 거슬러 세어 매긴 순번 (매주 월요일 실행 가정)
$week  = 1
$probe = $startDate.AddDays(-7)
while ((Get-OwningMonthKey $probe) -eq $ownKey) {
    $week++
    $probe = $probe.AddDays(-7)
}
$weekLabel = "${ownMonth}월 ${week}주차 핵심 이슈"
# 파일명: "2026년 7월 1주차 업계 동향 및 주요 이슈.html"
$baseName  = "${ownYear}년 ${ownMonth}월 ${week}주차 업계 동향 및 주요 이슈"
$outName   = "$baseName.html"
$outRel   = "리포트/$outName"
$outFull  = Join-Path $reportDir $outName

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  미디어커머스 업계 동향 - 주간 리포트 생성" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  작업 폴더 : $workDir"
Write-Host "  수집 기간 : $fromStr ~ $toStr (지난 7일)"
Write-Host "  결과 파일 : $outRel"
Write-Host "--------------------------------------------------"

# 이미 오늘자 리포트가 있으면 안내
if (Test-Path $outFull) {
    Write-Host "  [안내] 오늘자 리포트($outRel)가 이미 있습니다. 진행하면 갱신/덮어쓸 수 있어요." -ForegroundColor Yellow
}

# claude CLI 확인
$claude = Get-Command claude -ErrorAction SilentlyContinue
if (-not $claude) {
    Write-Host "  [오류] 'claude' 명령을 찾을 수 없습니다. Claude Code CLI 설치/로그인 상태를 확인하세요." -ForegroundColor Red
    Read-Host "  엔터를 누르면 종료합니다"
    exit 1
}

# Claude 에게 전달할 작업 지시 (CLAUDE.md + 최신 카드뉴스 템플릿을 따르게 함)
$prompt = @"
이 폴더의 CLAUDE.md 지시문에 따라 이번 회차 '미디어커머스 업계 동향 주간 리포트'를 생성해줘.

[이번 회차 조건]
- 수집 기간: $fromStr ~ $toStr (지난 7일)
- 추적 카테고리 4개(화장품/뷰티, 아이웨어+패션잡화, 뷰티 디바이스, 미디어커머스 공통) 모두 다룬다.
- 각 카테고리에서 신제품/런칭, 경쟁사 캠페인, 플랫폼·정책 변화, 규제·인증 이슈, 소비 트렌드를 웹에서 검색·수집한다.
- 중복·단순 광고성 기사를 제거하고 자사 브랜드 관련성이 높은 순으로 정리한다.
- 카테고리당 카드 6~7개를 목표로 한다.

[수집 - 검색보다 기사수집.py 를 먼저 돌린다]
- `python 기사수집.py $fromStr $toStr` 를 실행하면 매체 목록 페이지를 직접 훑어 기간 내 발행 기사만 TSV로 뽑아준다.
- 이 결과를 1차 후보로 쓰고, 카드가 모자란 카테고리만 웹 검색으로 보완한다.

[수집 창 - 전 섹션 '지난 7일' 엄수]
- 네 섹션 모두 $fromStr ~ $toStr 에 발행된 기사만 쓴다. 창 밖 기사는 내용이 좋아도 채택하지 않는다.
- 빈자리를 옛날 기사로 메우지 않는다. 카드가 모자라면 검색 소스를 넓히지, 기간을 늘리지 않는다.

[발행일 검증 - 가장 중요. 이 단계를 건너뛰지 말 것]
- 웹 검색 결과는 최신성을 보장하지 않는다. 관련성이 높아 보여도 몇 달~1년 전 기사가 섞여 나온다.
- 카드로 확정하기 전에 기사마다 원문 HTML에서 발행일을 뽑아 $fromStr ~ $toStr 안인지 반드시 확인한다.
  예) curl -sL -A "Mozilla/5.0" "URL" | grep -ioE '<meta[^>]+(article:published_time|datePublished)[^>]*>'
  메타태그가 없으면 본문 상단 '기사입력일'을 확인하고, 그래도 확인이 안 되면 그 기사는 버린다.
- 발행일은 카드 하단 바에 YYYY.MM.DD 로 표시한다.

[매체 티어 - 금지 목록이 아니라 '채우는 순서'. 상위부터 채우고 모자라면 내려간다]
- 티어는 우선순위다. 어느 티어에서 가져오든 아래 광고성 배제 기준은 예외 없이 적용한다.
  티어가 낮다고 버리는 게 아니라, 광고성이면 버린다. 같은 사안이면 항상 상위 티어 기사를 링크한다.
- 티어1(여기서 먼저 채운다): 전자신문, 서울경제, 매일경제, 한국경제, 이투데이, 대한경제, 시사저널e, 디지털데일리,
  바이라인네트워크, 플래텀, 아웃스탠딩, 모비인사이드, 어패럴뉴스, 패션비즈, 한국섬유신문
- 티어2(티어1에 없는 이슈를 메운다): 코스인코리아, 코스모닝, 장업신문, 뷰티경제, 뷰티누리
  → 원료·규제·시장 데이터는 오히려 여기가 빠르고 깊다. 적극 쓴다. 단일 브랜드 홍보성 기사만 광고성 기준으로 거른다.
- 티어3(위에서 못 채웠을 때만, 대신 더 깐깐하게): 중앙이코노미뉴스, AI마케팅뉴스, 신아일보, 천지일보, 플라넷뉴스,
  엘르·코스모폴리탄 등 → 그 이슈를 티어1·2가 아무도 안 다뤘고 기사 내용 자체가 시장·정책·트렌드 정보일 때만 채택하고,
  본문 사실관계를 다른 출처로 한 번 더 확인한다.
- 블로그·브랜드 자사 뉴스룸·쇼핑몰 페이지는 기사가 아니라 홍보물이므로 쓰지 않는다.

[광고성 배제 - 티어 무관, 하나라도 걸리면 버린다]
- 보도자료를 거의 그대로 실어 기자의 해석·비교·업계 코멘트가 없다
- 특정 브랜드 하나의 출시·할인·판매량 자랑이 본문의 중심이다
- 수치의 출처가 그 브랜드 자체 발표뿐이고 제3자 데이터가 없다
- 본문에 구매 링크·판매 채널·가격·프로모션 기간이 안내돼 있다
- 제목이 '대박', '폭증', '완판', '1위 등극' 같은 홍보 문구다

[카드가 모자랄 때 - 기간은 절대 늘리지 않는다. 순서대로 시도]
1) 티어1 안에서 검색어를 바꿔 다시 찾는다(브랜드명·제도명·수치 키워드)
2) 티어2로 내려간다
3) 인접 주제로 넓힌다(예: 아이웨어가 없으면 패션잡화·디자인 IP·소재 트렌드)
4) 해외 매체를 본다
5) 티어3에서 위 조건을 만족하는 기사를 찾는다
→ 그래도 안 되면 그 섹션은 카드 수가 적은 채로 낸다. 옛날 기사로 메우지 않는다.

[디자인 - 반드시 기존 템플릿을 그대로 따른다]
- 디자인 템플릿: 루트 index.html (직전 회차 = 현재 카드뉴스 디자인)
- 이 파일의 HTML/CSS 구조를 그대로 복제해서 내용만 이번 회차로 교체한다.
- 카드 구조: 이미지(200px)가 카드 상단을 차지하고 그 위에 카테고리 컬러 태그(우상단)와 제목(흰 글씨, 최대 3줄)을 얹는다
  → 흰 본문에 요약(3줄) → 시사점 → 하단 구분선 아래 출처
- 카드 전체가 클릭되어 기사로 이동하도록 stretched-link CSS(.card position:relative + .card-foot a::after)를 유지한다.
- <head> 안에 검색엔진 색인 차단용 <meta name="robots" content="noindex, nofollow" /> 를 반드시 포함한다.

[시사점 문체 - AI 말투 금지]
- 사람이 회의에서 말하듯 담백한 평서문으로 쓴다. 서술어로 끝낸다. ('~한다', '~해야 한다', '~하는 편이 낫다', '~볼 만하다')
- 금지: 개조식 명사 종결('~선점.', '~배치.', '~검토.', '~공략.'), 컨설팅 버즈워드(USP, 포트폴리오, 채널 믹스, 이원화, 서사화, 세계관, 벤치마킹, 로드맵, 포지셔닝),
  문장을 잇는 대시(—), 단어를 욱여넣는 '+'·중점 나열, 라벨의 이모지(💡).
- 라벨은 <b>시사점</b> 으로만 쓴다. 한 카드에 한두 문장, 40~60자.

[카드 이미지 - 기사 썸네일 자동 추출]
- 각 기사 원문 URL의 대표 이미지(og:image)를 카드 배경으로 사용한다.
- 추출 방법: 원본 HTML을 받아 og:image 메타태그를 파싱한다. (WebFetch는 head를 버리므로 사용 금지)
  예) curl -sL -A "Mozilla/5.0" "URL" | grep -ioE '<meta[^>]+property=.?og:image.?[^>]*>'
  한글 포함 이미지 URL은 percent-encoding 처리한다.
- 깨질 경우 대비해 background-image 를 url(썸네일), 카테고리 그라데이션 2겹으로 지정한다.

[산출물]
- '$outRel' 파일로 저장한다. (리포트 폴더 안)
- 상단 헤더: 생성일 / 수집 기간 / 핵심 헤드라인 5개(번호 배지). 담당 브랜드 줄은 넣지 않는다.
- 헤드라인 라벨 문구는 '$weekLabel' 로 한다.
- 작업이 끝나면 '$outRel' 내용을 루트의 index.html 로도 복사해 최신본을 갱신한다.

모든 설명과 출력은 한국어로 한다. 작업을 시작하기 전에 간단히 계획만 한 줄로 알려주고 바로 진행해줘.
"@

Write-Host "  Claude를 실행합니다. 진행 상황을 보면서 필요 시 승인/수정하세요." -ForegroundColor Green
Write-Host "  (작업이 끝나면 $outRel 와 index.html 이 만들어집니다.)"
Write-Host "=================================================="
Write-Host ""

# Claude 대화형 실행 (초기 프롬프트 주입). 작업 폴더의 CLAUDE.md 가 컨텍스트로 로드됨.
& claude $prompt

Write-Host ""
Write-Host "--------------------------------------------------"
if (Test-Path $outFull) {
    Write-Host "  [완료] $outRel 생성됨." -ForegroundColor Green
} else {
    Write-Host "  [안내] $outRel 가 보이지 않습니다. Claude 세션에서 생성이 끝났는지 확인하세요." -ForegroundColor Yellow
}
Write-Host "=================================================="

# === 사이트 발행 (GitHub Pages) ===
if (Test-Path $outFull) {
    Write-Host ""
    $pub = Read-Host "  방금 만든 리포트를 사이트에 발행할까요? (Y/N)"
    if ($pub -match '^[Yy]') {
        Write-Host "  발행 중..." -ForegroundColor Cyan
        git -C $workDir add -A
        if (git -C $workDir status --porcelain) {
            git -C $workDir commit -m "리포트 발행: $baseName" | Out-Null
        }
        git -C $workDir push origin main
        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Host "  [발행 완료] https://withbrothersjsa.github.io/media-report/" -ForegroundColor Green
            Write-Host "  (사이트 반영까지 1~2분 정도 걸립니다)"
        } else {
            Write-Host "  [발행 실패] GitHub Desktop을 열어 Commit 후 Push 해주세요." -ForegroundColor Yellow
        }
    } else {
        Write-Host "  발행은 건너뜁니다. (나중에 GitHub Desktop에서 Push 가능)" -ForegroundColor Yellow
    }
    Write-Host "=================================================="
}

Read-Host "  엔터를 누르면 창을 닫습니다"
