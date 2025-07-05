# YouTube Audio Downloader & MP3 Converter

This is a simple Bash script that downloads the best quality audio from a YouTube video, converts it to MP3, and saves it in a folder.

## Features

- Prompts the user to input a YouTube URL.
- Downloads the best available audio format using `yt-dlp`.
- Converts the downloaded audio to a high-quality MP3 using `ffmpeg`.
- Stores the result in a folder named after the original video title.
- Cleans up intermediate files.
- Saves the original video title in a text file.
- Opens the destination folder automatically (Linux/macOS supported).

## Requirements

Make sure the following tools are installed:

- [`yt-dlp`](https://github.com/yt-dlp/yt-dlp)
- [`ffmpeg`](https://ffmpeg.org/)

Install them via:

```bash
# For yt-dlp
pip install yt-dlp

# For ffmpeg (Ubuntu/Debian)
sudo apt install ffmpeg

# For macOS (using Homebrew)
brew install ffmpeg
```

## Usage

1. Save the script to a file, for example: `download_youtube.sh`
2. Make it executable:

```bash
chmod +x download_youtube.sh
```

3. Run the script:

```bash
./download_youtube.sh
```

4. Paste the YouTube video URL when prompted.

## Output

The script creates a folder inside a `downloads` directory (next to the script) with:

- `original.mp3` – the final converted audio file.
- `original_filename.txt` – the plain text title of the video.

## Notes

- The script supports Linux and macOS for auto-opening the output folder.
- Only a **single video** (not playlists) is supported.
- The script sanitizes folder names for safe filesystem usage.

## Example

```bash
$ ./download_youtube.sh
Enter YouTube URL: https://www.youtube.com/watch?v=dQw4w9WgXcQ
```

This will:
- Download the best audio stream.
- Convert it to `MP3`.
- Save it in `downloads/Never Gonna Give You Up/original.mp3`.

---

## Disclaimer

This script is intended for personal and educational use only. It is **not** meant to infringe upon the rights of the original content creators or copyright holders.

Please ensure you have the right to download and convert any content before using this tool. Respect copyright laws and the terms of service of the platform you are accessing.

Use responsibly.