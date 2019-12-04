#!/bin/sh
temp=$(mktemp --directory)
trap 'rm -rf $temp' EXIT

audio_id=$(ffprobe "$1" 2>&1 | grep "\(jpn\|jp\).*Audio" | head -n 1 | grep -o '[0-9]:[0-9]')
subs_id=$(ffprobe "$1" 2>&1 | grep "Sub.*\(srt\|ssa\|ass\)" | head -n 1 | grep -o '[0-9]:[0-9]')

if [ -z $subs_id ]; then
    echo "Error: No text-based subtitles found." >&2
    exit 1
fi

ffmpeg -i "$1" -map $subs_id "$temp/subs.ass" 2> /dev/null
timestamps=$(grep "^Dialogue:.*Default" "$temp/subs.ass" | cut -f "2,3" -d "," | tr '\n' ' ')

num=1
for timestamp in $timestamps; do
    begin=$(echo "$timestamp" | cut -f1 -d,)
    end=$(  echo "$timestamp" | cut -f2 -d,)
    ffmpeg -ss "$begin" -to "$end" -i "$1" -map $audio_id "$temp/$num.mp3" 2> /dev/null
    if ffprobe -i "$temp/$num.mp3" 2> /dev/null; then
        echo "$num.mp3 : $begin -> $end"
        echo "file '$temp/$num.mp3'" >> "$temp/list.txt"
        num="$(( $num + 1 ))"
    else
        rm "$temp/$num.mp3"
    fi
done

ffmpeg -safe 0 -f concat -i "$temp/list.txt" -c copy output.mp3
