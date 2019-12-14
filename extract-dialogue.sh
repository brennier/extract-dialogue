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

Only the -i option is required. If not specified, the default behavior is to use the first audio track and the first subtitle track. The default output name is simply the name of the input file with the extension changed to .mp3. The default padding is 100 milliseconds. Similar to ffmpeg, the extension of the output name determines the format of the output.\n' "$(basename $0)"
    exit 0
}

error() {
    echo "Error: $1" >&2
    exit 1
}

cat_subs() {
    subs=$1
    if [ -f "$subs" ]; then
        ffmpeg -y -loglevel fatal -i "$subs" -f ass -
    else
        subs_id=$(ffprobe "$file" 2>&1 | grep "Stream .*Subtitle" \
                  | sed -n "${subs:-1}p" | grep -o '[0-9]:[0-9]')
        [ -z "$subs_id" ] && error "No text-based subtitles found in '$file'."
        ffmpeg -loglevel fatal -i "$file" -map $subs_id -f ass -
    fi
}

extract_timestamps() {
    # Extracts timestamps into the format BEGIN:END (in milliseconds)
    padding=$1
    timestamps=$(grep "^Dialogue:" - | grep -v ",{" \
                 | cut -f "2,3" -d "," | sort)
    [ -z "$timestamps" ] && error "Subtitles file was found, but parsing failed."

    # Convert timestamps to milliseconds and pad the timestamps
    echo "$timestamps" | awk -F ':|,' -v p=$padding '{ printf "%d:%d\n", \
        ( $1 * 3600000 ) + ( $2 * 60000 ) + ($3 * 1000) - p, \
        ( $4 * 3600000 ) + ( $5 * 60000 ) + ($6 * 1000) + p }'
}

merge_timestamps() {
    # Merges overlapping intervals from standard input
    cur_begin=
    cur_end=
    while IFS=: read -r begin end; do
        if [ -z "$cur_begin" ]; then
            cur_begin=$begin
            cur_end=$end
        elif [ "$cur_end" -lt "$begin" ]; then
            echo "$cur_begin:$cur_end"
            cur_begin=$begin
            cur_end=$end
        elif [ "$cur_end" -lt "$end" ]; then
            cur_end=$end
        fi
    done
    echo "$cur_begin:$cur_end"
}

while [ -n "$1" ]; do
    case "$1" in
        "-i") shift; file=$1    ;;
        "-a") shift; audio=$1   ;;
        "-s") shift; subs=$1    ;;
        "-o") shift; output=$1  ;;
        "-p") shift; padding=$1 ;;
        "-h") usage             ;;
        *) error "Failed to parse arguments. Use -h for help." ;;
    esac
    shift
done

timestamps=$(cat_subs "$subs" | extract_timestamps "${padding:-100}" | merge_timestamps \
    | awk -F: '{ printf "%.3f:%.3f\n", ( $1 / 1000 ), ( $2 / 1000 ) }')
audio_id=$(ffprobe "$file" 2>&1 | grep "Stream .*Audio" \
           | sed -n "${audio:-1}p" | grep -o '[0-9]:[0-9]')

# Setup the filter complex command for trimming and then concatenating
num=0
trim=
concat=
for timestamp in $timestamps; do
    num=$(( $num + 1 ))
    trim="$trim[$audio_id]atrim=$timestamp[a$num];"
    concat="$concat[a$num]"
done
concat="${concat}concat=n=$num:v=0:a=1[out]"

output=${output:-"$(basename "$file" | sed 's/\.[^.]*$//').mp3"}
ffmpeg -i "$file" -filter_complex "$trim$concat" -map "[out]" "$output"
[ $? -eq 0 ] && echo "File '$output' was created successfully."
