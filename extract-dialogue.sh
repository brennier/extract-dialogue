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

merge_timestamps() {
    # Takes a list of timestamp intervals from standard input and merges
    # overlapping intervals
    cur_begin=""
    cur_end=""
    for timestamp in $(cat - | tr ' ' '\n' | sort | tr '\n' ' '); do
        begin=$(echo "$timestamp" | cut -f1 -d,)
        end=$(  echo "$timestamp" | cut -f2 -d,)
        [ -z "$cur_begin" ] && cur_begin="$begin"
        [ -z "$cur_end" ] && cur_end="$end"

        if earlier_than "$cur_end" "$begin"; then
            echo "$cur_begin,$cur_end "
            cur_begin=$begin
            cur_end=$end
        elif earlier_than "$cur_end" "$end"; then
            cur_end="$end"
        fi
    done
    echo "$cur_begin,$cur_end"
}

earlier_than() {
    # Takes two timestamps in the format of HH:MM:SS.ss and
    # determines whether the first occurs earlier than the second
    hour1=$(echo "$1" | cut -f1 -d:)
    hour2=$(echo "$2" | cut -f1 -d:)
    min1=$(echo "$1" | cut -f2 -d:)
    min2=$(echo "$2" | cut -f2 -d:)
    sec1=$(echo "$1" | cut -f3 -d: | cut -f1 -d.)
    sec2=$(echo "$2" | cut -f3 -d: | cut -f1 -d.)
    msec1=$(echo "$1" | cut -f2 -d.)
    msec2=$(echo "$2" | cut -f2 -d.)

    [ $hour1 -lt $hour2 ] && return 0
    [ $hour1 -gt $hour2 ] && return 1
    [ $min1  -lt $min2  ] && return 0
    [ $min1  -gt $min2  ] && return 1
    [ $sec1  -lt $sec2  ] && return 0
    [ $sec1  -gt $sec2  ] && return 1
    [ $msec1 -lt $msec2 ] && return 0
    [ $msec1 -gt $msec2 ] && return 1
    return 1 # If they're the same, return false
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

for timestamp in $(extract_timestamps "$subs" | merge_timestamps); do
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
