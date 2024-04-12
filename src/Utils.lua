local AssetService = game:GetService("AssetService")

local Utils = {}

function Utils.worldToLocal(vector, position, size, rotation)
	local translated = vector - position
	local cosAngle = math.cos(-rotation)
	local sinAngle = math.sin(-rotation)
	local rotatedX = cosAngle * translated.X - sinAngle * translated.Y
	local rotatedY = sinAngle * translated.X + cosAngle * translated.Y
	local scaledX = rotatedX / size.X
	local scaledY = rotatedY / size.Y
	return Vector2.new(scaledX, scaledY)
end

Utils.IMAGE_DOWNSCALE_FACTOR = 0.75 -- Sample images at lower resolution to improve performance
Utils.IMAGE_CACHE = {}
function Utils.getEditableImage(source: string | Instance): (EditableImage?, boolean?)
	local assetUri: string

	local sourceType = typeof(source)
	if sourceType == "string" then
		assetUri = source :: string
	elseif sourceType == "Instance" then
		local sourceInstance = source :: Instance
		if sourceInstance:FindFirstChildWhichIsA("EditableImage") then
			return sourceInstance:FindFirstChildWhichIsA("EditableImage"), false
		end

		if sourceInstance:IsA("ImageLabel") or sourceInstance:IsA("ImageButton") then
			assetUri = sourceInstance.Image
		elseif sourceInstance:IsA("Texture") or sourceInstance:IsA("Decal") then
			assetUri = sourceInstance.Texture
		elseif sourceInstance:IsA("SurfaceAppearance") then
			assetUri = sourceInstance.ColorMap
		end
	else
		return
	end

	if assetUri == nil or assetUri == "" then
		return
	end

	local assetId: string? = string.match(assetUri, "%d+$")
	if assetId == nil then
		return
	end

	if Utils.IMAGE_CACHE[assetId] then
		return Utils.IMAGE_CACHE[assetId], true
	end

	local success, editableImage = pcall(function()
		local image = AssetService:CreateEditableImageAsync(assetUri)
		image:Resize(image.Size * Utils.IMAGE_DOWNSCALE_FACTOR)
		Utils.IMAGE_CACHE[assetId] = image
		return image
	end)

	if success then
		return editableImage, true
	end

	return
end

function Utils.getSkyboxFaceAndCoords(lookDirection: Vector3): (string, number, number)
	local absX = math.abs(lookDirection.X)
	local absY = math.abs(lookDirection.Y)
	local absZ = math.abs(lookDirection.Z)
	local face, u, v

	-- Determine the primary direction of the lookDirection vector and calculate 2D coordinates
	if absX > absY and absX > absZ then
		if lookDirection.X < 0 then
			face = "SkyboxRt"
			u = 1 - (lookDirection.Z / absX + 1) / 2
			v = (lookDirection.Y / absX + 1) / 2
		else
			face = "SkyboxLf"
			u = (lookDirection.Z / absX + 1) / 2
			v = (lookDirection.Y / absX + 1) / 2
		end
	elseif absY > absZ then
		if lookDirection.Y > 0 then
			face = "SkyboxUp"
			u = 1 - (lookDirection.Z / absY + 1) / 2
			v = (lookDirection.X / absY + 1) / 2
		else
			face = "SkyboxDn"
			u = 1 - (lookDirection.Z / absY + 1) / 2
			v = 1 - (lookDirection.X / absY + 1) / 2
		end
	else
		if lookDirection.Z < 0 then
			face = "SkyboxFt"
			u = (lookDirection.X / absZ + 1) / 2
			v = (lookDirection.Y / absZ + 1) / 2
		else
			face = "SkyboxBk"
			u = 1 - (lookDirection.X / absZ + 1) / 2
			v = (lookDirection.Y / absZ + 1) / 2
		end
	end

	-- Invert v to map the coordinate system correctly
	v = 1 - v

	return face, u, v
end

return Utils
