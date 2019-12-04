# extract-dialogue
Uses subtitle timestamps to extract the dialogue from an .mkv file.

At the moment, the only valid input is an .mkv file. The first Japanese audio track is split according to the timestamps of the first text-based subtitles track (i.e. subtitles that are in the format .ass, .ssa, or .srt). The audio cuts are then concatenated and written to the file `output.mp3`.

This script is written in plain Bourne Shell. The only dependency is ffmpeg.

## Future Plans
* Add command line options to specify the audio and subtitles track
* Add option to specify output name
* Add option to use an external subtitles file
* Write documentation and error-handling
* Add the option to pad the timestamps in the subtitles file
* Automatically merge overlapping timestamps (especially when using padding)
* Parse bitmap-based subtitle files 
