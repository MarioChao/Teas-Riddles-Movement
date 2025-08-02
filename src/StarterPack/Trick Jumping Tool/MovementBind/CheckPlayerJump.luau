--!strict


---------- Services ----------

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")


---------- Module ----------

local module = {}


---------- Variables ----------

local localPlayer = Players.LocalPlayer

local _preventPlayerJumping = false


---------- Jump functions ----------

local function setIsJumping(state: boolean)
	module.isJumping = state
end

local function setUpJumpDetectWithHumanoid()
	RunService:BindToRenderStep("LocalPlayerDetectJump", Enum.RenderPriority.Input.Value + 1, function()
		local character = localPlayer.Character
		local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
		if not humanoid then
			return
		end

		setIsJumping(humanoid.Jump)

		if _preventPlayerJumping then
			humanoid.Jump = false
		end
	end)
end

local function cleanUpJumpDetect()
	RunService:UnbindFromRenderStep("LocalPlayerDetectJump")
end


---------- Connection functions ----------

local function disconnect()
	module.isJumping = false
	cleanUpJumpDetect()
end

local function connect(preventPlayerJumping: boolean)
	disconnect()
	_preventPlayerJumping = (preventPlayerJumping == true)
	setUpJumpDetectWithHumanoid()
end


---------- Module fields ----------

module.isJumping = false

module.connect = connect
module.disconnect = disconnect


---------- Return module ----------

return module
