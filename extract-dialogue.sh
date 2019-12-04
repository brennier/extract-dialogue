#!/bin/sh
temp=$(mktemp --directory)
trap 'rm -rf $temp' EXIT

ffmpeg -i "$1" -map 0:s:0 "$temp/subs.ass" 2> /dev/null
timestamps=$(grep "^Dialogue:.*Default" "$temp/subs.ass" | cut -f "2,3" -d "," | tr '\n' ' ')

num=1
for timestamp in $timestamps; do
    begin=$(echo "$timestamp" | cut -f1 -d,)
    end=$(  echo "$timestamp" | cut -f2 -d,)
    ffmpeg -ss "$begin" -to "$end" -i "$1" "$temp/$num.mp3" 2> /dev/null
    echo "$num.mp3 : $begin -> $end"
    echo "file '$temp/$num.mp3'" >> "$temp/list.txt"
    num="$(( $num + 1 ))"
done

ffmpeg -y -safe 0 -f concat -i $temp/list.txt -c copy output.mp3
