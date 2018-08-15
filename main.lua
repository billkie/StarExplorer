local composer = require("composer")
local json = require("json")
local scoresTable = {}
local filePath = system.pathForFile("scores.json", system.DocumentsDirectory)

-- hide status bar
display.setStatusBar(display.HiddenStatusBar)

-- seed the random number generator
math.randomseed(os.time())

-- reserve channel 1 for bgm
audio.reserveChannels(1)
-- reduce overall volume of channel
audio.setVolume(0, {channel=1})

-- go to menu screen
composer.gotoScene("menu")

local file = io.open(filePath, "r")

if file then
	local contents = file:read("*a")
	io.close(file)
	scoresTable = json.decode(contents)
end

if(scoresTable == nil or #scoresTable == 0) then
	scoresTable = { 10000, 7500, 5200, 4700, 3500, 3200, 1200, 1100, 800, 500 }
end

composer.setVariable("highScore", scoresTable[1])