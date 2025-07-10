--!strict
-- Main Script


---------- Tool ----------

local Tool = script.Parent


---------- Imports ----------

local MovementBind = require(script.Parent:WaitForChild("MovementBind"))


---------- Keybinds ----------

local function onToolEquipped()
	MovementBind.bindAction(MovementBind.moveActions.Crouch, {Enum.KeyCode.C})
	MovementBind.bindAction(MovementBind.moveActions.Dive, {Enum.KeyCode.LeftShift})
	MovementBind.bindAction(MovementBind.moveActions.Jump, {Enum.PlayerActions.CharacterJump})

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
