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

# Open the folder
echo "Opening folder..."
xdg-open "$folder" 2>/dev/null || open "$folder" || nautilus "$folder"

echo "Done ✅"
