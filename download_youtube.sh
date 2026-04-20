#!/bin/bash

# ── Colors & symbols ─────────────────────────────────────────────
BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

TICK="${GREEN}✔${RESET}"
CROSS="${RED}✖${RESET}"
ARROW="${CYAN}▶${RESET}"
SPINNER_CHARS='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'

# ── Helper functions ─────────────────────────────────────────────
log()  { echo -e " ${ARROW}  $1"; }
ok()   { echo -e " ${TICK}  $1"; }
fail() { echo -e " ${CROSS}  ${RED}$1${RESET}"; }

# Start a background spinner with a message.  Usage: start_spinner "msg"
start_spinner() {
    local msg="$1"
    _spin_running=1
    (
        i=0
        while [[ -f /tmp/_ytdl_spin_$$ ]]; do
            printf "\r ${DIM}%s${RESET}  %s" "${SPINNER_CHARS:i%${#SPINNER_CHARS}:1}" "$msg"
            i=$((i + 1))
            sleep 0.08
        done
    ) &
    _spin_pid=$!
    touch /tmp/_ytdl_spin_$$
}

# Stop the spinner and print a result line.  Usage: stop_spinner "done msg"
stop_spinner() {
    rm -f /tmp/_ytdl_spin_$$
    wait "$_spin_pid" 2>/dev/null
    printf "\r\033[K"      # clear the spinner line
    ok "$1"
}

# Stop spinner on failure
stop_spinner_fail() {
    rm -f /tmp/_ytdl_spin_$$
    wait "$_spin_pid" 2>/dev/null
    printf "\r\033[K"
    fail "$1"
}

# Draw a simple progress bar.  Usage: progress_bar current total label
progress_bar() {
    local cur=$1 total=$2 label=$3
    local pct=$((cur * 100 / total))
    local filled=$((pct / 4))
    local empty=$((25 - filled))
    local bar
    bar=$(printf '%0.s█' $(seq 1 "$filled" 2>/dev/null))
    bar+=$(printf '%0.s░' $(seq 1 "$empty" 2>/dev/null))
    printf "\r\033[K ${DIM}[${RESET}${GREEN}%s${RESET}${DIM}]${RESET} %3d%%  %s" "$bar" "$pct" "$label"
}

# ── Cleanup on exit ──────────────────────────────────────────────
cleanup() { rm -f /tmp/_ytdl_spin_$$; }
trap cleanup EXIT

# ── Main ─────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}  YouTube Audio Downloader${RESET}"
echo -e "${DIM}  ────────────────────────${RESET}"
echo ""

read -p "  Enter YouTube URL: " url
echo ""

# Base downloads folder (relative to script location)
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
DOWNLOADS_DIR="$BASE_DIR/downloads"
mkdir -p "$DOWNLOADS_DIR"

# ── Step 1: Fetch video info ─────────────────────────────────────
start_spinner "Fetching video info…"
title=$(yt-dlp --get-title "$url" 2>/dev/null)
if [[ -z "$title" ]]; then
    stop_spinner_fail "Could not fetch video info — check the URL."
    exit 1
fi
safe_title=$(echo "$title" | tr -cd '[:alnum:] _.-')
folder="$DOWNLOADS_DIR/$safe_title"
mkdir -p "$folder"
stop_spinner "Video: ${BOLD}$title${RESET}"

# ── Step 2: Download best audio ──────────────────────────────────
yt-dlp -f bestaudio --no-playlist --newline --progress \
    -o "$folder/original.%(ext)s" "$url" 2>&1 \
    | while IFS= read -r line; do
        # yt-dlp progress lines look like: [download]  45.2% of  5.12MiB ...
        if [[ "$line" =~ \[download\][[:space:]]+([0-9]+(\.[0-9]+)?)% ]]; then
            pct="${BASH_REMATCH[1]%%.*}"
            progress_bar "$pct" 100 "Downloading…"
        fi
    done
printf "\r\033[K"
ok "Audio downloaded"

# Find the downloaded file (e.g., original.webm or original.m4a)
downloaded_file=$(find "$folder" -name 'original.*' ! -name '*.mp3' ! -name '*.txt' | head -n 1)

# ── Step 3: Convert to MP3 ───────────────────────────────────────
start_spinner "Converting to MP3 (192 kbps)…"
ffmpeg -i "$downloaded_file" -vn -ab 192k -ar 44100 -y "$folder/original.mp3" \
    </dev/null >/dev/null 2>&1
stop_spinner "Converted to MP3"

# Remove the intermediate audio file
rm -f "$downloaded_file"

# Save original title
echo "$title" > "$folder/original_filename.txt"

# ── Step 4: Chapter splitting ────────────────────────────────────
start_spinner "Checking for chapters…"
chapters_json=$(yt-dlp --skip-download --print "%(chapters)j" "$url" 2>/dev/null)

if [[ "$chapters_json" != "null" && "$chapters_json" != "None" && -n "$chapters_json" ]]; then
    stop_spinner "Chapters found — splitting into individual MP3s"
    chapters_dir="$folder/chapters"
    mkdir -p "$chapters_dir"

    echo "$chapters_json" | python3 -c "
import sys, json, subprocess, os, re

chapters = json.load(sys.stdin)
src = sys.argv[1]
out_dir = sys.argv[2]
total = len(chapters)

BOLD   = '\033[1m'
DIM    = '\033[2m'
GREEN  = '\033[0;32m'
RESET  = '\033[0m'

def progress_bar(cur, total, label):
    pct = int(cur * 100 / total)
    filled = pct // 4
    empty  = 25 - filled
    bar = '█' * filled + '░' * empty
    sys.stdout.write(f'\r\033[K {DIM}[{RESET}{GREEN}{bar}{RESET}{DIM}]{RESET} {pct:3d}%  {label}')
    sys.stdout.flush()

for i, ch in enumerate(chapters):
    start = ch['start_time']
    end   = ch.get('end_time')
    raw   = ch.get('title', f'Chapter {i+1}')
    safe  = re.sub(r'[^\w \-.]', '', raw).strip()
    idx   = str(i + 1).zfill(2)
    out   = os.path.join(out_dir, f'{idx} - {safe}.mp3')

    progress_bar(i, total, f'{BOLD}{idx}/{str(total).zfill(2)}{RESET}  {safe}')

    cmd = ['ffmpeg', '-i', src, '-ss', str(start)]
    if end is not None:
        cmd += ['-to', str(end)]
    cmd += ['-vn', '-ab', '192k', '-ar', '44100', '-y', out]
    subprocess.run(cmd, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

print('\r\033[K', end='')
" "$folder/original.mp3" "$chapters_dir"

    ok "Chapter MP3s saved to ${DIM}chapters/${RESET}"
else
    stop_spinner "No chapters found — single MP3 only"
fi

# ── Step 5: Open folder ──────────────────────────────────────────
echo ""
xdg-open "$folder" 2>/dev/null || open "$folder" 2>/dev/null || nautilus "$folder" 2>/dev/null

echo -e " ${GREEN}${BOLD}Done ✅${RESET}  Saved to ${DIM}$folder${RESET}"
echo ""
