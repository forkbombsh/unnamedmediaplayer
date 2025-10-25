function love.run()
    if love.load then love.load(love.arg.parseGameArguments(arg), arg) end

    -- We don't want the first frame's dt to include time taken by love.load.
    if love.timer then love.timer.step() end

    local dt = 0

    -- Main loop time.
    return function()
        -- Process events.
        if love.event then
            love.event.pump()
            for name, a, b, c, d, e, f in love.event.poll() do
                if name == "quit" then
                    if not love.quit or not love.quit() then
                        return a or 0
                    end
                end
                love.handlers[name](a, b, c, d, e, f)
            end
        end

        -- Update dt, as we'll be passing it to update
        if love.timer then dt = love.timer.step() end

        -- Call update and draw
        if love.update then love.update(dt) end -- will pass 0 if love.timer is disabled

        if love.graphics and love.graphics.isActive() then
            love.graphics.origin()
            love.graphics.clear(love.graphics.getBackgroundColor())

            if love.draw then love.draw() end

            love.graphics.present()
        end

        if not isRendering then love.timer.sleep(0.001) end
    end
end

love.window.setMode(1920, 1080, {
    resizable = true
})

love.graphics.clear()
love.graphics.present()

love.graphics.setLineWidth(4)

local triangleImg = love.graphics.newImage("assets/triangle.png")

local arialSmaBold = love.graphics.newFont("assets/ARIALBD 1.TTF", 20)
local arialBigBold = love.graphics.newFont("assets/ARIALBD 1.TTF", 40)
local arialMedBold = love.graphics.newFont("assets/ARIALBD 1.TTF", 30)
local notoSansTCFallbackBigBold = love.graphics.newFont("assets/NotoSansTC-Bold.ttf", 40)
local notoSansTCFallbackMedBold = love.graphics.newFont("assets/NotoSansTC-Bold.ttf", 30)
local notoSansTCFallbackSmallBold = love.graphics.newFont("assets/NotoSansTC-Bold.ttf", 20)
local notoSansJPFallbackBigBold = love.graphics.newFont("assets/NotoSansJP-Bold.ttf", 30)
local notoSansJPFallbackMedBold = love.graphics.newFont("assets/NotoSansJP-Bold.ttf", 30)
local notoSansJPFallbackSmallBold = love.graphics.newFont("assets/NotoSansJP-Bold.ttf", 20)
local notoEmojiFallbackBigBold = love.graphics.newFont("assets/NotoEmoji-Bold.ttf", 40)
local notoEmojiFallbackMedBold = love.graphics.newFont("assets/NotoEmoji-Bold.ttf", 30)
local notoEmojiFallbackSmallBold = love.graphics.newFont("assets/NotoEmoji-Bold.ttf", 20)

arialBigBold:setFallbacks(notoEmojiFallbackBigBold, notoSansTCFallbackBigBold, notoSansJPFallbackBigBold)
arialMedBold:setFallbacks(notoEmojiFallbackMedBold, notoSansTCFallbackMedBold, notoSansJPFallbackMedBold)
arialSmaBold:setFallbacks(notoEmojiFallbackSmallBold, notoSansTCFallbackSmallBold, notoSansJPFallbackSmallBold)

local totalTime = 0
local songs = {}
local thumbnails = {}
local json = require("src.lib.json")
local https = require("https")
local nativefs = require("src.lib.nativefs")

local config = json.decode(love.filesystem.read("config.json"))

function string.trim(s)
    return s:match("^%s*(.-)%s*$")
end

local function getAverageColor(imageData)
    local width, height = imageData:getDimensions()
    local rawData = imageData:getString() -- raw pixel bytes in RGBA format
    local rSum, gSum, bSum = 0, 0, 0
    local totalPixels = width * height

    -- rawData is a string, 4 bytes per pixel (RGBA)
    local i = 1
    for pixel = 1, totalPixels do
        local r = string.byte(rawData, i)
        local g = string.byte(rawData, i + 1)
        local b = string.byte(rawData, i + 2)
        -- local a = string.byte(rawData, i + 3) -- alpha if needed

        rSum = rSum + r
        gSum = gSum + g
        bSum = bSum + b

        i = i + 4 -- move to next pixel
    end

    -- return average in 0–1 range
    return rSum / totalPixels / 255, gSum / totalPixels / 255, bSum / totalPixels / 255
end

-- Helper function to safely load image or audio
local function safeLoadImage(path)
    if love.filesystem.getInfo(path) then
        return love.image.newImageData(path)
    else
        print("Warning: Image not found: " .. path)
        return nil
    end
end

local function safeLoadAudio(path)
    if love.filesystem.getInfo(path) then
        return love.audio.newSource(path, "stream", "file")
    else
        print("Warning: Audio not found: " .. path)
        return nil
    end
end

function secondsToTime(time)
    local hours = math.floor(time / 3600)
    local minutes = math.floor((time - hours * 3600) / 60)
    local seconds = math.floor(time - hours * 3600 - minutes * 60)
    return string.format("%02d:%02d:%02d", hours, minutes, seconds)
end

renderer = {}

local songList = {}

for i, v in ipairs(love.filesystem.getDirectoryItems("songs")) do
    local path = ("songs/%s"):format(v)
    local metaPath = ("%s/meta.json"):format(path)
    if love.filesystem.getInfo(metaPath) then
        local meta = json.decode(love.filesystem.read(metaPath))
        local song = {
            safeFull = meta.safeFull,
            name = meta.name,
            duration = meta.duration,
            coverFile = meta.coverFile,
            audioFile = meta.audioFile,
            lyrics = meta.lyrics
        }
        songList[#songList + 1] = song
    end
end

local isRendering = false

require("src.playlist")(thumbnails, arialBigBold, arialMedBold, arialSmaBold,
    triangleImg, isRendering, config)

local curIndex = 0

local function getSongPath(song)
    return "songs/" .. song .. "/"
end

function LoadSong(song)
    curIndex = curIndex + 1
    local cleanName = (song.safeFull or song.name)
    local actualName = song.name

    local lyrics = song.lyrics or {}

    local thumbnailData = safeLoadImage(getSongPath(cleanName) .. song.coverFile)
    local colour = { getAverageColor(thumbnailData) }
    local r, g, b = colour[1] * 1.25, colour[2] * 1.25, colour[3] * 1.25
    local lighterColour = { r, g, b }
    local thumbnail = love.graphics.newImage(thumbnailData)
    thumbnails[curIndex] = thumbnail

    thumbnailData:release()

    local length = song.duration
    if not length then
        print("Warning: Duration not found for " .. cleanName)
        length = 0
    end
    local audioSource = safeLoadAudio(getSongPath(cleanName) .. song.audioFile)
    songs[#songs + 1] = {
        length = length,
        actualName = actualName,
        starting_time = totalTime,
        name = cleanName,
        audio = audioSource,
        index = curIndex,
        colour = colour,
        lighterColour = lighterColour,
        lyrics = lyrics
    }

    renderer.addSong(songs[#songs])

    print(
        string.format("%d: %s (%s) - %s", curIndex, cleanName, secondsToTime(length),
            secondsToTime(totalTime)))

    totalTime = totalTime + length
end

for _, song in ipairs(songList) do
    LoadSong(song)
end

local function encodeURIComponent(str)
    return (str:gsub("[^%w%-_%.%!%~%*%'%(%)]", function(c)
        return string.format("%%%02X", string.byte(c))
    end))
end

local function findFirstKey(obj, keyToFind)
    if type(obj) ~= "table" then
        return nil
    end

    for key, value in pairs(obj) do
        if key == keyToFind then
            return value
        end
        if type(value) == "table" then
            local result = findFirstKey(value, keyToFind)
            if result ~= nil then
                return result
            end
        end
    end

    return nil
end

local fileSignatures = {
    -- Images
    ["png"]  = "\137PNG\r\n\26\n",
    ["jpg"]  = "\255\216\255",
    ["jpeg"] = "\255\216\255",
    ["gif"]  = "GIF8",
    ["bmp"]  = "BM",
    ["webp"] = "RIFF", -- Need further check for "WEBP"
    ["tiff"] = "II",   -- "II" for little endian, "MM" for big endian
    ["tif"]  = "MM",

    -- Audio
    ["mp3"]  = "\255\251", -- Simple ID3-less MP3 header
    ["wav"]  = "RIFF",     -- Need further check for "WAVE"
    ["ogg"]  = "OggS",
    ["flac"] = "fLaC",
    ["aac"]  = "\255\241", -- ADTS header
    ["m4a"]  = "ftypM4A",
    ["aiff"] = "FORM",

    -- Video
    ["mp4"]  = "ftyp",      -- Check bytes 5-8 for "mp42" or "isom"
    ["mov"]  = "ftyp",      -- Check bytes 5-8 for "qt  "
    ["avi"]  = "RIFF",      -- Check bytes 9-12 for "AVI "
    ["mkv"]  = "\31\139\8", -- MKV/Matroska often starts with EBML
    ["webm"] = "\31\139\8"  -- Similar to MKV (needs EBML parsing)
}

-- Function to detect file extension
function getFileExt(data)
    for ext, signature in pairs(fileSignatures) do
        if ext == "webp" or ext == "wav" or ext == "avi" then
            -- Special handling for files starting with "RIFF"
            if data:sub(1, 4) == "RIFF" then
                local subType = data:sub(9, 12)
                if subType == "WEBP" then
                    return "webp"
                elseif subType == "WAVE" then
                    return "wav"
                elseif subType == "AVI " then
                    return "avi"
                end
            end
        elseif ext == "mp4" or ext == "mov" then
            if data:sub(5, 8) == "mp42" or data:sub(5, 8) == "isom" then
                return "mp4"
            elseif data:sub(5, 8) == "qt  " then
                return "mov"
            end
        else
            if data:sub(1, #signature) == signature then
                return ext
            end
        end
    end
    return nil -- unknown format
end

-- thanks chatgpt

local function sanitizeFilename(name)
    name = name:gsub('[<>:"/\\|?*]', '-')
    name = name:gsub('%s+', ' ')
    name = name:gsub('[\128-\255]', '-')
    return name:trim()
end

local function displayBoxedText(font, text)
    local rw = font:getWidth(text)
    local rh = font:getHeight()
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", 0, 0, rw, rh)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(text, font)
    love.graphics.present()
end

local bigFont = love.graphics.newFont(30)

function GetSong(input)
    input = input:trim()
    print("Fetching data...")
    displayBoxedText(bigFont, ("Fetching song with query '%s'..."):format(input))
    local _, dataBody = https.request(("https://katze.qqdl.site/song/?q=%s&quality=HI_RES"):format(encodeURIComponent(
        input)))
    local data = json.decode(dataBody)
    local artistNames = {}
    for _, artist in ipairs(data[1].artists) do
        table.insert(artistNames, artist.name)
    end
    local artists = table.concat(artistNames, ", ")

    -- Extract title
    local title = data[1].title

    -- Combine full song name
    local fullSongName = artists .. " - " .. title

    -- Find OriginalTrackUrl using your findFirstKey function
    local audioURL = findFirstKey(data, "OriginalTrackUrl")

    -- Get album cover ID
    local albumCoverId = data[1].album.cover

    -- Print results
    print(("Downloading '%s'..."):format(fullSongName))
    displayBoxedText(bigFont, ("Downloading song '%s'..."):format(fullSongName))
    local _, rawAudioFileContents = https.request(audioURL)
    local audioExt = getFileExt(rawAudioFileContents)

    local safeFull = sanitizeFilename(fullSongName)

    if not nativefs.getInfo(getSongPath(safeFull)) then
        nativefs.createDirectory(getSongPath(safeFull))
    end

    nativefs.write(getSongPath(safeFull) .. "song." .. audioExt, rawAudioFileContents)

    print("Downloading 1280x1280 cover...")
    displayBoxedText(bigFont, "Downloading 1280x1280 cover...")

    local _, rawCoverFileContents = https.request(("https://resources.tidal.com/images/%s/1280x1280.jpg"):format(
        albumCoverId:gsub("-", "/")))
    local coverExt = getFileExt(rawCoverFileContents)

    nativefs.write(getSongPath(safeFull) .. "cover." .. coverExt, rawCoverFileContents)

    print("Getting duration...")
    displayBoxedText(bigFont, "Getting duration...")
    local audio = love.audio.newSource(getSongPath(safeFull) .. "song." .. audioExt, "stream")
    local dur = audio:getDuration()
    audio:release()

    local meta = {
        duration = dur,
        name = fullSongName,
        safeFull = safeFull,
        audioFile = ("song.%s"):format(audioExt),
        coverFile = ("cover.%s"):format(coverExt),
        instrumental = true,
        lyrics = {},
    };

    print("Getting lyrics...")
    displayBoxedText(bigFont, "Getting lyrics...")

    local _, lrclibBody = https.request(("https://lrclib.net/api/get?artist_name=%s&track_name=%s"):format(
        encodeURIComponent(artists), encodeURIComponent(title)))
    local lyrics = json.decode(lrclibBody)

    local parsedLyrics = {}

    if lyrics.syncedLyrics then
        for line in lyrics.syncedLyrics:gmatch("[^\r\n]+") do
            local m, s, ms, txt = line:match("^%[(%d+):(%d+)%.(%d+)%](.*)")
            if m and s and ms and txt then
                local time = tonumber(m) * 60 + tonumber(s) + tonumber(ms) / 100
                table.insert(parsedLyrics, { time = time, text = txt:match("^%s*(.-)%s*$") })
            end
        end
    end

    meta.instrumental = lyrics.instrumental
    meta.lyrics = parsedLyrics

    nativefs.write(getSongPath(safeFull) .. "meta.json", json.encode(meta))

    LoadSong(meta)
end

local fps = 60
local w, h = 1920 * 1, 1080 * 1
local ffmpegArgs = "-c:v h264_nvenc -cq 23 -preset p1"
local args = ("\"\"%s\" -f image2pipe -framerate %d -s %dx%d -c:v rawvideo -pix_fmt rgba -frame_size %d -i - -vf colormatrix=bt601:bt709 -pix_fmt yuv420p %s -y -movflags +faststart \"%s\"\"")
    :format("ffmpeg", fps, w, h, 4 * w * h, ffmpegArgs, "test.mp4")

local frameBatch = {}
local batchSize = 1
local thread = love.thread.newThread("src/renderThread.lua")
local canvas
if isRendering then
    thread:start(args)
    canvas = love.graphics.newCanvas(w, h, { msaa = 4 })
end

if isRendering then
    love.window.setVSync(false)
end

WindowWidth = w
WindowHeight = h

local socket = require("socket")
local frame = 0
function FinishRender()
    isRendering = false
    love.thread.getChannel("renderingStopped"):push(true)
end

function love.quit()
    FinishRender()
end

while isRendering do
    love.event.pump()
    for name, a, b, c, d, e, f in love.event.poll() do
        if name == "quit" then
            break
        end
    end

    local dt = 1 / fps

    renderer.update(dt)
    love.graphics.setCanvas(canvas)
    love.graphics.clear()
    love.graphics.setColor(love.graphics.getBackgroundColor())
    love.graphics.rectangle("fill", 0, 0, w, h)
    love.graphics.setColor(1, 1, 1)
    renderer.draw()
    love.graphics.setCanvas()
    love.graphics.setColor(1, 1, 1)

    if frame % 700 == 0 then
        love.graphics.clear()
        love.graphics.setColor(love.graphics.getBackgroundColor())
        love.graphics.rectangle("fill", 0, 0, w, h)
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(canvas)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("frame: " .. frame, 10, 10)
        love.graphics.present()
    end

    local imageData = love.graphics.readbackTexture(canvas)
    frameBatch[#frameBatch + 1] = imageData:getString()
    imageData:release()

    if #frameBatch >= batchSize then
        while love.thread.getChannel("imageData"):getCount() > 30 do
            love.timer.sleep(0.001)
        end
        love.thread.getChannel("imageData"):push(frameBatch)
        frameBatch = {}
    end

    frame = frame + 1
end
if isRendering then
    love.event.quit()
end
