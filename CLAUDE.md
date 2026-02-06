# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Video processing workflow script that adds fade effects to videos and uploads them to YouTube and Nextcloud. Designed for processing preschool/educational videos.

## Usage

```bash
./video_fade.sh <input_video> [output_video]
```

Output defaults to `<input>_faded.<ext>` if not specified.

## Dependencies

- **ffmpeg/ffprobe**: Video processing (fade effects, encoding)
- **youtube-upload**: YouTube uploads (`pip install youtube-upload`)
- **curl**: Nextcloud WebDAV uploads
- **bc**: Duration calculations

## Configuration

Edit the configuration section at the top of `video_fade.sh`:

- **YouTube**: Set `YOUTUBE_CLIENT_SECRETS` path (get from Google Cloud Console)
- **Nextcloud**: Set `NEXTCLOUD_URL`, `NEXTCLOUD_USER`, `NEXTCLOUD_PASS`
- **Fade timing**: `FADE_IN_DURATION` (default 2s), `FADE_OUT_DURATION` (default 5s)

## Video Processing Pipeline

1. Validates input file exists
2. Gets video duration via ffprobe
3. Applies fade-in/out effects (video and audio) via ffmpeg
4. Encodes with libx264 (CRF 23) and AAC audio (192k)
5. Uploads to YouTube (unlisted, category 22 - People & Blogs)
6. Uploads to Nextcloud via WebDAV and creates public share link
7. Outputs summary with URLs
