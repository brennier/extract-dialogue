# extract-dialogue
Uses subtitle timestamps to extract the dialogue from an .mkv file. This script is written in plain Bourne Shell. The only dependency is ffmpeg.

First, ffmpeg is used to extract the subtitle file from the .mkv file. It then splits and converts the audio track of the .mkv file according to the timestamps of the subtitle file. This requires the subtitles in a text-based format (i.e. subtitles that are in the format .ass, .ssa, or .srt). The audio cuts are then concatenated and written to the output filename (default is `output.mp3`).

## Options
There are several options that you can specify:  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; -i   Specify the video input  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; -a   Specify the audio track number to use  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; -s   Specify the subtitle track number to use  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; -o   Specify the output filename  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; -h   Display usage message

Only the -i option is required. If not specified, the default behavior is to use
the first audio track and the first subtitle track. The default output name is
"output.mp3". Similar to ffmpeg, the extension of the output name determines the
format of the output.

## Future Plans
* ~~Add command line options to specify the audio and subtitles track~~
* ~~Add option to specify output name~~
* ~~Automatically merge overlapping timestamps (especially when using padding)~~
* ~~Add option to use an external subtitles file~~
* Improve subtitle parsing
* Improve documentation and error-handling
* Add the option to pad the timestamps in the subtitles file
* Parse bitmap-based subtitle files
