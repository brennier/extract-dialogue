#!/bin/sh
temp=$(mktemp -d)
trap 'rm -rf $temp' EXIT

usage() {
    printf 'Usage: %s -i <video-file> [-a <audio-track] [-s <subtitle-track>] [-o <output-file>]
Options:
    -i Specify the video input
    -a Specify the audio track number to use
    -s Specify the subtitle track number to use
    -o Specify the output filename
    -h Display this usage message

Only the -i option is required. If not specified, the default behavior is to use
the first audio track and the first subtitle track. The default output name is
"output.mp3". Similar to ffmpeg, the extension of the output name determines the
format of the output.\n' "$(basename $0)"
    exit 0
}

error() {
    echo "Error: $1" >&2
    exit 1
}

extract_timestamps() {
    # Parses the subtitles file to the format BEGIN,END
    # BEGIN and END are in the format HH:MM:SS.sss
    # H: hour, M: minute, S: second, s: milisecond
    subs="$1"
    if [ -f "$subs" ]; then
        ffmpeg -loglevel fatal -i "$subs" "$temp/subs.ass"
    else
        subs_id=$(ffprobe "$file" 2>&1 | grep "Stream .*Subtitle" | sed -n "${subs:-1}p" | grep -o '[0-9]:[0-9]')
        [ -z "$subs_id" ] && error "No text-based subtitles found in '$file'."
        ffmpeg -loglevel fatal -i "$file" -map $subs_id "$temp/subs.ass"
    fi
    timestamps=$(grep "^Dialogue:.*\(Default\|Main\)" "$temp/subs.ass" | cut -f "2,3" -d "," | tr '\n' ' ')

    [ ! -f "$temp/subs.ass" ] && error "No subtitles file found."
    [ -z "$timestamps" ] && error "Subtitles file was found, but parsing failed."

    echo "$timestamps"
}

[ -z "$1" ] && usage

while [ -n "$1" ]; do
    case "$1" in
        "-i") shift; file="$1"   ;;
        "-a") shift; audio="$1"  ;;
        "-s") shift; subs="$1"   ;;
        "-o") shift; output="$1" ;;
        "-h") usage              ;;
        *) error "There was an error parsing arguments. Make sure to use the -i option." ;;
    esac
    shift
done

audio_id=$(ffprobe "$file" 2>&1 | grep "Stream .*Audio" | sed -n "${audio:-1}p" | grep -o '[0-9]:[0-9]')
ext=$(echo "${output:=output.mp3}" | sed 's/.*\.\(.*\)/\1/')
num=1

for timestamp in $(extract_timestamps "$subs"); do
    begin=$(echo "$timestamp" | cut -f1 -d,)
    end=$(  echo "$timestamp" | cut -f2 -d,)
    ffmpeg -y -loglevel fatal -ss "$begin" -to "$end" -i "$file" -map $audio_id "$temp/$num.$ext"
    if ffprobe -i "$temp/$num.$ext" 2> /dev/null; then
        echo "$num.$ext : $begin -> $end"
        echo "file '$temp/$num.$ext'" >> "$temp/list.txt"
        num="$(( $num + 1 ))"
    fi
done

echo "Concatenating audio files..."
ffmpeg -loglevel fatal -safe 0 -f concat -i "$temp/list.txt" "${output:-output.mp3}"

[ $? -eq 0 ] && echo "File '${output:=output.mp3}' was created successfully."
