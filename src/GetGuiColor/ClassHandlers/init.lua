local handlerFunctions = {}
for _, module in script:GetChildren() do
	if not module:IsA("ModuleScript") then
		continue
	end
	handlerFunctions[module.Name] = require(module)
end

local ClassHandlers = setmetatable({
	default = handlerFunctions.default,

	ImageLabel = handlerFunctions.image,
	ImageButton = handlerFunctions.image,

	TextLabel = handlerFunctions.text,
	TextButton = handlerFunctions.text,
	TextBox = handlerFunctions.text,

	-- TODO: ViewportFrames
}, {
	__index = function(t, _class)
		-- No handler exists for this class, fallback to default
		return rawget(t, "default")
	end,
})

return ClassHandlers
