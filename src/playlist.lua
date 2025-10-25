local flux = require("src.lib.flux")

return function(thumbnails, arialBigBold, arialMedBold, arialSmaBold, triangleImg,
                isRendering)
    collectgarbage("collect")

    local isPaused = false
    local searching = false
    local searchText = ""
    local curSongSearch
    local songSelectIndex = 1
    local songSelectScroll = 0
    local justClickedSearch = false
    local blockNextSpec = false
    local justPlayedSong = false
    local totalTime = 0
    local songs = {}
    local addSongText = ""
    local addingSong = false

    local function getCurrentSong(t)
        if #songs == 0 then
            return nil, 0
        end

        if t <= 0 then
            return songs[1], 0
        end

        for i = 1, #songs do
            local current = songs[i]
            local nextStart = (songs[i + 1] and songs[i + 1].starting_time) or (totalTime + 1)

            if t >= current.starting_time and t < nextStart then
                local relativePos = t - current.starting_time
                return current, relativePos
            end
        end

        local last = songs[#songs]
        return last, last.length
    end

    local function getCurrentSongIndex(t)
        for i = 1, #songs do
            local current = songs[i]
            local nextStart = (songs[i + 1] and songs[i + 1].starting_time) or (totalTime + 1)
            if t >= current.starting_time and t < nextStart then
                return i
            end
        end
        return #songs
    end

    local function cutString(str, maxLen)
        if #str > maxLen then
            return str:sub(1, maxLen - 3) .. "..."
        else
            return str
        end
    end

    local time = 0
    local currentPlaying = nil

    local function stopAll()
        for _, v in ipairs(songs) do
            if v.audio and v.audio:isPlaying() then
                v.audio:stop()
            end
        end
    end

    local function play()
        stopAll()
        local song, relativePos = getCurrentSong(time)
        if not song or not song.audio then
            return
        end

        if relativePos < 0 then relativePos = 0 end
        if relativePos > song.length then relativePos = song.length end

        song.audio:seek(relativePos)
        if not isRendering then
            song.audio:play()
        end
        currentPlaying = song
    end

    local function seek(diff)
        time = time + diff
        if time < 0 then time = 0 end
        if time > totalTime then time = totalTime end
        play()
        justPlayedSong = true
    end

    play()

    local function get_line_count(str)
        local lines = 1
        for i = 1, #str do
            local c = str:sub(i, i)
            if c == '\n' then lines = lines + 1 end
        end

        return lines
    end

    local function searchSongs(query)
        local results = {}
        local q = query:lower()
        for _, v in ipairs(songs) do
            if v.actualName:lower():find(q, 1, true) then -- plain text search
                table.insert(results, v)
            end
        end
        return results
    end

    curSongSearch = searchSongs(searchText)

    local textOutlineCached = {}

    local function drawTextWithOutline(text, font, x, y)
        local outlineColor = { 0, 0, 0, 1 }
        local textColor    = { 1, 1, 1, 1 }

        local offsets      = {
            { -1, -1 }, { 0, -1 }, { 1, -1 },
            { -1, 0 }, { 1, 0 },
            { -1, 1 }, { 0, 1 }, { 1, 1 },
        }
        if not textOutlineCached[text .. tostring(font)] then
            textOutlineCached[text .. tostring(font)] = love.graphics.newCanvas(font:getWidth(text),
                font:getHeight() * (get_line_count(text)))
            local canvas = textOutlineCached[text .. tostring(font)]
            local r, g, b, a = love.graphics.getColor()
            local curCanvas = love.graphics.getCanvas()
            love.graphics.setCanvas(canvas)
            love.graphics.clear()
            love.graphics.setColor(outlineColor)
            for _, off in ipairs(offsets) do
                love.graphics.print(text, font, off[1], off[2])
            end
            love.graphics.setColor(textColor)
            love.graphics.print(text, font)
            love.graphics.setCanvas(curCanvas)
            love.graphics.setColor(r, g, b, a)
            love.graphics.draw(canvas, math.floor(x), math.floor(y))
        else
            local canvas = textOutlineCached[text .. tostring(font)]
            love.graphics.draw(canvas, math.floor(x), math.floor(y))
        end
    end

    local function drawTextWithOutlineRealtime(text, font, x, y)
        local outlineColor = { 0, 0, 0, 1 }
        local textColor    = { 1, 1, 1, 1 }

        local offsets      = {
            { -1, -1 }, { 0, -1 }, { 1, -1 },
            { -1, 0 }, { 1, 0 },
            { -1, 1 }, { 0, 1 }, { 1, 1 },
        }

        -- Save old state
        local r, g, b, a   = love.graphics.getColor()
        local oldFont      = love.graphics.getFont()

        -- Set font
        love.graphics.setFont(font)

        -- Draw outline
        love.graphics.setColor(outlineColor)
        for _, off in ipairs(offsets) do
            love.graphics.print(text, x + off[1], y + off[2])
        end

        -- Draw main text
        love.graphics.setColor(textColor)
        love.graphics.print(text, x, y)

        -- Restore state
        love.graphics.setFont(oldFont)
        love.graphics.setColor(r, g, b, a)
    end

    local function drawTextWithOutlineRealtimef(text, font, x, y, limit, t)
        local outlineColor = { 0, 0, 0, 1 }
        local textColor    = { 1, 1, 1, 1 }

        local offsets      = {
            { -1, -1 }, { 0, -1 }, { 1, -1 },
            { -1, 0 }, { 1, 0 },
            { -1, 1 }, { 0, 1 }, { 1, 1 },
        }

        -- Save old state
        local r, g, b, a   = love.graphics.getColor()
        local oldFont      = love.graphics.getFont()

        -- Set font
        love.graphics.setFont(font)

        -- Draw outline
        love.graphics.setColor(outlineColor)
        for _, off in ipairs(offsets) do
            love.graphics.printf(text, x + off[1], y + off[2], limit, t)
        end

        -- Draw main text
        love.graphics.setColor(textColor)
        love.graphics.printf(text, x, y, limit, t)

        -- Restore state
        love.graphics.setFont(oldFont)
        love.graphics.setColor(r, g, b, a)
    end

    local function getCurrentLyricIndex(song)
        for i, v in ipairs(song.lyrics) do
            if song.audio:tell() >= v.time then
                return i
            end
        end
    end

    local function getCurrentLyric(song)
        local text = ""
        for i, v in ipairs(song.lyrics) do
            if time - song.starting_time >= v.time then
                text = v.text
            end
        end
        return text
    end

    local function getPrevLyric(song)
        local prev = ""
        local currentIndex = nil

        for i, v in ipairs(song.lyrics) do
            if time - song.starting_time >= v.time then
                currentIndex = i
            else
                break
            end
        end

        if currentIndex and currentIndex > 1 then
            prev = song.lyrics[currentIndex - 1].text
        end

        return prev
    end

    local function getNextLyricAtTime(song, relPos)
        for i, v in ipairs(song.lyrics) do
            if v.time > relPos then
                return v.time
            end
        end
        return nil
    end

    local function getNextLyric(song)
        for i, v in ipairs(song.lyrics) do
            if v.time > (time - song.starting_time) then
                return v.text
            end
        end
        return nil
    end

    local function getNextLyricTime(song, relPos)
        for i, v in ipairs(song.lyrics) do
            if v.time > relPos then
                return v.time
            end
        end
        return nil
    end

    local abt = { 0, 0, 0 }

    local oldSongName = ""

    function renderer.addSong(song)
        songs[#songs + 1] = song
        totalTime = totalTime + song.length
    end

    function renderer.update(dt)
        if not isPaused then
            time = time + dt
        end

        local song, relativePos = getCurrentSong(time)

        if song then
            local relPos = time - song.starting_time
            local nextLyricTime = getNextLyricTime(song, relPos)
            local nextLyric = getNextLyricAtTime(song, relPos)
            local currentLyric = getCurrentLyric(song)

            local screenWidth = WindowWidth
            local yoff = 30
            local ty = WindowHeight - arialMedBold:getHeight() - (106 - yoff)
            local topBound = (GlobalConfig.albumArtFullscreen and 0 or arialBigBold:getHeight() + arialMedBold:getHeight() + 35)
            local bottomBound = ty - 10
            local verticalSpace = GlobalConfig.albumArtFullscreen and WindowHeight or bottomBound - topBound
            local size = math.min(screenWidth, verticalSpace) * (GlobalConfig.albumArtFullscreen and 1 or 0.8)
            local x = ((screenWidth - size) / 2)
            local y = topBound + (verticalSpace - size) / 2

            local nabx, naby, nabs

            local function small()
                local ny = arialBigBold:getHeight() + arialMedBold:getHeight() + 40
                nabx, naby, nabs = 50, ny + 50, 300
            end

            local function big()
                nabx, naby, nabs = x, y, size
            end

            if GlobalConfig.albumArtResizeWithLyrics then
                if currentLyric == "" and (nextLyricTime and nextLyricTime - relPos < GlobalConfig.albumResizeLyricsBuffer or false) and nextLyric ~= "" then
                    small()
                elseif currentLyric == "" then
                    big()
                elseif currentLyric ~= "" then
                    small()
                else
                    big()
                end
            else
                big()
            end

            local abx, aby, abs = abt[1], abt[2], abt[3]
            if nabx ~= abx or naby ~= aby or nabs ~= abs then
                if GlobalConfig.instantAlbumArtResize then
                    abt[1], abt[2], abt[3] = nabx, naby, nabs
                else
                    flux.to(abt, GlobalConfig.albumResizeTime, { nabx, naby, nabs }):ease("quartout")
                end
            end
        end

        if not isRendering then
            WindowWidth, WindowHeight = love.graphics.getDimensions()
        end

        if time >= totalTime + 1 then
            time = totalTime
            FinishRender()
        end

        if currentPlaying then
            if song ~= currentPlaying then
                play()
            else
                local audioPos = currentPlaying.audio:tell()
                if math.abs(audioPos - relativePos) > 0.5 then
                    currentPlaying.audio:seek(relativePos)
                end
            end
        else
            play()
        end

        if not isRendering and song then
            if isPaused then
                song.audio:pause()
            else
                song.audio:play()
            end
        end

        if song and oldSongName ~= song.name and GlobalConfig.randomSongs then
            if justPlayedSong then
                oldSongName = song.name
            else
                local randomSong = songs[love.math.random(#songs)]
                oldSongName = randomSong.name
                time = randomSong.starting_time
                play()
            end
        end

        if curSongSearch then
            if songSelectIndex > #curSongSearch then
                songSelectIndex = #curSongSearch
            end
        end

        flux.update(dt)
        justPlayedSong = false
    end

    local function drawUI(songName, curSongTime, songLength, nextStr, prevStr, songIdx, yoff, ty, song)
        if not GlobalConfig.drawUI then
            return
        end
        local colour = song.colour
        local lighterColour = song.lighterColour
        if not GlobalConfig.colourMatchesAlbumArt then
            colour = GlobalConfig.colour or { 0.5, 0.5, 0.5 }
            lighterColour = { colour[1] * 1.25, colour[2] * 1.25, colour[3] * 1.25 }
        end
        love.graphics.setColor(colour)
        love.graphics.rectangle("fill", 0, 0, WindowWidth, WindowHeight)
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle("fill", 0, 0, WindowWidth,
            arialBigBold:getHeight() + arialMedBold:getHeight() + 40)
        love.graphics.setColor(1, 1, 1)
        drawTextWithOutlineRealtime(songName, arialBigBold, 20, 10)
        drawTextWithOutlineRealtime(
            string.format("%s / %s", secondsToTime(curSongTime),
                secondsToTime(songLength)),
            arialMedBold, 20, arialBigBold:getHeight() + 10 + 10
        )
        local songText = "Song #" .. songIdx
        drawTextWithOutlineRealtime(songText, arialMedBold, WindowWidth - arialMedBold:getWidth(songText) - 20,
            arialBigBold:getHeight() - 5)
        love.graphics.setColor(0, 0, 0, 0.5)

        love.graphics.rectangle("fill", 0, ty - 15, WindowWidth,
            WindowHeight - ty + 15)

        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.rectangle("fill", 20, ty + 50, WindowWidth - 40, 40, 10)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("line", 20, ty + 50, WindowWidth - 40, 40, 10)
        local w = ((WindowWidth - 44) / totalTime) * time
        if w < 1 then
            w = 1
        end
        love.graphics.rectangle("fill", 22, ty + 50,
            w,
            40, 10)

        drawTextWithOutlineRealtimef(
            string.format("%s / %s", secondsToTime(time),
                secondsToTime(totalTime)),
            arialMedBold, 0, ty, WindowWidth,
            "center"
        )

        if not GlobalConfig.colourMatchesAlbumArt then
            love.graphics.setColor(GlobalConfig.borderColour)
        else
            love.graphics.setColor(lighterColour)
        end
        love.graphics.rectangle("fill", 0, arialBigBold:getHeight() + arialMedBold:getHeight() + 35,
            WindowWidth, 10)

        love.graphics.rectangle("fill", 0, ty - 15 - 5, WindowWidth, 10)

        love.graphics.setColor(1, 1, 1)

        if GlobalConfig.showPrevSong and songIdx > 1 then
            love.graphics.draw(triangleImg, 40,
                WindowHeight - (triangleImg:getHeight() * 0.25) - 110 + yoff,
                math.pi / 2, 0.25,
                0.2)

            drawTextWithOutlineRealtime(cutString(prevStr, 40), arialMedBold, 60,
                ty)
        end

        if GlobalConfig.showNextSong and nextStr ~= songName then
            drawTextWithOutlineRealtimef(cutString(nextStr, 40), arialMedBold, -60,
                ty,
                WindowWidth, "right")

            love.graphics.draw(triangleImg, WindowWidth - 40,
                WindowHeight - (triangleImg:getHeight() * 0.25) - 86 + yoff,
                -math.pi / 2, 0.25,
                0.2)
        end
    end

    local function drawSearches()
        if searching then
            love.graphics.setColor(0, 0, 0, 1)
            local searchWidth = arialSmaBold:getWidth(searchText)
            local searchHeight = arialSmaBold:getHeight()
            love.graphics.rectangle("fill", 9, 9, searchWidth + 2, searchHeight + 2)
            if curSongSearch then
                for i = 1, #curSongSearch do
                    local song = curSongSearch[i]
                    if searchWidth < arialSmaBold:getWidth(song.actualName) then
                        searchWidth = arialSmaBold:getWidth(song.actualName)
                    end
                end
                for i = 1, #curSongSearch do
                    local song = curSongSearch[i + songSelectScroll]
                    local y = 9 + i * (searchHeight + 2)
                    if song then
                        local col = songSelectIndex == i and 0.5 or 0
                        love.graphics.setColor(col, col, col, 1)
                        love.graphics.rectangle("fill", 9, y, searchWidth + 2, searchHeight + 2)
                        love.graphics.setColor(1, 1, 1, 1)
                        love.graphics.print(song.actualName, arialSmaBold, 10, y + 2)
                    end
                    if y + searchHeight + 2 > WindowHeight then
                        break
                    end
                end
            end
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print(searchText, arialSmaBold, 10, 10)
        end

        if addingSong then
            love.graphics.setColor(0, 0, 0, 1)
            local searchWidth = arialSmaBold:getWidth(addSongText)
            local searchHeight = arialSmaBold:getHeight()
            love.graphics.rectangle("fill", 9, 9, searchWidth + 2, searchHeight + 2)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print(addSongText, arialSmaBold, 10, 10)
        end
    end

    function renderer.draw()
        local song = getCurrentSong(time)
        local yoff = 30
        local ty = WindowHeight - arialMedBold:getHeight() - (106 - yoff)
        if not song then
            drawUI("?", 0, 0, "???", "???", 0, yoff, ty, {
                lighterColour = { 0.5, 0.5, 0.5 },
                colour = { 0.4, 0.4, 0.4 }
            })
            drawSearches()
            return
        end
        local upNext = getCurrentSong(time + song.length - song.audio:tell() + 1)
        local currentTime = time
        local currentIndex = getCurrentSongIndex(currentTime)
        local prevIndex = currentIndex - 1
        if prevIndex < 1 then prevIndex = #songs end
        local prevSong = songs[prevIndex]
        local prev = getCurrentSong(prevSong.starting_time)
        if song then
            drawUI(song.actualName, song.audio:tell(), song.audio:getDuration(), upNext.actualName, prev
                .actualName, currentIndex, yoff, ty, song)

            if GlobalConfig.showAlbumArt then
                local curThumbnail = thumbnails[song.index]
                local abx, aby, abs = abt[1], abt[2], abt[3]
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(curThumbnail, abx, aby, 0, abs / curThumbnail:getWidth(),
                    abs / curThumbnail:getHeight())
                if GlobalConfig.colourMatchesAlbumArt then
                    love.graphics.setColor(song.lighterColour)
                else
                    love.graphics.setColor(GlobalConfig.albumArtBorderColour)
                end
                love.graphics.rectangle("line", abx, aby, abs, abs)
            end

            love.graphics.setColor(1, 1, 1, 1)

            if GlobalConfig.showLyrics then
                local currentLyric = getCurrentLyric(song)

                if #song.lyrics > 0 and currentLyric ~= "" then
                    local lyricsColour = GlobalConfig.lyricsColour
                    local prevLyric = getPrevLyric(song)
                    local nextLyric = getNextLyric(song)

                    local lineHeight = arialBigBold:getHeight()
                    local wrapWidth = WindowWidth / 1.5

                    local _, wrappedCurrent = arialBigBold:getWrap(currentLyric, wrapWidth)
                    for j, line in ipairs(wrappedCurrent) do
                        local y = WindowHeight / 2 + (j - 1) * lineHeight
                        love.graphics.setColor(lyricsColour[1], lyricsColour[2], lyricsColour[3], 1)
                        drawTextWithOutline(line, arialBigBold, WindowWidth / 2 - arialBigBold:getWidth(line) / 2, y)
                    end

                    if GlobalConfig.showPrevLyric and prevLyric and prevLyric ~= song.lyrics[#song.lyrics].text then
                        love.graphics.setColor(lyricsColour[1], lyricsColour[2], lyricsColour[3], 0.25)
                        local _, wrappedPrev = arialBigBold:getWrap(prevLyric, wrapWidth)
                        for j = 1, #wrappedPrev do
                            local line = wrappedPrev[#wrappedPrev - j + 1]
                            local y = WindowHeight / 2 - j * lineHeight
                            drawTextWithOutline(line, arialBigBold, WindowWidth / 2 - arialBigBold:getWidth(line) / 2, y)
                        end
                        love.graphics.setColor(lyricsColour[1], lyricsColour[2], lyricsColour[3], 1)
                    end

                    if GlobalConfig.showNextLyric and nextLyric then
                        love.graphics.setColor(lyricsColour[1], lyricsColour[2], lyricsColour[3], 0.5)
                        local _, wrappedNext = arialBigBold:getWrap(nextLyric, wrapWidth)
                        for j, line in ipairs(wrappedNext) do
                            local y = WindowHeight / 2 + #wrappedCurrent * lineHeight + (j - 1) * lineHeight
                            drawTextWithOutline(line, arialBigBold, WindowWidth / 2 - arialBigBold:getWidth(line) / 2, y)
                        end
                        love.graphics.setColor(lyricsColour[1], lyricsColour[2], lyricsColour[3], 1)
                    end
                end
            end
            love.graphics.setColor(1, 1, 1, 1)
        end

        drawSearches()
        love.graphics.setColor(1, 1, 1, 1)
    end

    local function playSongFromSearch()
        local song
        if #curSongSearch == 1 then
            song = curSongSearch[1]
        elseif #curSongSearch > 1 then
            local idx = math.max(1, math.min(#curSongSearch, songSelectIndex + songSelectScroll))
            song = curSongSearch[idx]
        else
            return
        end
        if song then
            time = song.starting_time
            play()
        end
        searching = false
        searchText = ""
        songSelectIndex = 1
        songSelectScroll = 0
        justPlayedSong = true
        curSongSearch = searchSongs(searchText)
    end

    if not isRendering then
        love.draw = renderer.draw
        love.update = renderer.update
        function love.mousepressed(x, y, button)
            if not searching then
                if button == 1 then
                    local ww = WindowWidth
                    time = (x / ww) * totalTime
                    justPlayedSong = true
                    play()
                end
            else
                playSongFromSearch()
                justClickedSearch = true
            end
        end

        function love.mousemoved(x, y)
            if searching then
                songSelectIndex = math.max(1, math.floor((y - 9) / (arialSmaBold:getHeight() + 2)))
            end
            if not love.mouse.isDown(1) or searching or justClickedSearch then
                return
            end
            local ww = WindowWidth
            time = (x / ww) * totalTime
            justPlayedSong = true
            play()
        end

        function love.mousereleased()
            if justClickedSearch then
                justClickedSearch = false
            end
        end

        love.keyboard.setKeyRepeat(true)

        function love.wheelmoved(dx, dy)
            if searching then
                songSelectScroll = songSelectScroll - math.floor(dy)
            end
        end

        function love.keypressed(key)
            if key == "right" then
                seek(10)
            elseif key == "left" then
                seek(-10)
            end
            if not searching and not addingSong then
                if key == "space" then
                    isPaused = not isPaused
                elseif key == "/" then
                    searching = true
                    searchText = ""
                    songSelectIndex = math.max(1, math.floor((love.mouse.getY() - 9) / (arialSmaBold:getHeight() + 2)))
                    love.keyboard.setTextInput(searching)
                    curSongSearch = searchSongs(searchText)
                elseif key == "." then
                    addingSong = true
                    addSongText = ""
                    love.keyboard.setTextInput(addingSong)
                elseif key == "r" then
                    GlobalConfig = json.decode(love.filesystem.read("config.json"))
                end
            end
            if searching then
                if key == "escape" then
                    searching = false
                    searchText = ""
                    songSelectScroll = 0
                    love.keyboard.setTextInput(searching)
                    curSongSearch = searchSongs(searchText)
                    blockNextSpec = false
                elseif key == "backspace" then
                    searchText = string.sub(searchText, 1, #searchText - 1)
                    curSongSearch = searchSongs(searchText)
                elseif key == "down" then
                    songSelectIndex = songSelectIndex + 1
                    if songSelectIndex > #curSongSearch then
                        songSelectIndex = 1
                    end
                elseif key == "up" then
                    songSelectIndex = songSelectIndex - 1
                    if songSelectIndex < 1 then
                        songSelectIndex = #curSongSearch
                    end
                elseif key == "return" then
                    playSongFromSearch()
                    blockNextSpec = true
                end
            end
            if addingSong then
                if key == "escape" then
                    addingSong = false
                    addSongText = ""
                    love.keyboard.setTextInput(addingSong)
                    blockNextSpec = false
                elseif key == "backspace" then
                    addSongText = string.sub(addSongText, 1, #addSongText - 1)
                elseif key == "return" then
                    addingSong = false
                    GetSong(addSongText)
                    addSongText = ""
                    blockNextSpec = true
                end
            end
        end

        function love.textinput(t)
            if blockNextSpec and (t == "/" or t == ".") then
                blockNextSpec = false
                return
            end
            if searching then
                searchText = searchText .. t
                curSongSearch = searchSongs(searchText)
            end
            if addingSong then
                addSongText = addSongText .. t
            end
        end
    end
end
