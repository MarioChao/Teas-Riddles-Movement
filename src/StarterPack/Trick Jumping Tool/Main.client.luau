--!strict
-- Main Script


---------- Tool ----------

local Tool = script.Parent


---------- Imports ----------

local MovementBind = require(script.Parent:WaitForChild("MovementBind"))


---------- Keybinds ----------

local function onToolEquipped()
	MovementBind.bindAction(MovementBind.moveNames.Crouch, {Enum.KeyCode.C})
	MovementBind.bindAction(MovementBind.moveNames.Dive, {Enum.KeyCode.LeftShift})

	MovementBind.connect()

	MovementBind.showUI()
end

local function onToolUnequipped()
	MovementBind.unbindAndDisconnect()

	MovementBind.hideUI()
end


---------- Local functions ----------

Tool.Equipped:Connect(onToolEquipped)
Tool.Unequipped:Connect(onToolUnequipped)
