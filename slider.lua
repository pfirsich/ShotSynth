sliders = {}

function addSlider(name, tbl, key, min, max, integer, x, y, width, height)
	table.insert(sliders, {name = name, table = tbl, key = key, min = min, max = max, integer = integer, x = x, y = y, width = width, height = height})
end

function updateSliders()
	local mx, my = love.mouse.getPosition()
	if love.mouse.isDown("l") then
		for i = 1, #sliders do
			local slider = sliders[i]
			if mx > slider.x and mx < slider.x + slider.width - 1 and my > slider.y and my < slider.y + slider.height - 1 then
				slider.table[slider.key] = slider.min + (slider.max - slider.min) * (mx - slider.x) / slider.width
				if slider.integer then slider.table[slider.key] = math.floor(slider.table[slider.key]) end
			end
		end
	end
end

function drawSliders()
	local bgColor = {255, 255, 255, 255}
	local sliderColor = {255, 100, 100, 255}
	local textColor = {0, 0, 0, 255}
	local fontSize = 14
	local border = 2
	
	for i = 1, #sliders do
		slider = sliders[i]
		love.graphics.setColor(bgColor)
		love.graphics.rectangle("fill", slider.x, slider.y, slider.width, slider.height)
		
		love.graphics.setColor(sliderColor)
		local w = (slider.width - border * 2) * (slider.table[slider.key] - slider.min) / (slider.max - slider.min)
		love.graphics.rectangle("fill", slider.x + border, slider.y + border, w, slider.height - border * 2)
		
		love.graphics.setColor(textColor)
		local textY = slider.y + slider.height / 2 - fontSize / 2
		love.graphics.printf(slider.name .. ": " .. tostring(slider.table[slider.key]), slider.x, textY, slider.width, "center")
	end
end