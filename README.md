# Preschool Video Workflow

A bash script that adds fade effects to videos and uploads them to YouTube and Nextcloud.

## Features

- 2-second fade-in from black (configurable)
- 5-second fade-out to black (configurable)
- Matching audio fades
- Automatic YouTube upload (unlisted)
- Automatic Nextcloud upload with public share link

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
make install
```

This installs `video-fade` to `/usr/local/bin`.

To uninstall:

```bash
make uninstall
```

## Usage

```bash
video-fade <input_video> [output_video]
```

Output defaults to `<input>_faded.<ext>` if not specified.

### Examples

```bash
# Basic usage (outputs recital_faded.mp4)
video-fade recital.mp4

# Specify output filename
video-fade recital.mp4 recital_final.mp4
```

## Configuration

Edit the configuration section at the top of the script (or in `/usr/local/bin/video-fade` after installation):

### YouTube Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a project and enable YouTube Data API v3
3. Create OAuth 2.0 credentials and download `client_secrets.json`
4. Place it at `~/.config/youtube-upload/client_secrets.json`

### Nextcloud Setup

Edit these variables in the script:

```bash
NEXTCLOUD_URL="https://your-nextcloud-server.com"
NEXTCLOUD_USER="your_username"
NEXTCLOUD_PASS="your_app_password"
NEXTCLOUD_FOLDER="/Videos"
```

### Fade Timing

```bash
FADE_IN_DURATION=2   # seconds
FADE_OUT_DURATION=5  # seconds
```

## License

MIT
