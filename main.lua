require "slider"

function randrange(min, max)
	return min + math.random() * (max - min)
end

function randomProperties()
	local props = {}
	for i, v in pairs(parameters) do
		if v.integer then
			props[v.key] = love.math.random(v.min, v.max)
		else
			props[v.key] = randrange(v.min, v.max)
		end
	end
	
	if props.fCutoff > props.fStart then props.fCutoff = props.fStart / 2 end
	props.sustain = 0
	
	return props
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
	lastL = false
	messageStr = ""
	
	parameters = {
		{name = "oscillator 1", key = "oszA", min = 1, max = 4, integer = true},
		{name = "oscillator 2", key = "oszB", min = 1, max = 4, integer = true},
		{name = "oscillator mix", key = "oszMix", min = 0.0, max = 1.0, integer = false},
		{name = "frequency start", key = "fStart", min = 200.0, max = 2000.0, integer = false},
		{name = "frequency cutoff", key = "fCutoff", min = 30.0, max = 1000.0, integer = false},
		{name = "frequency sweep speed", key = "fSpeed", min = 0.00001, max = 0.0001, integer = false},
		{name = "volume decay length", key = "decay", min = 0.0, max = 1.0, integer = false},
		{name = "volume sustain length", key = "sustain", min = 0.0, max = 1.0, integer = false},
		{name = "shot interval", key = "shotInterval", min = 0.0, max = 0.4, integer = false},
		{name = "clamp threshold", key = "clamp", min = 0.0, max = 1.0, integer = false}
	}
	
	currentSound = nil
	properties = randomProperties()
	
	local spacing = 35
	local height = 25
	local w = 400
	local x = love.window.getWidth() / 2 - w / 2.0
	for i, param in ipairs(parameters) do
		-- a little extra for max, so you can reach it with the mouse more practically
		addSlider(param.name, properties, param.key, param.min, param.max + (param.integer and 0.04 or 0.0), param.integer, x, spacing * i, w, height)
	end
	
	shotsToFire = 0
	nextShot = 0
end

function getSaveFile()
	return "soundProps.lua"
end

function dictToStr(dict)
	str = "{\n"
	for k, v in pairs(dict) do
		str = str .. "\t" .. k .. " = " .. v .. ",\n"
	end
	str = str:sub(1, str:len() - 2) .. "\n}"
	return str
end

function saveSoundProperties(properties)
	file, errorStr = love.filesystem.newFile("soundProps.lua", "w")
	if file then
		file:write("return " .. dictToStr(properties))
		file:close()
		messageStr = "File saved."
	else
		messageStr = errorStr
		return
	end
	
	file, errorStr = love.filesystem.newFile("sound.wav", "w")
	local bytes
	function bytes(v, num)
		local ret = ""
		for i = 1, num do
			ret = ret .. string.char(v % 256)
			v = math.floor(v / 256)
		end
		return ret
	end
	
	local word = function(v) return bytes(v, 2) end
	local dword = function(v) return bytes(v, 4) end
	
	local dataStr = currentSound.soundData:getString()
	
	-- this is even on wikipedia! :)
	fileString = "RIFF" .. dword(24 + 8 + dataStr:len() - 8) .. "WAVE" -- "fmt " length + data header + data - "RIFF" and "WAVE"
	
	-- format chunk
	fileString = fileString .. "fmt " .. dword(16) .. word(1) .. word(1) -- chunk size, format: PCM, channels
	.. dword(44100) .. dword(44100 * 2) .. word(2) .. word(16) -- sample rate, bytes/second, block size, bits per sample
	
	-- data chunk
	fileString = fileString .. "data" .. dword(dataStr:len()) .. dataStr -- chunk size, data
	
	file:write(fileString)
	file:close()
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
	
	local play = function()
		currentSound = generateShootSound(properties)
		shotsToFire = 10
		nextShot = 0
	end
	
	if love.keyboard.isDown(" ") and lastPressedSpace == false then
		setTable(properties, randomProperties()) -- because of the sliders
		play()
	end
	lastPressedSpace = love.keyboard.isDown(" ")
	
	if love.keyboard.isDown("r") and not lastR then
		play()
	end
	lastR = love.keyboard.isDown("r")
	
	if love.keyboard.isDown("s") and not lastS then
		saveSoundProperties(properties)
	end
	lastS = love.keyboard.isDown("s")
	
	if love.keyboard.isDown("l") and not lastL then
		setTable(properties, loadstring(love.filesystem.read("soundProps.lua"))())
	end
	lastL = love.keyboard.isDown("l")
	
	if love.keyboard.isDown("m") and not lastM then
		local n = 0
		for k, v in pairs(parameters) do n = n + 1 end
		n = love.math.random(1, n)
		
		for i, param in pairs(parameters) do
			n = n - 1
			if n == 0 then
				if param.integer then
					properties[param.key] = clamp(properties[param.key] + (love.math.random() > 0.5 and 1 or -1), param.min, param.max)
				else
					properties[param.key] = properties[param.key] + (param.max - param.min) * 0.02 * (love.math.random() > 0.5 and 1 or -1)
					properties[param.key] = clamp(properties[param.key] , param.min, param.max)
				end
				break
			end
		end
	end
	lastM = love.keyboard.isDown("m")
	
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
	
	love.graphics.printf("Press <space> to generate and play a new sound and <r> to play a sound. \nPress <m> to mutate the sound. \nPress <s> to write a sounds properties (a table) to " .. love.filesystem.getSaveDirectory() .. "/" .. getSaveFile() .. "\nand <l> to load it.\n" .. messageStr, 5, 400, love.window.getWidth())
end