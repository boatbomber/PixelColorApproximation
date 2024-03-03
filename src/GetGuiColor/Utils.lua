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

return Utils
