#!/bin/bash

read -p "Enter YouTube URL: " url

# Base downloads folder (relative to script location)
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
DOWNLOADS_DIR="$BASE_DIR/downloads"

mkdir -p "$DOWNLOADS_DIR"

# Get the original video title
echo "Fetching video info..."
title=$(yt-dlp --get-title "$url")
safe_title=$(echo "$title" | tr -cd '[:alnum:] _.-')
folder="$DOWNLOADS_DIR/$safe_title"

mkdir -p "$folder"

# Download best audio format as original.ext
echo "Downloading audio..."
yt-dlp -f bestaudio --no-playlist -o "$folder/original.%(ext)s" "$url"

# Find the downloaded file (e.g., original.webm or original.m4a)
downloaded_file=$(find "$folder" -name 'original.*' | head -n 1)

# Convert to MP3
echo "Converting to MP3..."
ffmpeg -i "$downloaded_file" -vn -ab 192k -ar 44100 -y "$folder/original.mp3"

# Remove the original audio file
rm "$downloaded_file"

# Save only the original title (no file extension) to text file
echo "$title" > "$folder/original_filename.txt"

# Check for chapter timestamps and split into separate MP3s if present
echo "Checking for chapters..."
chapters_json=$(yt-dlp --skip-download --print "%(chapters)j" "$url" 2>/dev/null)

if [[ "$chapters_json" != "null" && "$chapters_json" != "None" && -n "$chapters_json" ]]; then
    echo "Chapters found — splitting into individual MP3 files..."
    chapters_dir="$folder/chapters"
    mkdir -p "$chapters_dir"

    # Parse chapters and split using ffmpeg
    num_chapters=$(echo "$chapters_json" | python3 -c "
import sys, json
chapters = json.load(sys.stdin)
print(len(chapters))
")

    echo "$chapters_json" | python3 -c "
import sys, json, subprocess, os, re

chapters = json.load(sys.stdin)
src = sys.argv[1]
out_dir = sys.argv[2]

for i, ch in enumerate(chapters):
    start = ch['start_time']
    end   = ch.get('end_time')
    raw   = ch.get('title', f'Chapter {i+1}')
    safe  = re.sub(r'[^\w \-.]', '', raw).strip()
    idx   = str(i + 1).zfill(2)
    out   = os.path.join(out_dir, f'{idx} - {safe}.mp3')

    cmd = ['ffmpeg', '-i', src, '-ss', str(start)]
    if end is not None:
        cmd += ['-to', str(end)]
    cmd += ['-vn', '-ab', '192k', '-ar', '44100', '-y', out]

    print(f'  [{idx}/{len(chapters)}] {safe}')
    subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
" "$folder/original.mp3" "$chapters_dir"

    echo "Chapter MP3s saved to: $chapters_dir"
else
    echo "No chapters found — single MP3 only."
fi

# Open the folder
echo "Opening folder..."
xdg-open "$folder" 2>/dev/null || open "$folder" || nautilus "$folder"

echo "Done ✅"
