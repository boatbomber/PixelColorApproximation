local PlayerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui", math.huge)

local GetGuiColor = require(script.GetGuiColor)
local GetWorldColor = require(script.GetWorldColor)

local PixelColorApproximation = {}

function PixelColorApproximation:GetColor(queryPoint: Vector2, topLayer: GuiObject?): { number }
	-- First, figure out the UI color at this point
	local guisAtPosition = PlayerGui:GetGuiObjectsAtPosition(queryPoint.X, queryPoint.Y)

	local uiIsOpaque = false
	local layerColors, layerIndex = table.create(math.ceil(#guisAtPosition / 2)), 0
	local topLayerIndex = if topLayer then table.find(guisAtPosition, topLayer) else nil

	for i = (topLayerIndex or 0) + 1, #guisAtPosition do
		local gui = guisAtPosition[i]

		-- Get object color
		local guiColor = GetGuiColor(queryPoint, gui)
		local guiAlpha = guiColor[4]
		if guiAlpha == 0 then
			-- Skip invisible objects
			continue
		end

		layerIndex += 1
		layerColors[layerIndex] = guiColor

		-- We'll stop at the first opaque item since everything beneath will be covered
		if guiAlpha == 1 then
			uiIsOpaque = true
			break
		end
	end

	-- If the UI is not opaque, we'll roughly get world color underneath
	if not uiIsOpaque then
		local worldColor = GetWorldColor(queryPoint)
		layerIndex += 1
		layerColors[layerIndex] = worldColor
	end

	-- Finally, we blend all these colors using their alphas and return that
	local color = { 0, 0, 0, 1 }
	for i = layerIndex, 1, -1 do
		local layerColor = layerColors[i]
		local layerAlpha = layerColor[4]
		color[1] = (1 - layerAlpha) * color[1] + layerAlpha * layerColor[1]
		color[2] = (1 - layerAlpha) * color[2] + layerAlpha * layerColor[2]
		color[3] = (1 - layerAlpha) * color[3] + layerAlpha * layerColor[3]
	end

	return color
end

return PixelColorApproximation
