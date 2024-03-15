local Terrain = workspace.Terrain
local Lighting = game:GetService("Lighting")
local AssetService = game:GetService("AssetService")

local skyboxResolution: number = 44
local skybox: Model? = nil

local function lerp(a: number, b: number, alpha: number)
	return a + (b - a) * alpha
end

local function createSkybox()
	local skyboxFaceData = {["SkyboxBk"] = {["Position"] = Vector3.new(0, -0, 0.5), ["Orientation"] = Vector3.new(0, 0, 180)}, ["SkyboxFt"] = {["Position"] = Vector3.new(0, -0, -0.5), ["Orientation"] = Vector3.new(0, 180, 180)}, ["SkyboxLf"] = {["Position"] = Vector3.new(-0.5, -0, 0), ["Orientation"] = Vector3.new(0, -90, 180)}, ["SkyboxRt"] = {["Position"] = Vector3.new(0.5, -0, 0), ["Orientation"] = Vector3.new(0, 90, 180)}, ["SkyboxDn"] = {["Position"] = Vector3.new(0, -0.5, 0), ["Orientation"] = Vector3.new(90, 90, 0)}, ["SkyboxUp"] = {["Position"] = Vector3.new(0, 0.5, 0), ["Orientation"] = Vector3.new(-90, 90, 0)}}
	if skybox ~= nil then return end
		
	skybox = Instance.new("Model")
	skybox.Name = "GetWorldColorSkybox"
		
	for i,v in pairs(skyboxFaceData) do
		local face = Instance.new("Part")
		face.Name = i
		face.Size = Vector3.new(1, 1, 0.001144)
		face.CanTouch = false
		face.CanCollide = false
		face.Transparency = 1
		face.CastShadow = false
		face.EnableFluidForces = false
		face.Anchored = true
		face.Locked = true
		
		face.Position = v.Position
		face.Orientation = v.Orientation
		
		local image = Instance.new("Decal")
		image.Name = "image"
		image.Transparency = 1
		image.Parent = face
		
		face.Parent = skybox
	end
		
	skybox.Parent = game.Workspace.Terrain
end

local function updateSkyboxImages()
	-- Create skybox if not avaliable

	createSkybox()
	-- Get skybox and apply images to "fake" skybox used for raycasting

	local currentSkybox = game.Lighting:FindFirstChildWhichIsA("Sky")
	if currentSkybox == nil then
		-- Create default skybox

		currentSkybox = script:FindFirstChildWhichIsA("Sky") or Instance.new("Sky", script)
	end

	--

	for i,v in pairs(skybox:GetChildren()) do
		-- Create EditableImages for each skybox face and insert into skybox

		local image = AssetService:CreateEditableImageAsync(currentSkybox[v.Name])
		image:Resize(Vector2.new(skyboxResolution, skyboxResolution))

		image.Parent = v.image
	end
end
updateSkyboxImages()

local function raycastUntilColor(origin, direction, length, ignoreList)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = ignoreList
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.IgnoreWater = false

	local raycastResult = workspace:Raycast(origin, direction * length, raycastParams)

	if not raycastResult or not raycastResult.Instance then
		-- No hit, return a guess at sky color

		local clockTime = Lighting.ClockTime
		local distFromNoon = math.abs(12 - clockTime) / 12
		local noise = math.noise(origin.X * 70, origin.Y * 70, origin.Z * 70) / 10
		local lightness = lerp(0, 0.8, distFromNoon + noise)
		-- Raycast "fake" skybox and get color at point

		local calculatedColorAtPoint, alpha = Color3.fromRGB(0, 0, 0), 1

		local raycastParamsSkybox = RaycastParams.new()
		raycastParamsSkybox.FilterDescendantsInstances = skybox:GetChildren()
		raycastParamsSkybox.FilterType = Enum.RaycastFilterType.Include

		local raycastResultSkybox = workspace:Raycast(Vector3.new(0, 0, 0), direction * 3.1144, raycastParamsSkybox)

		if raycastResultSkybox then
			local skyboxFace = raycastResultSkybox.Instance

			local calculatedPositionLocal = skyboxFace.CFrame:ToObjectSpace(CFrame.new(raycastResultSkybox.Position)).Position
			calculatedPositionLocal = (Vector2.new(calculatedPositionLocal.X, calculatedPositionLocal.Y) + Vector2.new(0.5, 0.5)) * skyboxResolution
			local pixels = skyboxFace.image.EditableImage:ReadPixels(calculatedPositionLocal, Vector2.new(1, 1))

			calculatedColorAtPoint, alpha = Color3.new(pixels[1], pixels[2], pixels[3]), pixels[4]
		end
		
		local h, s, v = calculatedColorAtPoint:ToHSV()
		v = math.clamp(v - lightness, 0, 1)
		calculatedColorAtPoint = Color3.fromHSV(h, s, v)

		return { calculatedColorAtPoint.R, calculatedColorAtPoint.G, calculatedColorAtPoint.B, alpha }
	end

	-- We should techincally be casting through semi-transparent objects and blending the result,
	-- but that's super costly and we need to be fast so we just use the first object we find

	local hit = raycastResult.Instance
	local fogBlend = if raycastResult.Distance >= Lighting.FogStart
		then (raycastResult.Distance - Lighting.FogStart) / (Lighting.FogEnd - Lighting.FogStart) * 0.9
		else 0

	if hit == Terrain then
		if raycastResult.Material == Enum.Material.Water then
			local color = Terrain.WaterColor:Lerp(Lighting.FogColor, fogBlend)
			return { color.R, color.G, color.B, 1 - Terrain.WaterTransparency }
		else
			local color = Terrain:GetMaterialColor(raycastResult.Material):Lerp(Lighting.FogColor, fogBlend)
			return { color.R, color.G, color.B, 1 }
		end
	end

	if hit.Transparency >= 0.95 then
		-- Pass through it
		table.insert(ignoreList, hit)
		return raycastUntilColor(raycastResult.Position, direction, length - raycastResult.Distance, ignoreList)
	else
		-- Note that this can be wildly wrong for textured or decaled items
		-- but again- speed is more important here. We aren't writing a raycast renderer,
		-- we're just approximating colors.
		local color = hit.Color:Lerp(Lighting.FogColor, fogBlend)
		return { color.R, color.G, color.B, 1 - hit.Transparency }
	end
end

return function(queryPoint: Vector2): { number }
	local ray = workspace.CurrentCamera:ViewportPointToRay(queryPoint.X, queryPoint.Y, 0)
	return raycastUntilColor(ray.Origin, ray.Direction, 500, {})
end
