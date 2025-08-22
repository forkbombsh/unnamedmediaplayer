require("dotenv").config();
const clientId = process.env.spotify_client_id;
const clientSecret = process.env.spotify_client_secret;

const { execSync } = require("child_process");
const fs = require("fs");
const { Client } = require("lrclib-api");
const client = new Client();

let list = [];
let curLyrics = {};

if (fs.existsSync("./list.json")) list = require("../list.json");
if (fs.existsSync("./lyrics.json")) curLyrics = require("../lyrics.json");

if (!fs.existsSync("./art")) fs.mkdirSync("art");
if (!fs.existsSync("./music")) fs.mkdirSync("music");

const search = process.argv.slice(2).join(" ");

// Encode in Base64
const authHeader = Buffer.from(`${clientId}:${clientSecret}`).toString("base64");

// 🚨 Sanitiser for filenames
function sanitizeFilename(name) {
    return name
        .replace(/[<>:"/\\|?*]/g, "-")   // remove illegal characters
        .replace(/\s+/g, " ")           // collapse multiple spaces
        .replace(/[<>:"/\\|?*\u{0080}-\u{FFFF}]/gu, "-") // more
        .trim();                        // trim ends
}

async function getToken() {
    const res = await fetch("https://accounts.spotify.com/api/token", {
        method: "POST",
        headers: {
            "Authorization": `Basic ${authHeader}`,
            "Content-Type": "application/x-www-form-urlencoded"
        },
        body: "grant_type=client_credentials"
    });

    const data = await res.json();
    return data.access_token; // save this for API requests
}

const folder = "./music/";

async function searchTrack(query) {
    const token = await getToken();

    const res = await fetch(
        `https://api.spotify.com/v1/search?q=${encodeURIComponent(query)}&type=track&limit=1`,
        {
            headers: { "Authorization": `Bearer ${token}` }
        }
    );

    const data = await res.json();
    if (data.tracks.items.length > 0) {
        const track = data.tracks.items[0];
        const artists = track.artists.map(a => a.name).join(", ");
        const safeArtists = sanitizeFilename(artists);
        const name = track.name;
        const full = `${artists} - ${name}`;
        const safeFull = sanitizeFilename(full); // ✅ use safe name
        const safeName = sanitizeFilename(name); // ✅ use safe name
        const file = `${safeFull}.wav`;

        console.log(file);
        console.log("Found:", name, "by", artists);
        if (list.find((s) => s.name === full)) {
            console.log("Song already in list");
            return;
        }

        console.log("Spotify Link:", track.external_urls.spotify);
        console.log("Downloading...");
        execSync(`spotdl "${track.external_urls.spotify}" --format wav --output "${folder}${safeArtists} - ${safeName}.{output-ext}"`, { stdio: "inherit" });

        console.log("Extracting thumbnail...");
        const probe = execSync(`ffprobe -v error -show_streams -select_streams v "${folder}${file}"`).toString();

        if (probe.includes("codec_name=mjpeg")) {
            // File has an embedded cover image
            const outFile = `./art/${safeFull}.jpg`;

            // robust extraction: re-encode to JPEG instead of copy
            execSync(`ffmpeg -y -i "${folder}${file}" -map 0:v:0 -frames:v 1 "${outFile}"`, { stdio: "inherit" });

            console.log(`Extracted cover art to ${outFile}`);
        } else {
            console.log(`No thumbnail found in ${file}`);
        }

        console.log(`Getting duration...`);
        const dur = execSync(`ffprobe -v error -show_entries format=duration -of csv=p=0 "${folder}${file}"`).toString().trim();
        console.log(dur);

        list.push({
            name: full,       // keep original name for display
            safeFull: safeFull, // keep safe name for filesystem
            duration: parseFloat(dur)
        });

        const query = { artist_name: artists, track_name: name };

        try {
            const lyrics = await client.findLyrics(query);

            const songEntry = {
                instrumental: lyrics.instrumental,
                lyrics: []
            };

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

                songEntry.lyrics.push(...parsedLyrics);
            }

            curLyrics[safeFull] = songEntry;

        } catch (e) {
            console.error(`Failed to fetch lyrics for ${artists} - ${name}:`, e);
            curLyrics[safeFull] = {
                instrumental: true,
                lyrics: []
            };
        }

        fs.writeFileSync("list.json", JSON.stringify(list, null, 2));
        fs.writeFileSync("lyrics.json", JSON.stringify(curLyrics, null, 2));
    } else {
        console.log("No track found for:", query);
    }
}

searchTrack(search);
