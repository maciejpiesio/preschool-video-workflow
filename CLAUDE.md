# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Video processing workflow script that adds fade effects to videos and uploads them to YouTube and Nextcloud. Designed for processing preschool/educational videos.

## Usage

```bash
video-fade [OPTIONS] <input_video> [output_video]

Options:
  -t, --title TITLE      Set YouTube video title
  --delete-source        Delete source file after processing
  --delete-output        Delete output file after uploading
  -h, --help             Show help
```

Output defaults to `<input><OUTPUT_SUFFIX>.<ext>` if not specified.

## Installation

```bash
make install PREFIX=$HOME/.local
```

## Dependencies

- **ffmpeg/ffprobe**: Video processing (fade effects, encoding)
- **youtube-upload**: YouTube uploads (`pip install youtube-upload`)
- **curl**: Nextcloud WebDAV uploads
- **bc**: Duration calculations

## Configuration

Config file location: `~/.config/video-fade/config`

Copy `config.example` to get started. Key settings:
- `OUTPUT_SUFFIX`: Appended to input filename (default: `_faded`)
- `FADE_IN_DURATION` / `FADE_OUT_DURATION`: Fade timing in seconds
- `YOUTUBE_*`: YouTube API credentials and upload settings
- `NEXTCLOUD_*`: Nextcloud WebDAV credentials and folder

## Video Processing Pipeline

1. Loads config from `~/.config/video-fade/config` if present
2. Parses command-line flags and validates (blocks `--delete-source` + `--delete-output` combo)
3. Gets video duration via ffprobe
4. Applies fade-in/out effects (video and audio) via ffmpeg
5. Encodes with libx264 (CRF 23) and AAC audio (192k)
6. Optionally deletes source file (`--delete-source`)
7. Uploads to YouTube with custom or auto-generated title
8. Uploads to Nextcloud via WebDAV and creates public share link
9. Optionally deletes output file (`--delete-output`)
10. Outputs summary with URLs
