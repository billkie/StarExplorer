
local composer = require( "composer" )

local scene = composer.newScene()

-- -----------------------------------------------------------------------------------
-- Code outside of the scene event functions below will only be executed ONCE unless
-- the scene is removed entirely (not recycled) via "composer.removeScene()"
-- -----------------------------------------------------------------------------------

local physics = require( "physics" )
physics.start()
physics.setGravity( 0, 0 )

-- Configure image sheet
local sheetOptions =
{
    frames =
    {
        {   -- 1) asteroid 1
            x = 0,
            y = 0,
            width = 102,
            height = 85
        },
        {   -- 2) asteroid 2
            x = 0,
            y = 85,
            width = 90,
            height = 83
        },
        {   -- 3) asteroid 3
            x = 0,
            y = 168,
            width = 100,
            height = 97
        },
        {   -- 4) ship
            x = 0,
            y = 265,
            width = 98,
            height = 79
        },
        {   -- 5) laser
            x = 98,
            y = 265,
            width = 14,
            height = 40
        },
    },
}
local objectSheet = graphics.newImageSheet( "gameObjects.png", sheetOptions )

-- Initialize variables
local lives = 3
local score = 0
local highScore
local died = false

local asteroidsTable = {}

local ship
local shipController
local gameLoopTimer
local livesText
local scoreText
local highScoreText

local backGroup
local mainGroup
local uiGroup

local explosionSound
local fireSound
local musicTrack

local json = require( "json" )

local explosionFilePath = system.pathForFile( "particles/explosion2.json" )
local explosionParams
-- local explosionEmitter

local laserFilePath = system.pathForFile( "particles/lasertrail.json" )
local laserParams
-- local laserEmitter

local function getEmitterParams()
	local expFile = io.open( explosionFilePath, "r" )
	local expEmitterData = expFile:read( "*a" )
	expFile:close()
	explosionParams = json.decode( expEmitterData )

	local laserFile = io.open( laserFilePath, "r" )
	local laserEmitterData = laserFile:read( "*a" )
	laserFile:close()
	laserParams = json.decode( laserEmitterData )

end


local function updateText()
	livesText.text = lives
	scoreText.text = score
end

local function createAsteroid()

    local whichAsteroid = math.random(3)

	local newAsteroid = display.newImageRect( mainGroup, objectSheet, whichAsteroid, 102, 85 )
	table.insert( asteroidsTable, newAsteroid )
	physics.addBody( newAsteroid, "dynamic", { radius=40, bounce=0.8 } )
	newAsteroid.myName = "asteroid"

	local whereFrom = math.random( 3 )

	if ( whereFrom == 1 ) then
		-- From the left
		newAsteroid.x = -60
		newAsteroid.y = math.random( 500 )
		newAsteroid:setLinearVelocity( math.random( 40,120 ), math.random( 20,60 ) )
	elseif ( whereFrom == 2 ) then
		-- From the top
		newAsteroid.x = math.random( display.contentWidth )
		newAsteroid.y = -60
		newAsteroid:setLinearVelocity( math.random( -40,40 ), math.random( 40,120 ) )
	elseif ( whereFrom == 3 ) then
		-- From the right
		newAsteroid.x = display.contentWidth + 60
		newAsteroid.y = math.random( 500 )
		newAsteroid:setLinearVelocity( math.random( -120,-40 ), math.random( 20,60 ) )
	end

	newAsteroid:applyTorque( math.random( -6,6 ) )
end

local function fireLaser()

	-- play laser sound
	audio.play(fireSound)

	local newLaser = display.newImageRect( mainGroup, objectSheet, 5, 14, 40 )
	physics.addBody( newLaser, "dynamic", { isSensor=true } )
	newLaser.isBullet = true
	newLaser.myName = "laser"

	newLaser.x = ship.x
	newLaser.y = ship.y
	newLaser:toBack()

	--load and fire particles
	local laserEmitter = display.newEmitter( laserParams )
	laserEmitter.x = newLaser.x
	laserEmitter.y = newLaser.y
	mainGroup:insert(laserEmitter)
	laserEmitter:toBack()

	laserEmitter:start()

	newLaser.emitter = laserEmitter

	transition.to( newLaser, { y=-40, time=500,
		onComplete = function() display.remove( newLaser ) end
	} )

	transition.to( laserEmitter, { y=-1000, time=1200,
		onComplete = function() display.remove( laserEmitter ) end
	} )

end

local function dragShip( event )

	-- local ship = event.target
	local phase = event.phase
	if ship.x ~= nil then -- check that ship is not destroyed
		if ( "began" == phase ) then
			-- Set touch focus on the ship
			-- display.currentStage:setFocus( event.target )
			-- Store initial offset position
			ship.touchOffsetX = event.x - ship.x

		elseif ( "moved" == phase ) then
			-- Move the ship to the new touch position
			ship.x = event.x - ship.touchOffsetX
			-- transition.to(ship, {time=500, delay=0, x=event.x})

			if(ship.x < 150) then
				ship.x = 150
			elseif(ship.x > (display.contentWidth - 150)) then
				ship.x = display.contentWidth - 150
			end

		elseif ( "ended" == phase or "cancelled" == phase ) then
			-- Release touch focus on the ship
			-- display.currentStage:setFocus( nil )
		end
	end

	return true  -- Prevents touch propagation to underlying objects
end

local function gameLoop()

	-- Create new asteroid
	createAsteroid()

	-- Remove asteroids which have drifted off screen
	for i = #asteroidsTable, 1, -1 do
		local thisAsteroid = asteroidsTable[i]

		if ( thisAsteroid.x < -100 or
			 thisAsteroid.x > display.contentWidth + 100 or
			 thisAsteroid.y < -100 or
			 thisAsteroid.y > display.contentHeight + 100 )
		then
			display.remove( thisAsteroid )
			table.remove( asteroidsTable, i )
		end
	end
end

local function restoreShip()

	ship.isBodyActive = false
	ship.x = display.contentCenterX
	ship.y = display.contentHeight - 200

	-- Fade in the ship
	transition.to( ship, { alpha=1, time=4000,
		onComplete = function()
			ship.isBodyActive = true
			died = false
		end
	} )
end

local function endGame()
	composer.setVariable("finalScore", score)
	composer.gotoScene("highscores", {time=800, effect="crossFade"})
end

local function onCollision( event )

	if ( event.phase == "began" ) then

		local obj1 = event.object1
		local obj2 = event.object2

		if ( ( obj1.myName == "laser" and obj2.myName == "asteroid" ) or
			 ( obj1.myName == "asteroid" and obj2.myName == "laser" ) )
		then

			--load and fire particles
			local explosionEmitter = display.newEmitter( explosionParams )
			explosionEmitter.x = obj1.x
			explosionEmitter.y = obj1.y

			explosionEmitter:start()

			if obj1.emitter ~= nil then
				obj1.emitter:stop()
			end
			if obj2.emitter ~= nil then
				obj2.emitter:stop()
			end

			-- Remove both the laser and asteroid
			display.remove( obj1 )
			display.remove( obj2 )

			-- play explosion sound
			audio.play(explosionSound)

			

			for i = #asteroidsTable, 1, -1 do
				if ( asteroidsTable[i] == obj1 or asteroidsTable[i] == obj2 ) then
					table.remove( asteroidsTable, i )
					break
				end
			end

			-- Increase score
			score = score + 100
			if score > highScore then
				highScore = score
			end
			scoreText.text = score
			highScoreText.text = highScore

		elseif ( ( obj1.myName == "ship" and obj2.myName == "asteroid" ) or
				 ( obj1.myName == "asteroid" and obj2.myName == "ship" ) )
		then
			if ( died == false ) then
				died = true

				--load and fire particles
				local shipExplosionEmitter = display.newEmitter( explosionParams )
				shipExplosionEmitter.x = ship.x
				shipExplosionEmitter.y = ship.y

				shipExplosionEmitter:start()

				-- play explosion sound
				audio.play(explosionSound)

				-- Update lives
				lives = lives - 1
				livesText.text = lives

				if ( lives == 0 ) then
					display.remove( ship )
					timer.performWithDelay(2000, endGame)
				else
					ship.alpha = 0
					timer.performWithDelay( 1000, restoreShip )
				end
			end
		end
	end
end

-- -----------------------------------------------------------------------------------
-- Scene event functions
-- -----------------------------------------------------------------------------------

-- create()
function scene:create( event )

	local sceneGroup = self.view
	-- Code here runs when the scene is first created but has not yet appeared on screen

	physics.pause() -- temporarily pause the physics engine

	-- set up display groups
	backGroup = display.newGroup() -- display group for background image
	sceneGroup:insert(backGroup) -- insert into scene view group
	
	mainGroup = display.newGroup() -- display group for ship, asteroids, lasers etc
	sceneGroup:insert(mainGroup) -- insert into scene view group

	uiGroup = display.newGroup() -- display group for ui objects
	sceneGroup:insert(uiGroup) -- insert into scene view group

	-- load the background
	local background = display.newImageRect(backGroup, "background.png", 800, 1400)
	background.x = display.contentCenterX
	background.y = display.contentCenterY

	-- load ship
	ship = display.newImageRect(mainGroup, objectSheet, 4, 98, 79)
	ship.x = display.contentCenterX
	ship.y = display.contentHeight - 200
	ship.touchOffsetX = 0
	physics.addBody(ship, {radius=30, isSensor=true})
	ship.myName = "ship"

	shipController = display.newRect(mainGroup, display.contentCenterX, display.contentHeight - 20, display.contentWidth, 500)
	shipController.isHitTestable = true
	shipController.alpha = 0

	highScore = composer.getVariable("highScore")

	-- display lives and score
	local livesLabel = display.newText(uiGroup, "Lives", 200, 40, native.systemFont, 30)
	local scoreLabel = display.newText(uiGroup, "Score", 375, 40, native.systemFont, 30)
	local highScoreLabel = display.newText(uiGroup, "Highscore", 550, 40, native.systemFont, 30)

	livesText = display.newText(uiGroup, lives, 200, 80, native.systemFont, 30)
	scoreText = display.newText(uiGroup, score, 375, 80, native.systemFont, 30)
	highScoreText = display.newText(uiGroup, highScore, 550, 80, native.systemFont, 30)

	-- ship:addEventListener("tap", fireLaser)
	shipController:addEventListener("touch", dragShip)
	

	explosionSound = audio.loadSound("audio/explosion.wav")
	fireSound = audio.loadSound("audio/fire.wav")
	musicTrack = audio.loadStream("audio/80s-Space-Game_Looping.wav")

	

	getEmitterParams()

end


-- show()
function scene:show( event )

	local sceneGroup = self.view
	local phase = event.phase

	if ( phase == "will" ) then
		-- Code here runs when the scene is still off screen (but is about to come on screen)

	elseif ( phase == "did" ) then
		-- Code here runs when the scene is entirely on screen
		Runtime:addEventListener("tap", fireLaser)
		physics.start()
        Runtime:addEventListener( "collision", onCollision )
		gameLoopTimer = timer.performWithDelay( 500, gameLoop, 0 )
		-- start the music
		audio.play(musicTrack, {channel=1, loops=-1})
		audio.fade( { channel=1, time=800, volume=0.5 } )

	end
end


-- hide()
function scene:hide( event )

	local sceneGroup = self.view
	local phase = event.phase

	if ( phase == "will" ) then
		-- Code here runs when the scene is on screen (but is about to go off screen)
		timer.cancel(gameLoopTimer)
		audio.fade( { channel=1, time=800, volume=0 } )
		Runtime:removeEventListener("tap", fireLaser)

	elseif ( phase == "did" ) then
		-- Code here runs immediately after the scene goes entirely off screen
		Runtime:removeEventListener("collision", onCollision)
		physics.pause()
		-- stop the music
		audio.stop(1)
		composer.removeScene("game")
	end
end


-- destroy()
function scene:destroy( event )

	local sceneGroup = self.view
	-- Code here runs prior to the removal of scene's view
	-- dispose audio
	audio.dispose(explosionSound)
	audio.dispose(fireSound)
	audio.dispose(musicTrack)

end


-- -----------------------------------------------------------------------------------
-- Scene event function listeners
-- -----------------------------------------------------------------------------------
scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )
-- -----------------------------------------------------------------------------------

return scene
