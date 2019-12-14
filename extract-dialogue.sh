#!/bin/sh
usage() {
    printf 'Usage: %s -i <video-file> [-a <audio-track] [-s <subtitle-track>] [-o <output-file>] [-p <padding>]
Options:
    -i    Specify the video input
    -a    Specify the audio track number to use
    -s    Either specify the subtitle track number to use or specify an external subtitle file
    -o    Specify the output filename
    -p    Specify padding (in milliseconds) around subtitle timestamps
    -h    Display this usage message

Only the -i option is required. If not specified, the default behavior is to use the first audio track and the first subtitle track. The default output name is "output.mp3". Similar to ffmpeg, the extension of the output name determines the format of the output.\n' "$(basename $0)"
    exit 0
}

error() {
    echo "Error: $1" >&2
    exit 1
}

extract_timestamps() {
    # Parses the subtitles file to the format BEGIN:END
    # BEGIN and END are in milliseconds.
    # Output is sorted by BEGIN time
    subs=$1
    padding=$2
    if [ -f "$subs" ]; then
        subtitles=$(ffmpeg -loglevel fatal -i "$subs" -f ass -)
    else
        subs_id=$(ffprobe "$file" 2>&1 | grep "Stream .*Subtitle" \
                  | sed -n "${subs:-1}p" | grep -o '[0-9]:[0-9]')
        [ -z "$subs_id" ] && error "No text-based subtitles found in '$file'."
        subtitles=$(ffmpeg -loglevel fatal -i "$file" -map $subs_id -f ass -)
    fi

    # Extract the timestamps of dialogue without extra styling.
    # This will exclude signs and most OPs/EDs.
    timestamps=$(echo "$subtitles" | grep "^Dialogue:" | grep -v ",{" \
                 | cut -f "2,3" -d "," | sort)

    [ -z "$timestamps" ] && error "Extracting subtitles failed."

    # Convert timestamps to milliseconds and pad the timestamps
    echo "$timestamps" | awk -F ':|,' -v p=$padding '{ printf "%d:%d\n", \
        ( $1 * 3600000 ) + ( $2 * 60000 ) + ($3 * 1000) - p, \
        ( $4 * 3600000 ) + ( $5 * 60000 ) + ($6 * 1000) + p }'
}

merge_timestamps() {
    # Takes a list of timestamp intervals from standard input and merges
    # overlapping intervals
    cur_begin=
    cur_end=

    for timestamp in $(cat /dev/stdin); do
        begin=$(echo "$timestamp" | cut -f1 -d:)
        end=$(  echo "$timestamp" | cut -f2 -d:)
        [ -z "$cur_begin" ] && cur_begin=$begin
        [ -z "$cur_end" ]   && cur_end=$end

        if [ "$cur_end" -lt "$begin" ]; then
            echo "$cur_begin:$cur_end"
            cur_begin=$begin
            cur_end=$end
        elif [ "$cur_end" -lt "$end" ]; then
            cur_end=$end
        fi
    done
    echo "$cur_begin:$cur_end"
}

[ -z "$1" ] && usage

while [ -n "$1" ]; do
    case "$1" in
        "-i") shift; file=$1    ;;
        "-a") shift; audio=$1   ;;
        "-s") shift; subs=$1    ;;
        "-o") shift; output=$1  ;;
        "-p") shift; padding=$1 ;;
        "-k") keep=1            ;;
        "-h") usage             ;;
        *) error "There was an error parsing arguments. Make sure to use the -i option." ;;
    esac
    shift
done

timestamps=$(extract_timestamps "$subs" "${padding:-100}" | merge_timestamps \
    | awk -F: '{ printf "%.3f:%.3f\n", ( $1 / 1000 ), ( $2 / 1000 ) }')
audio_id=$(ffprobe "$file" 2>&1 | grep "Stream .*Audio" \
           | sed -n "${audio:-1}p" | grep -o '[0-9]:[0-9]')
ext=$(echo "${output:-output.mp3}" | sed 's/.*\.//')

# Setup the filter complex command for trimming and then concatenating
num=1
trim=
concat=
for timestamp in $timestamps; do
    trim="$trim[$audio_id]atrim=$timestamp[a$num];"
    concat="$concat[a$num]"
    num=$(( $num + 1 ))
done
num=$(( $num - 1 ))
concat="${concat}concat=n=$num:v=0:a=1[out]"

base=$(basename "$file" | sed 's/\.[^.]*$//')
echo "Concatenating audio files..."
ffmpeg -i "$file" -filter_complex "$trim$concat" -map "[out]" "${output:-$base.mp3}"

[ $? -eq 0 ] && echo "File '${output:-$base.mp3}' was created successfully."
