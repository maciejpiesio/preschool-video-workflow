# Preschool Video Workflow

A bash script that adds fade effects to videos and uploads them to YouTube and Nextcloud.

## Background

I'm a member of the parents board for two preschool groups. I regularly record events (recitals, celebrations, etc.) and share the videos privately with other parents. This tool was created to streamline my workflow—adding professional-looking fade effects and quickly uploading to YouTube (unlisted) and Nextcloud without manual steps.

## Features

- 2-second fade-in from black (configurable)
- 5-second fade-out to black (configurable)
- Matching audio fades
- Automatic YouTube upload (unlisted)
- Automatic Nextcloud upload with public share link
- Config file support for persistent settings

## Installation

### Prerequisites

- [ffmpeg](https://ffmpeg.org/) - Video processing
- [youtube-upload](https://github.com/tokland/youtube-upload) - YouTube uploads (optional)
- curl - Nextcloud uploads (usually pre-installed)

```bash
# macOS
brew install ffmpeg

# YouTube upload (optional)
pip install youtube-upload
```

### Install the command

```bash
make install PREFIX=$HOME/.local
```

To uninstall:

```bash
make uninstall PREFIX=$HOME/.local
```

## Usage

```bash
video-fade [OPTIONS] <input_video> [output_video]
```

### Options

| Option | Description |
|--------|-------------|
| `-t, --title TITLE` | Set YouTube video title (default: output filename) |
| `--delete-source` | Delete source file after processing |
| `--delete-output` | Delete output file after uploading |
| `-h, --help` | Show help message |

Note: `--delete-source` and `--delete-output` cannot be used together.

### Examples

```bash
# Basic usage (outputs recital_faded.mp4)
video-fade recital.mp4

# Specify output filename
video-fade recital.mp4 recital_final.mp4

# Set custom YouTube title
video-fade --title "Spring Recital 2026" recital.mp4

# Upload only (delete local files after)
video-fade --delete-source recital.mp4
```

## Configuration

Create a config file at `~/.config/video-fade/config`:

```bash
mkdir -p ~/.config/video-fade
cp config.example ~/.config/video-fade/config
```

Then edit the config file with your settings.

### Config Options

```bash
# Output suffix (default: "_faded")
OUTPUT_SUFFIX="_faded"

# Fade timing
FADE_IN_DURATION=2
FADE_OUT_DURATION=5

# YouTube
YOUTUBE_ENABLED=true
YOUTUBE_PRIVACY="unlisted"
YOUTUBE_CATEGORY="22"

# Nextcloud
NEXTCLOUD_ENABLED=true
NEXTCLOUD_URL="https://your-nextcloud-server.com"
NEXTCLOUD_USER="your_username"
NEXTCLOUD_PASS="your_app_password"
NEXTCLOUD_FOLDER="/Videos"
```

### YouTube Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a project and enable YouTube Data API v3
3. Create OAuth 2.0 credentials and download `client_secrets.json`
4. Place it at `~/.config/youtube-upload/client_secrets.json`

## License

MIT
