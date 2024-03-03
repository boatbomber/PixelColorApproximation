return function(queryPoint: Vector2, gui: GuiObject): { number }
	local color =
		{ gui.BackgroundColor3.R, gui.BackgroundColor3.G, gui.BackgroundColor3.B, 1 - gui.BackgroundTransparency }
	local gradient = gui:FindFirstChildWhichIsA("UIGradient")
	if gradient then
		-- TODO: Figure out where in the gradient we are
		local colorKeypoint = gradient.Color.Keypoints[1]
		local alphaKeypoint = gradient.Transparency.Keypoints[1]

		color[1] *= colorKeypoint.Value.R
		color[2] *= colorKeypoint.Value.G
		color[3] *= colorKeypoint.Value.B
		color[4] *= 1 - alphaKeypoint.Value
	end

	return color
end
