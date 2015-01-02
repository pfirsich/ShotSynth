function love.load()	
	lastPressedSpace = false
	lastR = false
	lastS = false
	currentSound = {}
	messageStr = ""
	
	shotsToFire = 0
	nextShot = 0
end

function getSaveFile()
	return "soundProps.lua"
end

function dictToStr(dict)
	str = " = {\n"
	for k, v in pairs(dict) do
		str = str .. "\t" .. k .. " = " .. v .. ",\n"
	end
	str = str:sub(1, str:len() - 2) .. "\n}"
	return str
end

function saveSoundProperties(sound)
	file, errorStr = love.filesystem.newFile("soundProps.lua", "w")
	if file then
		file:write("properties" .. dictToStr(sound.properties))
		file:close()
		messageStr = "File saved."
	else
		messageStr = errorStr
	end
end

function osz_sin(freq, t)
	return math.sin(2*math.pi*freq * t)
end

function osz_square(freq, t)
	local s = t * freq - math.floor(t * freq)
	return math.floor(s + 0.5) * 2.0 - 1.0
end

function osz_tri(freq, t)
	local s = t * freq - math.floor(t * freq)
	return s * 2.0 - 1.0
end

function osz_whistle(freq, t)
	local mix = 0.2
	return (1 - mix) * math.sin(2*math.pi*freq * t) + mix * math.sin(2*math.pi*freq * 10.0 * t)
end

function osz_mix(oszA, oszB, mix)
	return function(freq, t) return (1 - mix) * oszA(freq, t) + mix * oszB(freq, t) end
end

function envelope(sustain, decay, t)
	if t < sustain then
		return 1.0
	elseif t < decay + sustain then 
		return 1.0 - 1.0 / decay * (t - sustain)
	else
		return 0.0
	end
end

function getRMS(soundData)
	integral = 0
	for i = 0, soundData:getSampleCount() - 1 do
		local s = soundData:getSample(i)
		integral = integral + s*s
	end
	return math.sqrt(integral / (soundData:getSampleCount() / soundData:getSampleRate()))
end

function generateShootSound(properties)
	local sampleRate = 44100
	local samples = 1.0 * 44100
	local osz_table = {osz_sin, osz_square, osz_tri, osz_whistle}
	
	soundData = love.sound.newSoundData(samples, sampleRate, 16, 1)
	
	local f = properties.fStart
	local osz = osz_mix(osz_table[properties.oszA], osz_table[properties.oszB], properties.oszMix)
	
	for i = 0, samples - 1 do
		f = f - properties.fSpeed * f
		if f < properties.fCutoff then 
			f = properties.fCutoff - 0.001
		end
		
		local sample = f < properties.fCutoff and 0 or 
								osz(f, i / sampleRate) * envelope(properties.sustain, properties.decay, i/samples)
		soundData:setSample(i, sample)
	end
	
	local rms = getRMS(soundData)
	local targetrms = 15.0
	messageStr = "RMS: " .. tostring(rms)
	for i = 0, samples - 1 do
		soundData:setSample(i, soundData:getSample(i) * targetrms / rms)
	end
	
	return {properties = properties, soundData = soundData}
end

function love.update()
	if love.keyboard.isDown(" ") and lastPressedSpace == false then
		local fStart = love.math.random(200.0, 1000.0)
		currentSound = generateShootSound({
			oszA = love.math.random(1, 4),
			oszB = love.math.random(1, 4), 
			oszMix = love.math.random(),
			fStart = fStart,
			fCutoff = math.max(fStart - love.math.random(100, 500), 30),
			fSpeed = 0.00005 + love.math.random() * 0.00002,
			decay = love.math.random() * 0.2 + 0.1,
			sustain = 0, --love.math.random() * 0.2,
			shotInterval = love.math.random() * 0.1 + 0.05
		})
		
		shotsToFire = 10
		nextShot = love.timer.getTime()
	end
	lastPressedSpace = love.keyboard.isDown(" ")
	
	if love.keyboard.isDown("r") and not lastR then
		nextShot = 0
		shotsToFire = 10
	end
	lastR = love.keyboard.isDown("r")
	
	if love.keyboard.isDown("s") and not lastS then
		saveSoundProperties(currentSound)
	end
	lastS = love.keyboard.isDown("s")
	
	if nextShot < love.timer.getTime() and shotsToFire > 0 then
		shotsToFire = shotsToFire - 1
		nextShot = love.timer.getTime() + currentSound.properties.shotInterval * (math.random() * 0.1 + 1.0)
		love.audio.play(love.audio.newSource(currentSound.soundData))
	end
end

function love.draw()
	local osz_names = {"sine", "triangle", "square", "whistle"}
	love.graphics.setColor({255, 255, 255, 255})
	local p = currentSound.properties
	if p then
		love.graphics.printf("oszillator 1: " .. osz_names[p.oszA], 5, 5, 400)
		love.graphics.printf("oszillator 2: " .. osz_names[p.oszB], 5, 25, 400)
		love.graphics.printf("oszillator mix: " .. tostring(p.oszMix), 5, 45, 400)
		love.graphics.printf("f_start: " .. tostring(p.fStart), 5, 65, 400)
		love.graphics.printf("f_cutoff: " .. tostring(p.fCutoff), 5, 85, 400)
		love.graphics.printf("f_speed: " .. tostring(p.fSpeed), 5, 105, 400)
		love.graphics.printf("decay: " .. tostring(p.decay), 5, 125, 400)
		love.graphics.printf("sustain: " .. tostring(p.sustain), 5, 145, 400)
		love.graphics.printf("shotInterval: " .. tostring(p.shotInterval), 5, 165, 400)
	end
	
	love.graphics.setColor({255, 0, 0, 255})
	love.graphics.printf("Press <space> to generate and play a new sound and <r> to replay a sound.", 5, 300, 700)
	love.graphics.printf("Press <s> to write a sounds properties (a table) to " .. love.filesystem.getSaveDirectory() .. "/" .. getSaveFile(), 5, 320, 700)
	love.graphics.printf(messageStr, 5, 400, 700)
end