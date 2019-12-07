#!/bin/sh
temp=$(mktemp -d)
trap 'rm -rf $temp' EXIT

usage() {
    printf 'Usage: %s -i <video-file> [-a <audio-track] [-s <subtitle-track>] [-o <output-file>]
Options:
    -i Specify the video input
    -a Specify the audio track number to use
    -s Either specify the subtitle track number to use or specify an external subtitle file
    -o Specify the output filename
    -p Specify padding (in milliseconds) around subtitle timestamps. Must be less than 1000
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
    # Output is sorted by BEGIN time
    subs="$1"
    if [ -f "$subs" ]; then
        ffmpeg -loglevel fatal -i "$subs" "$temp/subs.ass"
    else
        subs_id=$(ffprobe "$file" 2>&1 | grep "Stream .*Subtitle" | sed -n "${subs:-1}p" | grep -o '[0-9]:[0-9]')
        [ -z "$subs_id" ] && error "No text-based subtitles found in '$file'."
        ffmpeg -loglevel fatal -i "$file" -map $subs_id "$temp/subs.ass"
    fi
    [ -f "$temp/subs.ass" ] || error "No subtitles file found."

    timestamps=$(grep "^Dialogue:.*\(Default\|Main\)" "$temp/subs.ass" | cut -f "2,3" -d "," | sort)

    [ -z "$timestamps" ] && error "Subtitles file was found, but parsing failed."
    echo "$timestamps"
}

merge_timestamps() {
    # Takes a list of timestamp intervals from standard input and merges
    # overlapping intervals
    cur_begin=""
    cur_end=""
    for timestamp in $(cat /dev/stdin); do
        IFS=, read begin end <<< "$timestamp"
        [ -z "$cur_begin" ] && cur_begin="$begin"
        [ -z "$cur_end" ]   && cur_end="$end"

        if expr "$cur_end" "<" "$begin" > /dev/null; then
            echo "$cur_begin,$cur_end"
            cur_begin="$begin"
            cur_end="$end"
        elif expr "$cur_end" "<" "$end" > /dev/null; then
            cur_end="$end"
        fi
    done
    echo "$cur_begin,$cur_end"
}

pad_timestamps() {
    # Takes a list of timestamp intervals from standard input and a
    # number as its first argument. Pads the intervals by that number of
    # milliseconds. Padding must be less than 1 second.
    padding="$(printf "%03d" "$1")"
    [ "$padding" -gt 1000 ] && error "Padding is too large!"
    for timestamp in $(cat /dev/stdin); do
        IFS=, read begin end <<< "$timestamp"
        # Use date to shift timestamps
        if expr "$begin" ">" "00:00:00.$padding" > /dev/null; then
            new_begin="$(date +"%T.%2N" -d "01 Jan 1970 $begin - 0.$padding seconds")"
        else
            new_begin="00:00:00.000"
        fi
        new_end="$(date +"%T.%2N" -d "01 Jan 1970 $end + 0.$padding seconds")"

        echo "$new_begin,$new_end"
    done
}

[ -z "$1" ] && usage

while [ -n "$1" ]; do
    case "$1" in
        "-i") shift; file="$1"    ;;
        "-a") shift; audio="$1"   ;;
        "-s") shift; subs="$1"    ;;
        "-o") shift; output="$1"  ;;
        "-p") shift; padding="$1" ;;
        "-h") usage               ;;
        *) error "There was an error parsing arguments. Make sure to use the -i option." ;;
    esac
    shift
done

timestamps="$(extract_timestamps "$subs" | pad_timestamps "${padding:-100}" | merge_timestamps)"
audio_id=$(ffprobe "$file" 2>&1 | grep "Stream .*Audio" | sed -n "${audio:-1}p" | grep -o '[0-9]:[0-9]')
ext=$(echo "${output:=output.mp3}" | sed 's/.*\.//')
num="1"

for timestamp in $timestamps; do
    IFS=, read begin end <<< "$timestamp"
    ffmpeg -y -loglevel fatal -ss "$begin" -to "$end" -i "$file" -map $audio_id "$temp/$num.$ext"
    if ffprobe -i "$temp/$num.$ext" 2> /dev/null; then
        echo "$num.$ext : $begin -> $end"
        echo "file '$temp/$num.$ext'" >> "$temp/list.txt"
        (( num++ ))
    fi
done

base=$(basename "$file" | sed 's/\..*//')
echo "Concatenating audio files..."
ffmpeg -loglevel fatal -safe 0 -f concat -i "$temp/list.txt" "${output:-$base.mp3}"

[ $? -eq 0 ] && echo "File '${output:=output.mp3}' was created successfully."
