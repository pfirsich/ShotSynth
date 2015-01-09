shotSoundParameters = {
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

function randomShotSoundProperties()
	local props = {}
	for i, v in pairs(shotSoundParameters) do
		if v.integer then
			props[v.key] = love.math.random(v.min, v.max)
		else
			props[v.key] = randrangef(v.min, v.max)
		end
	end
	
	if props.fCutoff > props.fStart then props.fCutoff = props.fStart / 2 end
	props.sustain = 0
	
	return props
end

function getRMS(soundData)
	integral = 0
	for i = 0, soundData:getSampleCount() - 1 do
		local s = soundData:getSample(i)
		integral = integral + s*s
	end
	return math.sqrt(integral / (soundData:getSampleCount() / soundData:getSampleRate()))
end

function generateShotSound(properties)
	local sampleRate = 44100
	local samples = 1.0 * 44100
	local osz_table = {osz_sin, osz_square, osz_tri, osz_whistle}
	
	local soundData = love.sound.newSoundData(samples, sampleRate, 16, 1)
	
	local f = properties.fStart
	local osz = osz_mix(osz_table[properties.oszA], osz_table[properties.oszB], properties.oszMix)
	
	for i = 0, samples - 1 do
		f = f - properties.fSpeed * f
		if f < properties.fCutoff then 
			f = properties.fCutoff - 0.001
		end
		
		local sample = f < properties.fCutoff and 0 or 
								osz(f, i / sampleRate) * SDenvelope(properties.sustain, properties.decay, i/samples)
		sample = clamp(sample, -properties.clamp, properties.clamp)
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

-- utility
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

function SDenvelope(sustain, decay, t)
	if t < sustain then
		return 1.0
	elseif t < decay + sustain then 
		return 1.0 - 1.0 / decay * (t - sustain)
	else
		return 0.0
	end
end

function clamp(v, min, max)
	return math.max(math.min(v, max), min)
end