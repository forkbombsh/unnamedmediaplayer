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

local function getAverageColor(imageData)
    local width, height = imageData:getDimensions()
    local rSum, gSum, bSum = 0, 0, 0
    local totalPixels = width * height

    for x = 0, width - 1 do
        for y = 0, height - 1 do
            local r, g, b = imageData:getPixel(x, y)
            rSum = rSum + r
            gSum = gSum + g
            bSum = bSum + b
        end
    end

    local avgR = rSum / totalPixels
    local avgG = gSum / totalPixels
    local avgB = bSum / totalPixels

    return avgR, avgG, avgB
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

local function secondsToTime(time)
    local hours = math.floor(time / 3600)
    local minutes = math.floor((time - hours * 3600) / 60)
    local seconds = math.floor(time - hours * 3600 - minutes * 60)
    return string.format("%02d:%02d:%02d", hours, minutes, seconds)
end

local songList = json.decode(love.filesystem.read("list.json") or "[]")
local rawLyrics = json.decode(love.filesystem.read("lyrics.json") or "{}")

for curIndex, song in ipairs(songList) do
    local cleanName = (song.safeFull or song.name)
    local actualName = song.name

    local lyrics = {}

    if rawLyrics[cleanName] then
        lyrics = rawLyrics[cleanName].lyrics
    end

    local thumbnailData = safeLoadImage("art/" .. cleanName .. ".jpg")
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
    local audioSource = safeLoadAudio("music/" .. cleanName .. ".wav")
    songs[curIndex] = {
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

    print(
        string.format("%d: %s (%s) - %s", curIndex, cleanName, secondsToTime(length),
            secondsToTime(totalTime)))

    totalTime = totalTime + length
end

renderer = {}

local isRendering = false

local fps = 60
-- local totalFrames = fps * 10
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

if isRendering then
    love.window.setVSync(false)
end

WindowWidth = w
WindowHeight = h

local socket = require("socket")
local startTime = socket.gettime()
local frame = 0
function FinishRender()
    isRendering = false
    love.thread.getChannel("renderingStopped"):push(true)
end

function love.quit()
    FinishRender()
end

require("src.playlist")(secondsToTime, totalTime, songs, thumbnails, arialBigBold, arialMedBold, arialSmaBold,
    triangleImg, isRendering)

while isRendering do
    love.event.pump()
    for name, a, b, c, d, e, f in love.event.poll() do
        if name == "quit" then
            -- frame = totalFrames
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

    -- local imageData = canvas:newImageData()
    local imageData = love.graphics.readbackTexture(canvas)
    -- love.thread.getChannel("imageData"):push(imageData)
    frameBatch[#frameBatch + 1] = imageData:getString()
    imageData:release()
    -- print(#frameBatch)

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
