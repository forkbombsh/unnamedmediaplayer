require("love.image")
require("love.event")

local pipeCommand = ...
print(pipeCommand)

local renderingStoppedChannel = love.thread.getChannel("renderingStopped")
local imageChannel = love.thread.getChannel("imageData")

-- open ffmpeg pipe
local pipe = io.popen(pipeCommand, "wb")

while true do
    -- stop condition: main says "done" AND no more frames pending
    if renderingStoppedChannel:peek() and imageChannel:getCount() == 0 then
        break
    end

    -- get next batch (raw string, may contain 1+ frames)
    local data = imageChannel:demand()
    if data then
        if type(data) == "table" then
            for i = 1, #data do
                pipe:write(data[i])
            end
        end
    end
end

renderingStoppedChannel:pop()

-- wait for ffmpeg to flush/close
pipe:read("*a")
pipe:close()
