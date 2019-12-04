#!/bin/sh
temp=$(mktemp --directory)
trap 'rm -rf $temp' EXIT

usage() {
    printf 'Usage: %s -i <video-file> [-a <audio-track] [-s <subtitle-track>] [-o <output-file>]
Options:
    -i Specify the video input
    -a Specify the audio track number to use
    -s Specify the subtitle track number to use
    -o Specify the output filename
    -h Display this usage message

Only the -i option is required. If not specified, the default behavior is to use the first audio track and the first subtitle track. The default output name is "output.mp3". Similar to ffmpeg, the extension of the output name determines the format of the output.\n' "$(basename $0)"
}

if [ -z "$1" ]; then
    usage
    exit
fi

while [ -n "$1" ]; do
    case "$1" in
        "-i") shift; file="$1"   ;;
        "-a") shift; audio="$1"  ;;
        "-s") shift; subs="$1"   ;;
        "-o") shift; output="$1" ;;
        "-h") usage ; exit       ;;
        *) echo "There was an error parsing arguments. Make sure to use the -i option." >&2 ; exit 1 ;;
    esac
    shift
done

audio_id=$(ffprobe "$file" 2>&1 | grep "Audio" | sed -n "${audio:-1}p" | grep -o '[0-9]:[0-9]')
subs_id=$(ffprobe "$file" 2>&1 | grep "Subtitle" | sed -n "${subs:-1}p" | grep -o '[0-9]:[0-9]')

if [ -z $subs_id ]; then
    echo "Error: No text-based subtitles found." >&2
    exit 1
fi

ffmpeg -i "$file" -map $subs_id "$temp/subs.ass" 2> /dev/null
timestamps=$(grep "^Dialogue:.*Default" "$temp/subs.ass" | cut -f "2,3" -d "," | tr '\n' ' ')

num=1
for timestamp in $timestamps; do
    begin=$(echo "$timestamp" | cut -f1 -d,)
    end=$(  echo "$timestamp" | cut -f2 -d,)
    ffmpeg -ss "$begin" -to "$end" -i "$file" -map $audio_id "$temp/$num.mp3" 2> /dev/null
    if ffprobe -i "$temp/$num.mp3" 2> /dev/null; then
        echo "$num.mp3 : $begin -> $end"
        echo "file '$temp/$num.mp3'" >> "$temp/list.txt"
        num="$(( $num + 1 ))"
    else
        rm "$temp/$num.mp3"
    fi
done

ffmpeg -safe 0 -f concat -i "$temp/list.txt" -c copy "${output:-output.mp3}"
