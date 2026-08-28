local Keybinds = {}

local UserInputService = game:GetService("UserInputService")

local events = game.ReplicatedStorage:WaitForChild("Events")
local updateKeybindsEvent = events:WaitForChild("UpdateKeybinds")

local player = game.Players.LocalPlayer
local keybinds = game.ReplicatedStorage:WaitForChild("Keybinds")

export type ActionListener = {
	action: string,
	inputState: "Begin" | "End" | "Both",
	bypassGpe: boolean,
	garbageCollect: boolean,
	callback: (isButtonPressed: boolean) -> ()
}

local listeners: {ActionListener} = {}
local actionMap = {}

local function processInput(input: InputObject, gpe: boolean)
	local key = input.KeyCode.Name:lower()
	
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		key = "m1"
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		key = "m2"
	elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
		key = "m3"
	end
	
	for i, listener in pairs(listeners) do
		if not listener.bypassGpe and gpe then continue end
		if (actionMap[listener.action] or ""):lower() ~= key then continue end
		if input.UserInputState.Name ~= listener.inputState and listener.inputState ~= "Both" then continue end
		
		if listener.callback then
			listener.callback(input.UserInputState.Name == "Begin")
		else
			table.remove(listeners, i) -- Should never happen but failsafe anyway
		end
	end
end

local function updateKeybinds(newBinds)
	actionMap = newBinds
end

Keybinds.ActionToKey = function(action)
	return actionMap[action]
end

Keybinds.GarbageCollect = function()
	for i = #listeners, 1, -1 do
		if not listeners[i].garbageCollect then continue end
		table.remove(listeners, i)
	end
end

Keybinds.AddListener = function(listener: ActionListener)
	if not listener.action then return end
	if not listener.callback then return end
	
	if listener.garbageCollect == nil then
		listener.garbageCollect = true
	end
	if listener.bypassGpe == nil then
		listener.bypassGpe = false
	end
	
	listener.inputState = listener.inputState or "Begin"
	
	table.insert(listeners, listener)
end

Keybinds.OnActionBegan = function(action: string, callback)
	Keybinds.AddListener({action = action, callback = callback})
end

Keybinds.OnAction = function(action: string, callback)
	Keybinds.AddListener({action = action, callback = callback, inputState = "Both"})
end

Keybinds.OnActionStopped = function(action: string, callback)
	Keybinds.AddListener({action = action, callback = callback, inputState = "End"})
end

UserInputService.InputBegan:Connect(processInput)
UserInputService.InputEnded:Connect(processInput)

local _tempBinds = {}
for _, v in pairs(keybinds:GetChildren()) do
	_tempBinds[v.Name] = v.Value:lower()
end
updateKeybinds(_tempBinds)
updateKeybindsEvent.OnClientEvent:Connect(updateKeybinds)

return Keybinds
