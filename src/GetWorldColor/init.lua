--!strict
--!native
--!optimize 2

local Terrain = workspace.Terrain
local CurrentWorkspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local AssetService = game:GetService("AssetService")

local skyboxResolution: number, skyboxBucketCellSize: number = 40, 1
local skybox: Model | nil, skyboxBuckets, skyboxFaces = nil, {}, {}

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = false

local raycastParamsSkybox = RaycastParams.new()
raycastParamsSkybox.FilterType = Enum.RaycastFilterType.Include

local V3 = Vector3.new
local V2 = Vector2.new
local clamp = math.clamp
local floor = math.floor
local color3new = Color3.new
local color3fromHEX = Color3.fromHex
local color3fromHSV = Color3.fromHSV

local function lerp(a: number, b: number, alpha: number)
	return a + (b - a) * alpha
end

local function hash2D(position: Vector2, cellSize: number): string
	local x = floor(position.X / cellSize)
	local y = floor(position.Y / cellSize)

	--

	return x .. "_" .. y
end

local function createSkybox()
	if skybox ~= nil then
		skybox:Destroy()
		skybox = nil
	end
	
	for i,bucket in pairs(skyboxBuckets) do
		table.clear(bucket)
	end
	
	local skyboxFaceData = {["SkyboxBk"] = {["Position"] = V3(0, -0, 0.5), ["Orientation"] = V3(0, 0, 180)}, ["SkyboxFt"] = {["Position"] = V3(0, -0, -0.5), ["Orientation"] = V3(0, 180, 180)}, ["SkyboxLf"] = {["Position"] = V3(-0.5, -0, 0), ["Orientation"] = V3(0, -90, 180)}, ["SkyboxRt"] = {["Position"] = V3(0.5, -0, 0), ["Orientation"] = V3(0, 90, 180)}, ["SkyboxDn"] = {["Position"] = V3(0, -0.5, 0), ["Orientation"] = V3(90, 90, 0)}, ["SkyboxUp"] = {["Position"] = V3(0, 0.5, 0), ["Orientation"] = V3(-90, 90, 0)}}
		
	skybox = Instance.new("Model")
	if skybox == nil then return end -- typechecking
	skybox.Name = "GetWorldColorSkybox"
		
	for i,v in pairs(skyboxFaceData) do
		local face = Instance.new("Part")
		face.Name = i
		face.Size = V3(1, 1, 0)
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
		
	skybox.Parent = Terrain
	
	skyboxFaces = skybox:GetChildren()
	raycastParamsSkybox.FilterDescendantsInstances = skyboxFaces
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

	for i,v in pairs(skyboxFaces) do
		-- Create EditableImages for each skybox face

		local image = AssetService:CreateEditableImageAsync(currentSkybox[v.Name])
		image:Resize(V2(skyboxResolution, skyboxResolution))
		
		local bucket = {}
		skyboxBuckets[v.Name] = bucket

		for x=1, skyboxResolution - 1 do
			for y=1, skyboxResolution - 1 do
				local position = V2(x, y)
				local colorAtPixel = image:ReadPixels(position, V2(1, 1))
				colorAtPixel = color3new(colorAtPixel[1], colorAtPixel[2], colorAtPixel[3])
				
				local calculatedWorldPosition: Vector2 = position - (V2(skyboxResolution, skyboxResolution) / 2)
				
				bucket[hash2D(calculatedWorldPosition, skyboxBucketCellSize)] = colorAtPixel:ToHex()
			end
		end
		
		image:Destroy()
	end
end
updateSkyboxImages()

local cachedClockTime, lastUpdatedClockTime = Lighting.ClockTime, tick()
local function raycastUntilColor(origin: Vector3, direction: Vector3, length: number, ignoreList: {})
	raycastParams.FilterDescendantsInstances = ignoreList

	local raycastResult = CurrentWorkspace:Raycast(origin, direction * length, raycastParams)

	if not raycastResult or not raycastResult.Instance then
		-- No hit, return a guess at sky color
		
		-- Clock time is semi-expensive to get, so fetch every so often
		local currentClockTime = tick()
		if (currentClockTime - lastUpdatedClockTime) > 2 then
			cachedClockTime = Lighting.ClockTime
			lastUpdatedClockTime = currentClockTime
		end
		
		-- Calculate lightness used for tinting pixel lightness depending on time of day
		local distFromNoon = math.abs(12 - cachedClockTime) / 12
		local lightness = lerp(0, 0.8, distFromNoon)
		
		-- Raycast "fake" skybox and get color at point
		local calculatedColorAtPoint, alpha = color3new(0, 0, 0), 1

		local raycastResultSkybox = CurrentWorkspace:Raycast(V3(0, 0, 0), direction * 3.1144, raycastParamsSkybox)

		if raycastResultSkybox then
			local skyboxFace = raycastResultSkybox.Instance
			local calculatedPositionLocal = skyboxFace.CFrame:ToObjectSpace(CFrame.new(raycastResultSkybox.Position)).Position
			
			calculatedColorAtPoint = color3fromHEX(skyboxBuckets[skyboxFace.Name][hash2D(V2(calculatedPositionLocal.X, calculatedPositionLocal.Y) * skyboxResolution, skyboxBucketCellSize)] or "434343")
		end
		
		local h, s, v = calculatedColorAtPoint:ToHSV()
		v = clamp(v - lightness, 0, 1)
		calculatedColorAtPoint = color3fromHSV(h, s, v)

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
	local ray = CurrentWorkspace.CurrentCamera:ScreenPointToRay(queryPoint.X, queryPoint.Y, 0)
	return raycastUntilColor(ray.Origin, ray.Direction, 500, {})
end
