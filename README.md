# extract-dialogue
Uses subtitle timestamps to extract the dialogue from a video file. This script is written in plain Bourne Shell. The only dependency is ffmpeg.

First, the timestamps from the subtitles are extracted. The subtitles can either be specified as an external file or as a track number if the input is a container format like .mkv. The subtitles are required to be in a text-based format (i.e. subtitles that are in the format .ass, .ssa, .srt, etc.). The timestamps are then padded and overlapping timestamps are merged. The program ffmpeg is used to extract the audio during the timestamps.

## Options
There are several options that you can specify:
```
    -i   Specify the video input  
    -a   Specify the audio track number to use  
    -s   Either specify the subtitle track number to use or specify the filename of an external subtitle file  
    -o   Specify the output filename  
    -p   Specify padding (in milliseconds) around subtitle timestamps 
    -h   Display usage message
```

Only the -i option is required. If not specified, the default behavior is to use the first audio track and the first subtitle track. The default output name is simply the name of the video file with the extension changed to .mp3.  The default padding is 100 milliseconds. Similar to ffmpeg, the extension of the output name determines the format of the output.

## Future Plans
* ~~Add command line options to specify the audio and subtitles track~~
* ~~Add option to specify output name~~
* ~~Automatically merge overlapping timestamps (especially when using padding)~~
* ~~Add option to use an external subtitles file~~
* ~~Add the option to pad the timestamps in the subtitles file~~
* ~~Improve subtitle parsing~~ (Note: not perfect, but uses the same method as subs2srs)
* Improve documentation
* Improve error-handling
* Parse bitmap-based subtitle files
