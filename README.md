# unnamed audio player / playlist thingy

Supports:
 - Alot of songs at once
 - Downloading songs
 - Shuffling the list
 - Searching via `/`
 - Rendering to a video
 - Lyrics via lrclib
 - Being very lightweight
 - random song every time a song finishes, configure in config.json

Requirements: 
 - LÖVE 12.0
 - Node.js
 - Spotdl
 - FFmpeg
 - yt-dlp

## Downloading songs

To download songs get a spotify developer account then put your in a .env file like:

```env
spotify_client_id="spotifyclientid"
spotify_client_secret="spotifyclientsecret"
``` 

Make sure to use `npm i` or whatever is equivalent to the node package manager you use

Then just run `node js/addSong.js (your song name)`

This will download the song using spotdl and ffmpeg, make sure you have them

It will also try to find lyrics and put them in lyrics.json

if it errors then try again and again it should work eventually

## Shuffling list
Run `node js/shuffleList.js` if list.json exists

## Running the app
It should just run normally with `love .` or `lovec .`

## Screenshots
![Screenshot of app](/assets/ss/ss1.png)
![Screenshot of app](/assets/ss/ss2.png)
![Screenshot of app](/assets/ss/ss3.png)