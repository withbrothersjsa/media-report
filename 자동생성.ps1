# ============================================================
#  미디어커머스 업계 동향 - 주간 리포트 '무인 자동 생성' (스케줄러용)
#  용도:  작업 스케줄러가 월요일 오전에 이 스크립트를 실행 → 사람 없이
#         Claude(headless)가 지난 7일 동향을 수집해 리포트를 생성하고
#         index.html(최신본)까지 갱신한다. ※ 발행(push)은 하지 않음(반자동).
#  발행:  월요일 아침 결과를 확인한 뒤 '발행.bat' 더블클릭으로 게시.
#  수동으로 옆에서 보며 만들 땐 기존 '리포트생성.bat'(대화형)을 쓰면 됨.
# ============================================================

$ErrorActionPreference = "Stop"
chcp 65001 > $null   # 한글 출력 깨짐 방지(UTF-8)
# claude(headless) 출력이 로그에서 깨지지 않도록 콘솔 인코딩도 UTF-8로 맞춘다
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# ※ 이 파일은 반드시 'UTF-8 BOM 있음'으로 저장할 것.
#   이 PC는 ANSI 코드페이지가 949라 BOM 없는 UTF-8이면 PowerShell 5.1이
#   한글을 CP949로 오독해 파싱 단계에서 죽는다(로그도 안 남고 종료코드 1).

$workDir = $PSScriptRoot
Set-Location $workDir

$reportDir = Join-Path $workDir "리포트"
if (-not (Test-Path $reportDir)) { New-Item -ItemType Directory -Path $reportDir | Out-Null }

# 로그 파일 (실행 이력/오류 추적)
$logDir = Join-Path $workDir "자동생성로그"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
$logFile = Join-Path $logDir ("자동생성_" + (Get-Date -Format "yyyy-MM-dd_HHmm") + ".txt")

function Log($msg) {
    $line = "[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $msg
    Write-Host $line
    Add-Content -Path $logFile -Value $line -Encoding utf8
}

# --- 주차/기간 계산 (리포트생성.ps1과 동일 규칙) ---
function Get-OwningMonthKey([datetime]$start) {
    $counts = @{}
    for ($i = 0; $i -lt 7; $i++) {
        $d = $start.AddDays($i)
        $k = "{0:0000}-{1:00}" -f $d.Year, $d.Month
        if ($counts.ContainsKey($k)) { $counts[$k]++ } else { $counts[$k] = 1 }
    }
    ($counts.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1).Key
}

$today     = Get-Date
$startDate = $today.AddDays(-7)
$endDate   = $startDate.AddDays(6)
$fromStr   = $startDate.ToString("yyyy-MM-dd")
$toStr     = $endDate.ToString("yyyy-MM-dd")

$ownKey   = Get-OwningMonthKey $startDate
$ownYear  = [int]$ownKey.Substring(0,4)
$ownMonth = [int]$ownKey.Substring(5,2)
$week  = 1
$probe = $startDate.AddDays(-7)
while ((Get-OwningMonthKey $probe) -eq $ownKey) {
    $week++
    $probe = $probe.AddDays(-7)
}
$weekLabel = "${ownMonth}월 ${week}주차 핵심 이슈"
$baseName  = "${ownYear}년 ${ownMonth}월 ${week}주차 업계 동향 및 주요 이슈"
$outName   = "$baseName.html"
$outRel    = "리포트/$outName"
$outFull   = Join-Path $reportDir $outName

Log "=== 업계동향 리포트 무인 생성 시작 ==="
Log "수집 기간: $fromStr ~ $toStr / 대상: $outRel"

# claude CLI 확인
$claude = Get-Command claude -ErrorAction SilentlyContinue
if (-not $claude) {
    Log "[오류] 'claude' CLI를 찾을 수 없습니다. 설치/로그인 상태 확인 필요. 종료."
    exit 1
}

# --- Claude 에게 줄 무인 작업 지시 (대화형 승인 없이 한 번에 끝내도록 상세히) ---
$prompt = @"
[무인 자동 실행] 이 폴더의 CLAUDE.md 지시문에 따라 이번 회차 '미디어커머스 업계 동향 주간 리포트'를 처음부터 끝까지 사람 개입 없이 완성해줘. 중간에 질문하지 말고, 합리적 기본값으로 끝까지 진행한 뒤 결과만 보고해.

[이번 회차 조건]
- 수집 기간: $fromStr ~ $toStr (지난 7일)
- 추적 카테고리 4개(화장품/뷰티, 아이웨어+레인부츠·패션잡화, 뷰티 디바이스, 미디어커머스 공통) 모두 다룬다.
- 각 카테고리에서 신제품/런칭, 경쟁사 캠페인, 플랫폼·정책 변화, 규제·인증 이슈, 소비 트렌드를 WebSearch로 검색·수집한다.
- 지난주(직전 회차, 루트 index.html)와 중복되는 기사는 피하고, 이번 주 신선한 이슈 위주로 고른다.
- 중복·단순 광고성 기사를 제거하고 자사 브랜드 관련성이 높은 순으로 정리한다. 카테고리당 카드 6~7개.

[수집 - 검색보다 기사수집.py 를 먼저 돌린다]
- `python 기사수집.py $fromStr $toStr` 를 실행하면 매체 목록 페이지를 직접 훑어 기간 내 발행 기사만 TSV로 뽑아준다.
- 이 결과를 1차 후보로 쓰고, 카드가 모자란 카테고리만 WebSearch로 보완한다.

[수집 창 - 전 섹션 '지난 7일' 엄수]
- 네 섹션 모두 $fromStr ~ $toStr 에 발행된 기사만 쓴다. 창 밖 기사는 내용이 좋아도 채택하지 않는다.
- 빈자리를 옛날 기사로 메우지 않는다. 카드가 모자라면 검색 소스를 넓히지, 기간을 늘리지 않는다.

[발행일 검증 - 가장 중요. 이 단계를 건너뛰지 말 것]
- WebSearch 결과는 최신성을 보장하지 않는다. 관련성이 높아 보여도 몇 달~1년 전 기사가 섞여 나온다.
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

[디자인 - 반드시 기존 템플릿을 그대로 복제]
- 루트 index.html(직전 회차)의 HTML/CSS 구조를 그대로 복제하고 내용만 이번 회차로 교체한다.
- 카드 구조: 이미지(200px)가 카드 상단을 차지하고 그 위에 카테고리 컬러 태그(우상단)와 제목(흰 글씨, 최대 3줄)을 얹는다
  → 흰 본문에 요약(3줄) → 시사점 → 하단 구분선 아래 출처.
- 카드 전체 클릭 이동(stretched-link) CSS 유지(.card position:relative + .card-foot a::after). <head>에 <meta name="robots" content="noindex, nofollow" /> 포함.
- 섹션(카테고리)마다 상단에 '이번주 이슈 요약' 박스를 넣는다. 요약은 순수 요약만(구체 수치 포함), '브랜드 적용'이나 '~할 시점이다' 식 마무리 문장은 넣지 않는다. (카드 안 시사점에는 자사 브랜드 적용 코멘트 유지)
- **제작 사정은 절대 쓰지 않는다.** 카드가 몇 장인지, 해당 분야 보도가 적었는지, 기간을 안 늘렸는지,
  다른 주제로 채웠는지 같은 '만드는 쪽 사정'은 독자가 알 바가 아니다. 요약 박스는 **이슈 내용만** 담는다.
  금지 예: "이번 주도 디바이스 전문 보도가 적어 카드는 4장이다", "기간을 늘리는 대신 수를 줄였다",
  "기간 내 아이웨어 보도가 없어 패션잡화로 채웠다"
  → 그냥 확보한 이슈를 바로 서술하며 시작한다. 카드가 적으면 적은 대로 조용히 낸다.

[시사점 문체 - AI 말투 금지]
- 사람이 회의에서 말하듯 담백한 평서문으로 쓴다. 서술어로 끝낸다. ('~한다', '~해야 한다', '~하는 편이 낫다', '~볼 만하다')
- 금지: 개조식 명사 종결('~선점.', '~배치.', '~검토.', '~공략.'), 컨설팅 버즈워드(USP, 포트폴리오, 채널 믹스, 이원화, 서사화, 세계관, 벤치마킹, 로드맵, 포지셔닝),
  문장을 잇는 대시(—), 단어를 욱여넣는 '+'·중점 나열, 라벨의 이모지(💡).
- 라벨은 <b>시사점</b> 으로만 쓴다. 한 카드에 한두 문장, 40~60자.

[카드 이미지 - 기사 썸네일(og:image) 자동 추출]
- 각 기사 원문 URL의 대표 이미지(og:image)를 카드 배경으로 사용한다.
- 추출은 반드시 원본 HTML을 curl로 받아 og:image 메타태그를 파싱한다. WebFetch는 head를 버리므로 사용 금지.
  예) curl -sL -A "Mozilla/5.0" "URL" | grep -ioE '<meta[^>]+property=.?og:image.?[^>]*>'
- background-image 는 url(썸네일)과 카테고리 그라데이션 2겹으로 지정(깨짐 대비). 한글 URL은 percent-encoding.

[검증 - 무인이므로 반드시 자동 점검]
- 완성 후 모든 카드의 썸네일 이미지 URL과 기사 링크 URL을 curl로 HTTP 상태 점검한다.
- 404 등 비정상 링크/이미지는 정상 대체 URL로 교체하고 다시 점검한다. (전부 200이 되도록)
- **링크가 200이라는 것과 기사가 최신이라는 것은 별개다.** 모든 카드의 발행일이 $fromStr ~ $toStr 안인지 다시 한 번 전수 확인하고,
  기간 밖이 하나라도 있으면 그 카드를 교체한다. 보고할 때 카드별 발행일 목록을 함께 출력한다.

[산출물]
- '$outRel' 파일로 저장한다. 상단 헤더에 생성일 / 수집 기간 / 핵심 헤드라인 5개(번호 배지). 담당 브랜드 줄은 넣지 않는다.
- 헤드라인 라벨 문구는 '$weekLabel' 로 한다.
- 작업이 끝나면 '$outRel' 내용을 루트 index.html 로도 복사해 최신본을 갱신한다.
- 너는 git commit/push 를 하지 마라. 발행은 이 스크립트가 검증을 마친 뒤 알아서 처리한다.
- 폴더 CLAUDE.md '진행 현황 메모'에 이번 회차 한 줄을 추가한다.

모든 설명·출력은 한국어. 끝나면 생성한 파일 경로와 카테고리별 카드 수, 링크 점검 결과(정상/교체)를 요약해서 보고해.
"@

Log "Claude(headless) 실행 시작... (리서치·작성·검증까지 수 분 소요될 수 있음)"

# headless 실행: -p(print) 로 비대화형. 무인이라 도구 승인 없이 끝까지 진행되도록 권한 우회.
# ※ 이 스크립트는 발행(push)을 하지 않으므로 영향 범위는 로컬 파일 쓰기/웹 조회로 한정됨.
# 빈 stdin 을 파이프해 'no stdin data' 경고/3초 대기를 방지.
"" | & claude -p $prompt --dangerously-skip-permissions 2>&1 | Tee-Object -FilePath $logFile -Append

Log "Claude 실행 종료."

if (Test-Path $outFull) {
    Log "[완료] $outRel 생성 확인됨."

    # --- 발행 전 최소 점검 (빈 껍데기·생성 실패본을 올리지 않기 위한 안전장치) ---
    $html      = Get-Content $outFull -Raw -Encoding utf8
    $cardCount = ([regex]::Matches($html, 'class="card[" ]')).Count
    Log "카드 수 점검: $cardCount 장"

    if ($cardCount -lt 8) {
        Log "[중단] 카드가 $cardCount 장뿐이라 발행하지 않습니다. 로그 확인 후 수동 발행하세요."
    }
    elseif (-not (Test-Path (Join-Path $workDir "index.html"))) {
        Log "[중단] index.html 갱신이 안 됐습니다. 발행하지 않습니다."
    }
    else {
        # --- 발행 (GitHub Pages) ---
        # ※ PS 5.1 주의: 네이티브 명령(git)은 stderr에 경고만 써도
        #   $ErrorActionPreference="Stop" 아래서 종료 오류로 승격된다.
        #   (git add 의 "LF will be replaced by CRLF" 경고로 발행이 실패했던 이력 있음)
        #   그래서 git 구간에서만 Continue 로 낮추고, 성공 판정은 $LASTEXITCODE 로만 한다.
        Log "발행 시작..."
        $prevEAP = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            $addOut = & git add -A 2>&1
            if ($LASTEXITCODE -ne 0) { throw "git add 실패(코드 $LASTEXITCODE): $addOut" }

            $msg = "업계동향 리포트 $ownYear-$('{0:00}' -f $ownMonth) ${week}주차 ($fromStr~$toStr)"
            $commitOut = & git commit -m $msg 2>&1
            $commitCode = $LASTEXITCODE
            Log ("git commit: " + ($commitOut -join " / "))
            # 커밋할 변경이 없으면 exit 1 → 오류가 아니라 '이미 최신'
            if ($commitCode -ne 0 -and ($commitOut -join " ") -notmatch "nothing to commit|working tree clean") {
                throw "git commit 실패(코드 $commitCode)"
            }

            $pushOut = & git push origin main 2>&1
            $pushCode = $LASTEXITCODE
            Log ("git push: " + ($pushOut -join " / "))
            if ($pushCode -eq 0) {
                Log "[발행 완료] https://withbrothersjsa.github.io/media-report/"
            } else {
                Log "[발행 실패] push 오류(코드 $pushCode). 인증(GitHub Desktop) 확인 후 '발행.bat' 수동 실행."
            }
        } catch {
            Log "[발행 실패] $($_.Exception.Message)"
        } finally {
            $ErrorActionPreference = $prevEAP
        }
    }
} else {
    Log "[경고] $outRel 가 생성되지 않았습니다. 로그($logFile)를 확인하세요."
}

Log "=== 무인 생성 종료 ==="
