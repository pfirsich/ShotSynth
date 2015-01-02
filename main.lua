require "slider"

function randrange(min, max)
	return min + math.random() * (max - min)
end

function randomProperties()
	local fStart = randrange(200.0, 1000.0)
	return {
		oszA = love.math.random(1, 4),
		oszB = love.math.random(1, 4), 
		oszMix = love.math.random(),
		fStart = fStart,
		fCutoff = math.max(fStart - love.math.random(100, 500), 30),
		fSpeed = randrange(0.00005, 0.00007),
		decay = randrange(0.1, 0.3),
		sustain = 0, --love.math.random() * 0.2,
		shotInterval = randrange(0.05, 0.15),
		clamp = randrange(0.01, 1.0)
	}
end

function setTable(a, b)
	for k, v in pairs(b) do
		a[k] = b[k]
	end
end

function love.load()	
	lastPressedSpace = false
	lastR = false
	lastS = false
	currentSound = nil
	properties = randomProperties()
	messageStr = ""
	
	local spacing = 35
	local height = 25
	local w = 400
	local x = love.window.getWidth() / 2 - w / 2.0
	addSlider("oscillator 1", properties, "oszA", 1, 4.04, true, x, spacing * 1, w, height)
	addSlider("oscillator 2", properties, "oszB", 1, 4.04, true, x, spacing * 2, w, height)
	addSlider("oscillator mix", properties, "oszMix", 0.0, 1.0, false, x, spacing * 3, w, height)
	addSlider("frequency start", properties, "fStart", 200.0, 2000.0, false, x, spacing * 4, w, height)
	addSlider("frequency cutoff", properties, "fCutoff", 30.0, 1000.0, false, x, spacing * 5, w, height)
	addSlider("frequency sweep speed", properties, "fSpeed", 0.00001, 0.0001, false, x, spacing * 6, w, height)
	addSlider("volume decay length", properties, "decay", 0.0, 1.0, false, x, spacing * 7, w, height)
	addSlider("volume sustain length", properties, "sustain", 0.0, 1.0, false, x, spacing * 8, w, height)
	addSlider("shot interval", properties, "shotInterval", 0.0, 0.4, false, x, spacing * 9, w, height)
	addSlider("clamp threshold", properties, "clamp", 0.0, 1.0, false, x, spacing * 10, w, height)
	
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

function saveSoundProperties(properties)
	file, errorStr = love.filesystem.newFile("soundProps.lua", "w")
	if file then
		file:write("properties" .. dictToStr(properties))
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

function clamp(v, min, max)
	return math.max(math.min(v, max), min)
end

function clampRange(v, range)
	return clamp(v, -range, range)
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
		sample = clampRange(sample, properties.clamp)
		soundData:setSample(i, sample)
	end
	
	-- normalize, so all sounds have similar loudness
	local rms = getRMS(soundData)
	local targetrms = 15.0
	for i = 0, samples - 1 do
		soundData:setSample(i, soundData:getSample(i) * targetrms / rms)
	end
	
	return {properties = properties, soundData = soundData}
end

function love.update()
	updateSliders()
	
	if love.keyboard.isDown(" ") and lastPressedSpace == false then
		setTable(properties, randomProperties()) -- because of the sliders
		
		currentSound = generateShootSound(properties)
		shotsToFire = 10
		nextShot = 0
	end
	lastPressedSpace = love.keyboard.isDown(" ")
	
	if love.keyboard.isDown("r") and not lastR then
		currentSound = generateShootSound(properties)
		shotsToFire = 10
		nextShot = 0
	end
	lastR = love.keyboard.isDown("r")
	
	if love.keyboard.isDown("s") and not lastS then
		saveSoundProperties(properties)
	end
	lastS = love.keyboard.isDown("s")
	
	if nextShot < love.timer.getTime() and shotsToFire > 0 then
		shotsToFire = shotsToFire - 1
		nextShot = love.timer.getTime() + currentSound.properties.shotInterval * (math.random() * 0.1 + 1.0)
		love.audio.play(love.audio.newSource(currentSound.soundData))
	end
end

function love.draw()
	drawSliders()
	
	local osz_names = {"sine", "triangle", "square", "whistle"}
	love.graphics.setColor({255, 255, 255, 255})
	love.graphics.printf("Oscillators: 1 = sine, 2 = triangle, 3 = square, 4 = whistle", 0, 5, love.window.getWidth(), "center")
	
	love.graphics.printf("Press <space> to generate and play a new sound and <r> to play a sound. \nPress <s> to write a sounds properties (a table) to " .. love.filesystem.getSaveDirectory() .. "/" .. getSaveFile() .. "\n\n" .. messageStr, 5, 400, love.window.getWidth())
end