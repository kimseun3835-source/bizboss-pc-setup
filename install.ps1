# BIZBOSS 클로드 작업실 — 새 PC 한 번에 설치
# 사용법: PowerShell 을 열고 아래 한 줄 붙여넣기
#   irm https://raw.githubusercontent.com/kimseun3835-source/bizboss-pc-setup/main/install.ps1 | iex
$ErrorActionPreference = 'Continue'
$RepoName = 'kimseun3835-source/bizboss-claude'   # 비공개 저장소 (자료 전부)

function Step($t) { Write-Host ''; Write-Host "==== $t ====" -ForegroundColor Cyan }
function RefreshPath { $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User') }
function Sanitize($p) { return ($p -replace '[^A-Za-z0-9]', '-') }

Step '1/7 프로그램 설치 (10~30분, 중간에 "예" 창 뜨면 전부 예)'
$ids = 'Git.Git','GitHub.cli','Python.Python.3.12','OpenJS.NodeJS.LTS','Gyan.FFmpeg','Anthropic.Claude','Google.Chrome','astral-sh.uv','BlenderFoundation.Blender','Kakao.KakaoTalk'
foreach ($id in $ids) {
  Write-Host "- $id"
  winget install -e --id $id --accept-source-agreements --accept-package-agreements --silent | Out-Null
}
RefreshPath

Step '2/7 깃허브 로그인 (브라우저가 열리면 코드 입력 → 승인)'
gh auth status 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) { gh auth login --web --hostname github.com --git-protocol https }
gh auth setup-git | Out-Null

Step '3/7 작업 자료 내려받기 (1~2GB, 시간 걸려요)'
$desktop = [Environment]::GetFolderPath('Desktop')
$root = Join-Path $desktop '클로드'
git config --global core.quotepath false
git config --global core.longpaths true
if (Test-Path (Join-Path $root '.git')) {
  Write-Host '이미 있음 → 최신으로 업데이트'
  git -C $root pull
} else {
  if (Test-Path $root) { Rename-Item $root ($root + '_옛날_' + (Get-Date -Format 'MMdd_HHmm')) }
  gh repo clone $RepoName $root
}
if (-not (Test-Path (Join-Path $root '_클로드설정'))) { Write-Host '내려받기 실패. 깃허브 로그인 계정을 확인하고 다시 실행하세요.' -ForegroundColor Red; return }

Step '4/7 클로드 설정·스킬·기억 복원'
$cfg = Join-Path $root '_클로드설정'
$hc  = Join-Path $env:USERPROFILE '.claude'
New-Item -ItemType Directory -Force $hc | Out-Null
foreach ($f in 'CLAUDE.md','settings.json') { $p = Join-Path $cfg $f; if (Test-Path $p) { Copy-Item $p (Join-Path $hc $f) -Force } }
foreach ($d in 'skills','scheduled-tasks','agents','commands') {
  $p = Join-Path $cfg $d; if (Test-Path $p) { robocopy $p (Join-Path $hc $d) /E /R:1 /W:1 /NFL /NDL /NP /NJH /NJS | Out-Null }
}
# 기억: 노트북 경로 이름 → 이 PC 경로 이름으로 바꿔서 넣기
$deskKey = Sanitize $desktop
Get-ChildItem (Join-Path $cfg 'memory') -Directory | ForEach-Object {
  $new = $_.Name -replace '^C--Users-__USER__-Desktop', $deskKey
  $dst = Join-Path $hc "projects\$new\memory"
  robocopy $_.FullName $dst /E /R:1 /W:1 /NFL /NDL /NP /NJH /NJS | Out-Null
  Write-Host "기억 복원: $new"
}
# MCP 연결 목록 합치기
$mcpFile = Join-Path $cfg 'mcpServers.json'
if (Test-Path $mcpFile) {
  $cj = Join-Path $env:USERPROFILE '.claude.json'
  $mcp = Get-Content $mcpFile -Raw -Encoding UTF8 | ConvertFrom-Json
  if (Test-Path $cj) { $j = Get-Content $cj -Raw -Encoding UTF8 | ConvertFrom-Json } else { $j = New-Object psobject }
  if ($j.PSObject.Properties['mcpServers']) { $j.mcpServers = $mcp } else { $j | Add-Member -NotePropertyName mcpServers -NotePropertyValue $mcp }
  $utf8 = New-Object System.Text.UTF8Encoding($false)
  [IO.File]::WriteAllText($cj, ($j | ConvertTo-Json -Depth 20), $utf8)
}
$dc = Join-Path $cfg 'claude_desktop_config.json'
if (Test-Path $dc) { New-Item -ItemType Directory -Force (Join-Path $env:APPDATA 'Claude') | Out-Null; Copy-Item $dc (Join-Path $env:APPDATA 'Claude\claude_desktop_config.json') -Force }

Step '5/7 비밀 키 파일(.env.local) 복원'
$envTargets = '자체CRM\app','홈페이지','아버지_프로젝트\사이트'
$od = Join-Path $env:USERPROFILE 'OneDrive\ClaudeBackup\klode'
foreach ($t in $envTargets) {
  $src = Join-Path $od "$t\.env.local"; $dst = Join-Path $root "$t\.env.local"
  if (Test-Path $dst) { Write-Host "있음: $t" }
  elseif (Test-Path $src) { Copy-Item $src $dst; Write-Host "OneDrive 에서 복원: $t" }
  else { Write-Host "없음: $t  → 나중에 그 폴더에서 'vercel env pull .env.local' (vercel 로그인 후)" -ForegroundColor Yellow }
}

Step '6/7 도구 설치 (npm · 파이썬)'
RefreshPath
npm install -g @anthropic-ai/claude-code vercel hyperframes
foreach ($t in '자체CRM\app','아버지_프로젝트\사이트') {
  $p = Join-Path $root $t
  if (Test-Path (Join-Path $p 'package.json')) { Write-Host "npm install: $t"; Push-Location $p; npm install --no-audit --no-fund; Pop-Location }
}
py -3.12 -m pip install --upgrade pip
py -3.12 -m pip install faster-whisper numpy pillow opencv-contrib-python scipy yt-dlp onnxruntime olefile requests
$ae = Join-Path $root '유튜브\bizboss_autoedit'
if (Test-Path (Join-Path $ae 'requirements.txt')) {
  py -3.12 -m venv (Join-Path $ae '.venv')
  & (Join-Path $ae '.venv\Scripts\python.exe') -m pip install -r (Join-Path $ae 'requirements.txt')
}
$om = Join-Path $root '유튜브\video_tools\OpenMontage'
if (-not (Test-Path $om)) { git clone https://github.com/calesthio/OpenMontage.git $om }

Step '7/7 끝!'
Write-Host '남은 일 (손으로):' -ForegroundColor Green
Write-Host ' 1. Claude 앱 열기 → 같은 클로드 계정 로그인 → Code 탭 → 폴더: 바탕화면\클로드'
Write-Host ' 2. 크롬 로그인(동기화 켜기) → 확장: Claude, Handlus, uplika 업로드 도우미'
Write-Host ' 3. 사이트 로그인: uplika · 네이버 · 인스타/페북 · 노션 · vercel · 구글드라이브 · 크몽 · 페이앱 · 카카오톡 PC'
Write-Host ' 4. 클로드에게: "연결 확인해줘" / "예약 작업 PC로 옮겨줘"'
Write-Host ' 5. 영상 원본(mp4)·통화녹음은 깃허브에 없음 → 구글드라이브/USB'
Write-Host ''
Write-Host '자료 최신으로 받기:  바탕화면\클로드 에서  git pull'
Write-Host '자료 깃허브에 올리기: 바탕화면\클로드\컴퓨터옮기기\깃허브_올리기.bat 더블클릭'
