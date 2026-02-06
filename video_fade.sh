#!/bin/bash

# Video Fade Script
# Adds fade-in from black and fade-out to black
# with corresponding audio fades, then uploads to YouTube and Nextcloud

set -o pipefail

# ==================== DEFAULT CONFIGURATION ====================
# These can be overridden by config file or command-line flags

# Fade settings
FADE_IN_DURATION=2
FADE_OUT_DURATION=5

# Output settings
OUTPUT_SUFFIX="_faded"

# YouTube settings
YOUTUBE_ENABLED=true
YOUTUBE_CLIENT_SECRETS="$HOME/.config/youtube-upload/client_secrets.json"
YOUTUBE_CREDENTIALS="$HOME/.config/youtube-upload/credentials.json"
YOUTUBE_PRIVACY="unlisted"
YOUTUBE_CATEGORY="22"

# Nextcloud settings
NEXTCLOUD_ENABLED=true
NEXTCLOUD_URL=""
NEXTCLOUD_USER=""
NEXTCLOUD_PASS=""
NEXTCLOUD_FOLDER="/Videos"
# ===============================================================

# Config file location
CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/video-fade/config"

# Load config file if it exists
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Command-line flags
DELETE_SOURCE=false
DELETE_OUTPUT=false
YOUTUBE_TITLE=""

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] <input_video> [output_video]

Options:
  -t, --title TITLE      Set YouTube video title (default: output filename)
  --delete-source        Delete source file after processing
  --delete-output        Delete output file after uploading
  -h, --help             Show this help message

Output filename defaults to <input>${OUTPUT_SUFFIX}.<ext> if not specified.

Config file: $CONFIG_FILE

Examples:
  $(basename "$0") input.mp4
  $(basename "$0") input.mp4 output.mp4
  $(basename "$0") --title "My Video" input.mp4
  $(basename "$0") --delete-source --title "Upload Only" input.mp4
EOF
    exit 0
}

# Parse command-line arguments
POSITIONAL=()
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--title)
            YOUTUBE_TITLE="$2"
            shift 2
            ;;
        --delete-source)
            DELETE_SOURCE=true
            shift
            ;;
        --delete-output)
            DELETE_OUTPUT=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        -*)
            echo "Error: Unknown option: $1"
            echo "Use --help for usage information."
            exit 1
            ;;
        *)
            POSITIONAL+=("$1")
            shift
            ;;
    esac
done

# Restore positional arguments
set -- "${POSITIONAL[@]}"

# Validate: cannot use both delete flags together
if [ "$DELETE_SOURCE" = true ] && [ "$DELETE_OUTPUT" = true ]; then
    echo "Error: Cannot use --delete-source and --delete-output together."
    echo "This would delete both input and output files, leaving nothing."
    exit 1
fi

if [ $# -lt 1 ]; then
    echo "Error: Input video required."
    echo "Use --help for usage information."
    exit 1
fi

INPUT="$1"
OUTPUT="${2:-${INPUT%.*}${OUTPUT_SUFFIX}.${INPUT##*.}}"

if [ ! -f "$INPUT" ]; then
    echo "Error: Input file '$INPUT' not found"
    exit 1
fi

# Get video duration
DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$INPUT")

if [ -z "$DURATION" ]; then
    echo "Error: Could not determine video duration"
    exit 1
fi

# Calculate fade-out start time
FADE_OUT_START=$(echo "$DURATION - $FADE_OUT_DURATION" | bc)

echo "Input: $INPUT"
echo "Output: $OUTPUT"
echo "Duration: ${DURATION}s"
echo "Fade in: ${FADE_IN_DURATION}s, Fade out: ${FADE_OUT_DURATION}s (starts at ${FADE_OUT_START}s)"
[ "$DELETE_SOURCE" = true ] && echo "Will delete source after processing"
[ "$DELETE_OUTPUT" = true ] && echo "Will delete output after uploading"

ffmpeg -i "$INPUT" \
    -vf "fade=t=in:st=0:d=${FADE_IN_DURATION},fade=t=out:st=${FADE_OUT_START}:d=${FADE_OUT_DURATION}" \
    -af "afade=t=in:st=0:d=${FADE_IN_DURATION},afade=t=out:st=${FADE_OUT_START}:d=${FADE_OUT_DURATION}" \
    -c:v libx264 -preset medium -crf 23 \
    -c:a aac -b:a 192k \
    "$OUTPUT"

if [ $? -ne 0 ]; then
    echo "Error: FFmpeg encoding failed"
    exit 1
fi

echo "Done! Output saved to: $OUTPUT"
echo ""

# Delete source file if requested
if [ "$DELETE_SOURCE" = true ]; then
    rm "$INPUT"
    echo "Deleted source file: $INPUT"
fi

# Set video title (flag > default from filename)
VIDEO_TITLE="${YOUTUBE_TITLE:-$(basename "${OUTPUT%.*}")}"

# Variables to store URLs for final summary
YOUTUBE_URL=""
NEXTCLOUD_LINK=""

# ==================== YOUTUBE UPLOAD ====================
if [ "$YOUTUBE_ENABLED" = true ]; then
    echo "=== Uploading to YouTube ==="

    if ! command -v youtube-upload &> /dev/null; then
        echo "Warning: youtube-upload not found. Install with: pip install youtube-upload"
    elif [ ! -f "$YOUTUBE_CLIENT_SECRETS" ]; then
        echo "Warning: YouTube client_secrets.json not found at $YOUTUBE_CLIENT_SECRETS"
        echo "Get it from: https://console.cloud.google.com/"
    else
        echo "Title: $VIDEO_TITLE"
        # Capture the video ID from youtube-upload output
        VIDEO_ID=$(youtube-upload \
            --title="$VIDEO_TITLE" \
            --privacy="$YOUTUBE_PRIVACY" \
            --category="$YOUTUBE_CATEGORY" \
            --client-secrets="$YOUTUBE_CLIENT_SECRETS" \
            --credentials-file="$YOUTUBE_CREDENTIALS" \
            "$OUTPUT" 2>&1 | tail -n 1)

        if [ -n "$VIDEO_ID" ] && [[ "$VIDEO_ID" =~ ^[a-zA-Z0-9_-]{11}$ ]]; then
            YOUTUBE_URL="https://www.youtube.com/watch?v=${VIDEO_ID}"
            echo "YouTube upload complete!"
        else
            echo "Warning: YouTube upload failed or couldn't get video ID"
        fi
    fi
    echo ""
fi

# ==================== NEXTCLOUD UPLOAD ====================
if [ "$NEXTCLOUD_ENABLED" = true ]; then
    echo "=== Uploading to Nextcloud ==="

    if [ -z "$NEXTCLOUD_URL" ]; then
        echo "Warning: Nextcloud URL not configured. Set NEXTCLOUD_URL in $CONFIG_FILE"
    else
        FILENAME="$(basename "$OUTPUT")"
        WEBDAV_URL="${NEXTCLOUD_URL}/remote.php/dav/files/${NEXTCLOUD_USER}${NEXTCLOUD_FOLDER}/${FILENAME}"

        # Upload file
        HTTP_CODE=$(curl -X PUT \
            -u "${NEXTCLOUD_USER}:${NEXTCLOUD_PASS}" \
            --upload-file "$OUTPUT" \
            "$WEBDAV_URL" \
            --progress-bar \
            -o /dev/null \
            -w "%{http_code}")

        if [ "$HTTP_CODE" = "201" ] || [ "$HTTP_CODE" = "204" ]; then
            echo "Nextcloud upload complete!"

            # Create a public share link using OCS API
            SHARE_RESPONSE=$(curl -s -X POST \
                -u "${NEXTCLOUD_USER}:${NEXTCLOUD_PASS}" \
                -H "OCS-APIREQUEST: true" \
                -d "path=${NEXTCLOUD_FOLDER}/${FILENAME}" \
                -d "shareType=3" \
                "${NEXTCLOUD_URL}/ocs/v2.php/apps/files_sharing/api/v1/shares?format=json")

            # Extract the share URL from JSON response
            NEXTCLOUD_LINK=$(echo "$SHARE_RESPONSE" | grep -o '"url":"[^"]*"' | head -1 | cut -d'"' -f4 | sed 's/\\\//\//g')

            if [ -z "$NEXTCLOUD_LINK" ]; then
                # Fallback: construct direct file path URL
                NEXTCLOUD_LINK="${NEXTCLOUD_URL}/apps/files/?dir=${NEXTCLOUD_FOLDER}&openfile=${FILENAME}"
            fi
        else
            echo "Warning: Nextcloud upload failed (HTTP $HTTP_CODE)"
        fi
    fi
    echo ""
fi

# Delete output file if requested (after uploads complete)
if [ "$DELETE_OUTPUT" = true ]; then
    rm "$OUTPUT"
    echo "Deleted output file: $OUTPUT"
fi

# ==================== SUMMARY ====================
echo "=========================================="
echo "                 SUMMARY"
echo "=========================================="
if [ "$DELETE_OUTPUT" = true ]; then
    echo "Output file: $OUTPUT (deleted)"
else
    echo "Output file: $OUTPUT"
fi
echo ""
if [ -n "$YOUTUBE_URL" ]; then
    echo "YouTube URL: $YOUTUBE_URL"
fi
if [ -n "$NEXTCLOUD_LINK" ]; then
    echo "Nextcloud URL: $NEXTCLOUD_LINK"
fi
echo "=========================================="
echo "All done!"
