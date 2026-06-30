# ============================================================
#  사이트 발행 (변경된 내용을 GitHub Pages 사이트에 올리기)
#  사용법: "발행.bat" 더블클릭
#  동작:  바뀐 파일을 커밋하고 push 해서 웹사이트를 갱신합니다.
#         (리포트 새로 만들 땐 '리포트생성.bat'에서 바로 발행하면 됨.
#          이건 '내용만 수정'했을 때 한 번에 올리는 용도)
# ============================================================

$ErrorActionPreference = "Stop"
chcp 65001 > $null
$workDir = $PSScriptRoot
Set-Location $workDir

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  사이트 발행" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

git add -A
if (git status --porcelain) {
    $msg = "내용 수정 발행: " + (Get-Date -Format "yyyy-MM-dd HH:mm")
    git commit -m $msg | Out-Null
    Write-Host "  변경 사항 커밋 완료" -ForegroundColor Green
} else {
    Write-Host "  바뀐 내용이 없습니다. (이미 최신 상태)" -ForegroundColor Yellow
}

Write-Host "  사이트에 올리는 중..." -ForegroundColor Cyan
git push origin main
if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "  [발행 완료] https://withbrothersjsa.github.io/media-report/" -ForegroundColor Green
    Write-Host "  (사이트 반영까지 1~2분 정도 걸립니다)"
} else {
    Write-Host ""
    Write-Host "  [발행 실패] GitHub Desktop을 열어 Push 해주세요." -ForegroundColor Yellow
}
Write-Host "=================================================="
Read-Host "  엔터를 누르면 창을 닫습니다"
