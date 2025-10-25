import fs from 'fs';
import { fileTypeFromBuffer } from 'file-type';
import { execSync } from 'child_process';
import { Client } from "lrclib-api";

const lrclib = new Client();

function findFirstKey(obj, keyToFind) {
    if (typeof obj !== "object" || obj === null) return undefined;
    for (const key in obj) {
        if (key === keyToFind) {
            return obj[key];
        }
        if (typeof obj[key] === "object" && obj[key] !== null) {
            const result = findFirstKey(obj[key], keyToFind);
            if (result !== undefined) return result;
        }
    }
    return undefined;
}

function sanitizeFilename(name) {
    return name
        .replace(/[<>:"/\\|?*]/g, "-")
        .replace(/\s+/g, " ")
        .replace(/[<>:"/\\|?*\u{0080}-\u{FFFF}]/gu, "-")
        .trim();
}

async function downloadAudio(input) {
    input = input.trim();
    console.log("Fetching data...");

    const dataRes = await fetch(`https://katze.qqdl.site/song/?q=${encodeURIComponent(input)}&quality=HI_RES`);
    const data = await dataRes.json();

    const artists = data[0].artists.map(x => x.name).join(", ");
    const title = data[0].title;
    const fullSongName = `${artists} - ${title}`;
    const audioURL = findFirstKey(data, "OriginalTrackUrl");
    const albumCoverId = data[0].album.cover;

    console.log(`Downloading '${fullSongName}'...`);
    const audioRes = await fetch(audioURL);
    const rawAudioFileContents = Buffer.from(await audioRes.arrayBuffer());
    const audioType = await fileTypeFromBuffer(rawAudioFileContents);
    const audioExt = audioType.ext;

    const safeFull = sanitizeFilename(fullSongName);

    if (!fs.existsSync(`songs/${safeFull}`))
        fs.mkdirSync(`songs/${safeFull}`);

    fs.writeFileSync(`songs/${safeFull}/song.${audioExt}`, rawAudioFileContents);

    console.log("Downloading 1280x1280 cover...");
    const coverRes = await fetch(`https://resources.tidal.com/images/${albumCoverId.replaceAll("-", "/")}/1280x1280.jpg`);
    const rawCoverFileContents = Buffer.from(await coverRes.arrayBuffer());
    const coverType = await fileTypeFromBuffer(rawCoverFileContents);
    const coverExt = coverType.ext;

    fs.writeFileSync(`songs/${safeFull}/cover.${coverExt}`, rawCoverFileContents);

    // console.log("Adding the cover to the audio file...");
    // execSync(`ffmpeg -i ${tempName}.${audioExt} -i ${tempName}.${coverExt} -map 0:a -map 1:0 -c copy -id3v2_version 3 -metadata:s:v title="Album cover" -metadata:s:v comment="Cover (front)" -disposition:v attached_pic "${outputDir}/${sanitizeFilename(`${fullSongName}.${audioExt}`)}" -y`);

    console.log(`Getting duration...`);
    const dur = execSync(`ffprobe -v error -show_entries format=duration -of csv=p=0 "songs/${safeFull}/song.${audioExt}"`).toString().trim();
    
    const meta = {
        duration: parseFloat(dur),
        name: fullSongName,
        safeFull,
        audioFile: `song.${audioExt}`,
        coverFile: `cover.${coverExt}`,
        instrumental: true,
        lyrics: [],
    };

    console.log(`Getting lyrics...`);

    try {
        const lyrics = await lrclib.findLyrics({ artist_name: artists, track_name: title });

        const songEntry = []

        if (!lyrics.instrumental && lyrics.syncedLyrics) {
            const parsedLyrics = lyrics.syncedLyrics.split("\n").map(line => {
                const match = line.match(/^\[(\d+):(\d+)\.(\d+)\](.*)/);
                if (!match) return null;
                const [, m, s, ms, txt] = match;
                return {
                    time: parseInt(m) * 60 + parseInt(s) + parseInt(ms) / 100,
                    text: txt.trim()
                };
            }).filter(Boolean);

            songEntry.push(...parsedLyrics);
        }

        meta.lyrics = songEntry;
    } catch (e) {
        console.error(`Failed to fetch lyrics for ${fullSongName}:`, e);
        meta.lyrics = [];
    }

    fs.writeFileSync(`songs/${safeFull}/meta.json`, JSON.stringify(meta, null, 2));
}

downloadAudio(process.argv.slice(2).join(" ").trim());