local AssetService = game:GetService("AssetService")

local Utils = require(script.Parent.Parent.Utils)
local defaultHandler = require(script.Parent.default)

local DOWNSCALE_FACTOR = 0.5 -- Sample images at half resolution to improve performance

local imageCache = {}
return function(queryPoint: Vector2, gui: ImageLabel | ImageButton): { number }
	local color = defaultHandler(queryPoint, gui)
	if gui.ImageTransparency == 1 or gui.Image == "" or gui.IsLoaded == false then
		return color
	end

	local success, image = pcall(function()
		if gui:FindFirstChildWhichIsA("EditableImage") then
			return gui:FindFirstChildWhichIsA("EditableImage")
		end

		if imageCache[gui.Image] then
			return imageCache[gui.Image]
		end
		local editableImage = AssetService:CreateEditableImageAsync(gui.Image)
		editableImage:Resize(editableImage.Size * DOWNSCALE_FACTOR)
		imageCache[gui.Image] = editableImage
		return editableImage
	end)
	if not success then
		return color
	end

	local queryInObjectSpace =
		Utils.worldToLocal(queryPoint, gui.AbsolutePosition, gui.AbsoluteSize, math.rad(gui.Rotation))
	local imageWidth, imageHeight = image.Size.X, image.Size.Y
	local objectWidth, objectHeight = gui.AbsoluteSize.X, gui.AbsoluteSize.Y
	local queryInImageSpace = queryInObjectSpace

	-- Find where on the image we'll be sampling
	if gui.ScaleType == Enum.ScaleType.Fit then
		if objectWidth <= objectHeight then
			-- Image will display across width, so we need to adjust our objectSpace Y into imageSpace Y
			local imageSizeInObject = Vector2.new(objectWidth, objectWidth / imageWidth * imageHeight)
			local imagePositionInObject = Vector2.new(0, (objectHeight - imageSizeInObject.Y) / 2)
			local minimumObjectSpace = imagePositionInObject.Y / objectHeight
			if queryInObjectSpace.Y < minimumObjectSpace then
				return color
			end
			local maximumObjectSpace = 1 - minimumObjectSpace
			if queryInObjectSpace.Y > maximumObjectSpace then
				return color
			end
			local range = maximumObjectSpace - minimumObjectSpace

			queryInImageSpace = Vector2.new(queryInObjectSpace.X, (queryInObjectSpace.Y - minimumObjectSpace) / range)
		else
			-- Image will display across height, so we need to adjust our objectSpace X into imageSpace X
			local imageSizeInObject = Vector2.new(objectHeight / imageHeight * imageWidth, objectHeight)
			local imagePositionInObject = Vector2.new((objectWidth - imageSizeInObject.X) / 2, 0)
			local minimumObjectSpace = imagePositionInObject.X / objectWidth
			if queryInObjectSpace.X < minimumObjectSpace then
				return color
			end
			local maximumObjectSpace = 1 - minimumObjectSpace
			if queryInObjectSpace.X > maximumObjectSpace then
				return color
			end
			local range = maximumObjectSpace - minimumObjectSpace

			queryInImageSpace = Vector2.new((queryInObjectSpace.X - minimumObjectSpace) / range, queryInObjectSpace.Y)
		end
		--TODO: elseif object.ScaleType == Enum.ScaleType.Crop then
	end

	local rectSize = gui.ImageRectSize * DOWNSCALE_FACTOR / image.Size
	if rectSize.X ~= 0 or rectSize.Y ~= 0 then
		-- Adjust queryInImageSpace based on rect cutout
		local rectPos = gui.ImageRectOffset * DOWNSCALE_FACTOR / image.Size
		queryInImageSpace = Vector2.new(
			math.clamp(queryInImageSpace.X * rectSize.X + rectPos.X, 0, 1),
			math.clamp(queryInImageSpace.Y * rectSize.Y + rectPos.Y, 0, 1)
		)
	end

	-- If the query point is outside the image, return the background color
	if queryInImageSpace.X < 0 or queryInImageSpace.X > 1 or queryInImageSpace.Y < 0 or queryInImageSpace.Y > 1 then
		return color
	end

	-- Get the pixel color at the query point
	local imageColor = image:ReadPixels(
		Vector2.new(
			math.clamp(math.floor(queryInImageSpace.X * imageWidth), 0, imageWidth - 1),
			math.clamp(math.floor(queryInImageSpace.Y * imageHeight), 0, imageHeight - 1)
		),
		Vector2.one
	)
	if not imageColor then
		return color
	end

	-- Blend the gui properties
	local multColor = gui.ImageColor3
	imageColor[1] *= multColor.R
	imageColor[2] *= multColor.G
	imageColor[3] *= multColor.B
	imageColor[4] *= (1 - gui.ImageTransparency)

	-- Blend this pixel over the background
	local imageAlpha = imageColor[4]
	local colorAlpha = color[4]
	color[1] = (1 - imageAlpha) * (color[1] * colorAlpha) + imageAlpha * imageColor[1]
	color[2] = (1 - imageAlpha) * (color[2] * colorAlpha) + imageAlpha * imageColor[2]
	color[3] = (1 - imageAlpha) * (color[3] * colorAlpha) + imageAlpha * imageColor[3]
	color[4] = math.max(imageAlpha, colorAlpha)

	return color
end
