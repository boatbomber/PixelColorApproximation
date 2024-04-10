local Terrain = workspace.Terrain
local Lighting = game:GetService("Lighting")

local nightColor, dayColor = Color3.fromRGB(2, 7, 30), Color3.fromRGB(89, 178, 210)

local function raycastUntilColor(origin, direction, length, ignoreList)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = ignoreList
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.IgnoreWater = false

	local raycastResult = workspace:Raycast(origin, direction * length, raycastParams)

	if not raycastResult or not raycastResult.Instance then
		-- No hit, return a guess at sky color
		-- TODO: Consider sampling skybox images for real?
		local clockTime = Lighting.ClockTime
		local distFromNoon = math.abs(12 - clockTime) / 12
		local noise = math.noise(origin.X * 70, origin.Y * 70, origin.Z * 70) / 10
		local color = dayColor:Lerp(nightColor, distFromNoon + noise)

		return { color.R, color.G, color.B, 1 }
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

	if (1 - hit.Transparency) * (1 - hit.LocalTransparencyModifier) <= 0.05 then
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
