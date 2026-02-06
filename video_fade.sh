#!/bin/bash

# Video Fade Script
# Adds 2 second fade-in from black and 5 second fade-out to black
# with corresponding audio fades, then uploads to YouTube and Nextcloud

set -o pipefail

# ==================== CONFIGURATION ====================
# Fade settings
FADE_IN_DURATION=2
FADE_OUT_DURATION=5

# YouTube settings (requires youtube-upload: pip install youtube-upload)
# Get client_secrets.json from Google Cloud Console: https://console.cloud.google.com/
YOUTUBE_ENABLED=true
YOUTUBE_CLIENT_SECRETS="$HOME/.config/youtube-upload/client_secrets.json"
YOUTUBE_CREDENTIALS="$HOME/.config/youtube-upload/credentials.json"
YOUTUBE_PRIVACY="unlisted"  # public, unlisted, or private
YOUTUBE_CATEGORY="22"       # 22 = People & Blogs

# Nextcloud settings (uses WebDAV)
NEXTCLOUD_ENABLED=true
NEXTCLOUD_URL="https://your-nextcloud-server.com"  # Base URL without trailing slash
NEXTCLOUD_USER="your_username"
NEXTCLOUD_PASS="your_app_password"  # Use app password, not main password
NEXTCLOUD_FOLDER="/Videos"          # Remote folder path
# =======================================================

if [ $# -lt 1 ]; then
    echo "Usage: $0 <input_video> [output_video]"
    echo "Example: $0 input.mp4 output.mp4"
    exit 1
fi

INPUT="$1"
OUTPUT="${2:-${INPUT%.*}_faded.${INPUT##*.}}"

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

# Get video title from filename (without extension)
VIDEO_TITLE="$(basename "${OUTPUT%.*}")"

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
    
    if [ "$NEXTCLOUD_URL" = "https://your-nextcloud-server.com" ]; then
        echo "Warning: Nextcloud URL not configured. Edit the script to set NEXTCLOUD_URL."
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

# ==================== SUMMARY ====================
echo "=========================================="
echo "                 SUMMARY"
echo "=========================================="
echo "Output file: $OUTPUT"
echo ""
if [ -n "$YOUTUBE_URL" ]; then
    echo "YouTube URL: $YOUTUBE_URL"
fi
if [ -n "$NEXTCLOUD_LINK" ]; then
    echo "Nextcloud URL: $NEXTCLOUD_LINK"
fi
echo "=========================================="
echo "All done!"
