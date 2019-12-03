#!/bin/sh
temp=$(mktemp --directory)
trap 'rm -rf $temp' EXIT

ffmpeg -i "$1" -map 0:s:0 "$temp/subs.ass" 2> /dev/null
timestamps=$(grep "^Dialogue:" "$temp/subs.ass" | cut -f "2,3" -d "," | uniq | head -n 50 | tr '\n' ' ')

num=1
for timestamp in $timestamps; do
    begin=$(echo "$timestamp" | cut -f1 -d,)
    end=$(  echo "$timestamp" | cut -f2 -d,)
    ffmpeg -ss "$begin" -to "$end" -i "$1" -q:a 0 -map a "$temp/$num.mp3" 2> /dev/null
    echo "$num : $begin $end"
    num="$(( $num + 1 ))"
done

find $temp -name '*.mp3' | sort -V | sed "s/\(.*\)/file '\1'/" > $temp/list.txt
ffmpeg -y -safe 0 -f concat -i $temp/list.txt -c copy output.mp3
