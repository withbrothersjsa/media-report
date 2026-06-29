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

[디자인 - 반드시 기존 템플릿을 그대로 따른다]
- 디자인 템플릿: 루트 index.html (직전 회차 = 현재 카드뉴스 디자인)
- 이 파일의 HTML/CSS 구조를 그대로 복제해서 내용만 이번 회차로 교체한다.
- 카드 구조: 상단 이미지 + 카테고리 컬러 태그 → 제목(2줄) → 요약(3줄) → 💡시사점 → 출처
- 카드 전체가 클릭되어 기사로 이동하도록 stretched-link CSS(.card position:relative + .card-link a::after)를 유지한다.
- <head> 안에 검색엔진 색인 차단용 <meta name="robots" content="noindex, nofollow" /> 를 반드시 포함한다.

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
