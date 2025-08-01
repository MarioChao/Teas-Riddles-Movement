--!strict
-- Movement Module


---------- Module ----------

local module = {}


---------- Validate environment ----------

local RunService = game:GetService("RunService")
if not RunService:IsClient() then
	warn("MovementBind should be required in a client environment!")
end


---------- Services ----------

local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")


---------- Imports ----------

local CheckPlayerJump = require(script:WaitForChild("CheckPlayerJump"))


---------- Instances ----------

local Default_Movement_ScreenGui = script:WaitForChild("Movement_ScreenGui")
local Movement_ScreenGui: ScreenGui
local Move_TextLabel: TextLabel


---------- Configuration variables ----------


----- Moves -----

local MovesConfig = script:WaitForChild("MovesConfig")

local baseWalkSpeed = MovesConfig:GetAttribute("Base_Speed")
local speedBuffs = {
	Crouch = MovesConfig:GetAttribute("Crouch_SpeedBuff"),
	GroundPound = MovesConfig:GetAttribute("GP_SpeedBuff"),
	Dive = MovesConfig:GetAttribute("Dive_SpeedBuff"),
	Roll = MovesConfig:GetAttribute("Roll_SpeedBuff"),
	BackFlip = MovesConfig:GetAttribute("BFlip_SpeedBuff"),
	LongJump = MovesConfig:GetAttribute("LJump_SpeedBuff"),
}


local baseJumpPower = MovesConfig:GetAttribute("Base_JumpPower")
local jumpPowerBuffs = {
	BackFlip = MovesConfig:GetAttribute("BFlip_JumpBuff"),
	LongJump = MovesConfig:GetAttribute("LJump_JumpBuff"),
	Jump1 = MovesConfig:GetAttribute("Jump1_JumpBuff"),
	Jump2 = MovesConfig:GetAttribute("Jump2_JumpBuff"),
	Jump3 = MovesConfig:GetAttribute("Jump3_JumpBuff"),
}

local groundPoundVelocityY_magnitude = MovesConfig:GetAttribute("GP_VelocityY")

local groundPoundSpinTime = MovesConfig:GetAttribute("GPSpin_Time")

local diveVelocityXZ_magnitude = MovesConfig:GetAttribute("Dive_VelocityXZ")
local diveVelocityY_magnitude = MovesConfig:GetAttribute("Dive_VelocityY")

local diveCancelVelocityY_magnitude = MovesConfig:GetAttribute("DiveCancel_VelocityY")

local backFlipVelocityXZ_magnitude = MovesConfig:GetAttribute("BFlip_VelocityXZ")

local jumpConsecutiveTime = MovesConfig:GetAttribute("Jump_ConsecTime")
local jumpLeaveGroundTime = MovesConfig:GetAttribute("Jump_LeaveGroundTime") -- aka coyote jump time


----- Audio -----

local AudioConfig = script:WaitForChild("AudioConfig")

local move_audioId = {
	Dive = AudioConfig:GetAttribute("Dive_Audio"),
	DiveCancel = AudioConfig:GetAttribute("DiveCancel_Audio"),
	GroundPoundSpin = AudioConfig:GetAttribute("GPSpin_Audio"),
	Jump3 = AudioConfig:GetAttribute("Jump3_Audio"),
	LongJump = AudioConfig:GetAttribute("LongJump_Audio"),
	BackFlip = AudioConfig:GetAttribute("BackFlip_Audio"),
}


----- Debug -----

local DebugConfig = script:WaitForChild("DebugConfig")

local movesUI_Enabled = DebugConfig:GetAttribute("MovesUI_Enabled")
local printMovements = DebugConfig:GetAttribute("Print_Movements")


---------- Variables ----------

local moveNames = {
	Crouch = "Crouch",
	Dive = "Dive",
	Jump = "Jump",
}

local move_actionName = {
	Crouch = "Movement: Crouch",
	Dive = "Movement: Dive",
	Jump = "Movement: Jump",
}

local localPlayer = Players.LocalPlayer


local playerStates = {
	Stand = "Stand",
	Crouch = "Crouch",
	GroundPound = "GroundPound",
	GroundPoundSpin = "GroundPoundSpin",
	Dive = "Dive",
	Roll = "Roll",
	Jump1 = "Jump1",
	Jump2 = "Jump2",
	Jump3 = "Jump3",
	LongJump = "LongJump",
	BackFlip = "BackFlip",
	DiveCancel = "DiveCancel",
	GroundPoundCancel = "GroundPoundCancel",
}

local currentPlayerState = nil


local lastFrameIsJumping = false


local toolConnections: {RBXScriptConnection} = {}
local landedEvent = Instance.new("BindableEvent")


----- Moves -----

local isDivingAction = false
local isCrouchingAction = false
local isJumpingAction = false


local canDive = false


local latestGroundPoundStartTime = -32


local lastGroundedTime = -32

local isInJumpingSequence = false
local lastLandTime = -32
local isLastLandFromJump = false
local jumpIndex = 1


----- Audio -----

local audioInteractionGroup = "TrickJumpingAudio"

local audioDeviceOutput: AudioDeviceOutput
local audioListener: AudioListener
local audioEmitter: AudioEmitter
local emitterWire: Wire

local audioEmitterCurve = {}
audioEmitterCurve[10] = 1
audioEmitterCurve[50] = 0.3
audioEmitterCurve[300] = 0

local move_audioPlayer: {string: AudioPlayer} = {}


---------- Initialize functions ----------

local function initializeVariables()
	currentPlayerState = nil

	lastFrameIsJumping = false


	isDivingAction = false
	isCrouchingAction = false
	isJumpingAction = false


	canDive = false


	latestGroundPoundStartTime = -32


	lastGroundedTime = -32

	isInJumpingSequence = false
	lastLandTime = -32
	isLastLandFromJump = false
	jumpIndex = 1
end


---------- User interface Functions----------

----- Touch buttons -----

local function modifyTouchButton(moveName: string, uiPosition: UDim2, uiSize: UDim2)
	-- Validate action binded
	if not next(ContextActionService:GetBoundActionInfo(move_actionName[moveName])) then
		return
	end

	-- Modify touch buttons
	ContextActionService:SetTitle(move_actionName[moveName], moveName)
	ContextActionService:SetPosition(move_actionName[moveName], uiPosition)
	local button = ContextActionService:GetButton(move_actionName[moveName])
	if button then
		button.Size = uiSize
		local actionTitle: TextLabel = button:FindFirstChild("ActionTitle")
		actionTitle.TextScaled = true
		local uiTextSizeConstraint = Instance.new("UITextSizeConstraint")
		uiTextSizeConstraint.MaxTextSize = 18
		uiTextSizeConstraint.Parent = actionTitle
	end
end

local function resizeTouchButtonUIs()
	local minAxis = math.min(Movement_ScreenGui.AbsoluteSize.X, Movement_ScreenGui.AbsoluteSize.y)
	local isSmallScreen = minAxis <= 500
	local buttonSize = isSmallScreen and 70 or 120
	local jumpButtonPosition = (
		isSmallScreen and UDim2.new(1, -(buttonSize*1.5-10), 1, -buttonSize - 20) or
		UDim2.new(1, -(buttonSize*1.5-10), 1, -buttonSize * 1.75)
	)
	local jumpButtonXOffset = jumpButtonPosition.X.Offset
	local jumpButtonYOffset = jumpButtonPosition.Y.Offset

	local touchButtonXDifference = 1.2*buttonSize
	local touchButtonUISize = UDim2.fromOffset(buttonSize, buttonSize)
	local move_touchButtonUIPosition = {
		Crouch = UDim2.new(UDim.new(1, jumpButtonXOffset - 0*touchButtonXDifference), UDim.new(1, jumpButtonYOffset - 1*buttonSize)),
		Dive = UDim2.new(UDim.new(1, jumpButtonXOffset - 1*touchButtonXDifference), UDim.new(1, jumpButtonYOffset - 1*buttonSize)),
		Jump = UDim2.new(UDim.new(1, jumpButtonXOffset - 0.5*touchButtonXDifference), UDim.new(1, jumpButtonYOffset - 1.75*buttonSize)),
	}

	for _, moveName in moveNames do
		modifyTouchButton(moveName, move_touchButtonUIPosition[moveName], touchButtonUISize)
	end
end


----- Screen UIs -----

local function repositionMovementGui()
	local minAxis = math.min(Movement_ScreenGui.AbsoluteSize.X, Movement_ScreenGui.AbsoluteSize.y)
	local isSmallScreen = minAxis <= 500
	local buttonSize = isSmallScreen and 70 or 120
	local jumpButtonPosition = (
		isSmallScreen and UDim2.new(1, -(buttonSize*1.5-10), 1, -buttonSize - 20) or
		UDim2.new(1, -(buttonSize*1.5-10), 1, -buttonSize * 1.75)
	)
	local jumpButtonYOffset = jumpButtonPosition.Y.Offset
	local touchButtonYOffset = jumpButtonYOffset - buttonSize
	local textLabelHeight = math.abs(Move_TextLabel.Size.Y.Offset)

	local jumpButtonEnabled = UserInputService.TouchEnabled
	local jumpButtonOverlaps = jumpButtonYOffset + buttonSize >= -20 - textLabelHeight

	if jumpButtonEnabled and jumpButtonOverlaps then
		Move_TextLabel.Position = UDim2.new(Move_TextLabel.Position.X, UDim.new(1, touchButtonYOffset - 5))
	else
		Move_TextLabel.Position = UDim2.new(1, -20, 1, -20)
	end
end

local function initializeUserInterfaces()
	-- Get player gui
	local PlayerGui = localPlayer.PlayerGui
	while not PlayerGui do
		PlayerGui = localPlayer.PlayerGui
	end

	-- Get or create screen gui
	Movement_ScreenGui = PlayerGui:FindFirstChild(Default_Movement_ScreenGui.Name)
	if not Movement_ScreenGui then
		Movement_ScreenGui = Default_Movement_ScreenGui:Clone()
		Movement_ScreenGui.Enabled = false
		Movement_ScreenGui.Parent = PlayerGui
	end

	-- Set instances
	Move_TextLabel = Movement_ScreenGui.Move_TextLabel
	Move_TextLabel.Text = ""

	-- Call functions related to absolute size
	resizeTouchButtonUIs()
	repositionMovementGui()
	table.insert(toolConnections, Movement_ScreenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(resizeTouchButtonUIs))
	table.insert(toolConnections, Movement_ScreenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(repositionMovementGui))

	-- Enable screen gui
	Movement_ScreenGui.Enabled = movesUI_Enabled
end

local function showUI()
	Movement_ScreenGui.Enabled = movesUI_Enabled
end

local function hideUI()
	Movement_ScreenGui.Enabled = false
end

local function showMovement(moveName: string)
	Move_TextLabel.Text = moveName
	if printMovements then
		print(moveName)
	end
end


---------- Audio functions ----------

local function createAudio(audioId: string, title: string)
	local audioPlayer = Instance.new("AudioPlayer")
	audioPlayer.Asset = audioId
	audioPlayer.Looping = false
	audioPlayer.Name = `{title}AudioPlayer`

	local wire = Instance.new("Wire")
	wire.SourceInstance = audioPlayer
	wire.TargetInstance = audioEmitter
	wire.Name = `{title}Wire`

	move_audioPlayer[title] = audioPlayer

	audioPlayer.Parent = audioEmitter
	wire.Parent = audioEmitter
end

local function initializeAudios()
	Debris:AddItem(audioDeviceOutput, 0)
	Debris:AddItem(audioListener, 0)
	Debris:AddItem(audioEmitter, 0)
	Debris:AddItem(emitterWire, 0)
	audioDeviceOutput = Instance.new("AudioDeviceOutput")
	audioListener = Instance.new("AudioListener")
	audioEmitter = Instance.new("AudioEmitter")
	emitterWire = Instance.new("Wire")
	audioDeviceOutput.Name = "TrickJumpAudioDeviceOutput"
	audioListener.Name = "TrickJumpAudioListener"
	audioListener.AudioInteractionGroup = audioInteractionGroup
	audioEmitter.Name = "TrickJumpAudioEmitter"
	audioEmitter:SetDistanceAttenuation(audioEmitterCurve)
	audioEmitter.AudioInteractionGroup = audioInteractionGroup
	emitterWire.SourceInstance = audioListener
	emitterWire.TargetInstance = audioDeviceOutput

	move_audioPlayer = {}
	for moveName, audioId in move_audioId do
		task.defer(function()
			createAudio(audioId, moveName)
		end)
	end

	emitterWire.Parent = audioListener
	audioListener.Parent = workspace.CurrentCamera
	audioDeviceOutput.Parent = SoundService
end

task.defer(initializeAudios)

local function playSound(state: string)
	local audioPlayer = move_audioPlayer[state]
	if not audioPlayer then
		return
	end

	audioPlayer.TimePosition = 0
	audioPlayer:Play()
end


---------- Player functions ----------

local function getPlayerInfo()
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
	local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart
	local playerInfo = {
		character = character,
		humanoid = humanoid,
		humanoidRootPart = humanoidRootPart,
	}
	return playerInfo
end

local function setPlayerState(state: string)
	currentPlayerState = state

	playSound(state)
end

local function isPlayerFloorMaterialAir()
	local playerInfo = getPlayerInfo()
	local humanoid = playerInfo.humanoid
	if not humanoid then
		return false
	end

	return humanoid.FloorMaterial == Enum.Material.Air
end

local function isPlayerJumping()
	if currentPlayerState == playerStates.Dive then return true end
	if currentPlayerState == playerStates.GroundPoundSpin then return true end
	if currentPlayerState == playerStates.GroundPound then return true end
	if currentPlayerState == playerStates.Jump1 then return true end
	if currentPlayerState == playerStates.Jump2 then return true end
	if currentPlayerState == playerStates.Jump3 then return true end
	if currentPlayerState == playerStates.LongJump then return true end
	if currentPlayerState == playerStates.BackFlip then return true end
	return false
end

local function isPlayerGrounded()
	if isPlayerJumping() then return false end
	if not currentPlayerState then return false end
	return time() - lastGroundedTime < jumpLeaveGroundTime
end

local function isPlayerClimbing()
	local playerInfo = getPlayerInfo()
	local humanoid = playerInfo.humanoid
	if not humanoid then
		return false
	end

	return humanoid:GetState() == Enum.HumanoidStateType.Climbing
end

local function getPlayerHorizontalVelocity()
	local playerInfo = getPlayerInfo()
	local humanoidRootPart = playerInfo.humanoidRootPart
	if not humanoidRootPart then
		return Vector3.new()
	end

	return humanoidRootPart.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
end

local function refreshPlayerSpeedJump()
	local playerInfo = getPlayerInfo()
	local humanoid = playerInfo.humanoid
	if not humanoid then
		return
	end

	humanoid.WalkSpeed = baseWalkSpeed + (speedBuffs[currentPlayerState] or 0)
	local newJumpPower = baseJumpPower + (jumpPowerBuffs[currentPlayerState] or 0)
	local newJumpVelocity = newJumpPower * 1.04515
	if humanoid.UseJumpPower then
		humanoid.JumpPower = newJumpPower
	else
		humanoid.JumpHeight = (math.pow(newJumpVelocity, 2) + 41.12071) / (2 * workspace.Gravity)
	end
end

local function setStanding()
	isLastLandFromJump = (
		currentPlayerState == playerStates.Jump1
		or currentPlayerState == playerStates.Jump2
		or currentPlayerState == playerStates.Jump3
	)
	setPlayerState(playerStates.Stand)
	canDive = true
	lastLandTime = time()

	showMovement("standing")
end

local function playerJump()
	local playerInfo = getPlayerInfo()
	local humanoid = playerInfo.humanoid
	if not humanoid then
		return
	end

	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
end

local function onCharacterAdded(character: Model)
	local function getHumanoidAndRootPartLoop(): (Humanoid, BasePart)
		local humanoid = character:FindFirstChildWhichIsA("Humanoid")
		while not humanoid do
			RunService.Heartbeat:Wait()
			humanoid = character:FindFirstChildWhichIsA("Humanoid")
		end
		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		while not humanoidRootPart do
			RunService.Heartbeat:Wait()
			humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		end
		return humanoid :: Humanoid, humanoidRootPart :: BasePart
	end

	local humanoid, humanoidRootPart = getHumanoidAndRootPartLoop()

	-- State connections
	local landedConnection = humanoid.StateChanged:Connect(function(old: Enum.HumanoidStateType, new: Enum.HumanoidStateType)
		if new == Enum.HumanoidStateType.Landed then
			landedEvent:Fire()
			return
		end

		if old == Enum.HumanoidStateType.Freefall then
			if new == Enum.HumanoidStateType.Climbing then
				landedEvent:Fire()
			end
		end
	end)
	table.insert(toolConnections, landedConnection)

	local jumpedConnection = humanoid.Jumping:Connect(function(active: boolean)
		if active and not isPlayerJumping() then
			setPlayerState(playerStates.Jump1)
			showMovement("normal jump")
		end
	end)
	table.insert(toolConnections, jumpedConnection)

	-- Audio
	task.defer(function()
		initializeAudios()
		audioEmitter.Parent = humanoidRootPart
	end)

	-- Clean up
	humanoid.Died:Once(function()
		landedConnection:Disconnect()
		jumpedConnection:Disconnect()
	end)
end


---------- Movement functions ----------

local function doDive()
	local playerInfo = getPlayerInfo()
	local humanoid = playerInfo.humanoid
	local humanoidRootPart = playerInfo.humanoidRootPart

	-- Validate info
	if not (humanoid and humanoidRootPart) then
		return
	end

	-- Get movement direction
	local moveDirection = humanoid.MoveDirection
	if humanoid.MoveDirection.Magnitude == 0 then
		moveDirection = Vector3.yAxis:Cross(humanoidRootPart.CFrame.RightVector)
	end

	-- Dive
	isInJumpingSequence = false
	setPlayerState(playerStates.Dive)

	local diveVelocity = moveDirection * diveVelocityXZ_magnitude + Vector3.new(0, diveVelocityY_magnitude, 0)
	humanoidRootPart.AssemblyLinearVelocity = diveVelocity

	showMovement("diving")
end

local function roll_func()
	-- Check jumping
	if isPlayerJumping() then
		return
	end

	-- Validate floor
	if isPlayerFloorMaterialAir() then
		return
	end

	-- Roll
	setPlayerState(playerStates.Roll)

	showMovement("rolling")
end

local function onDiveAction()
	if isDivingAction then return end
	isDivingAction = true

	-- Dive under certain contains
	local function dive_func()
		if not canDive then
			return
		end

		if not isPlayerFloorMaterialAir() then
			return
		end

		if currentPlayerState == playerStates.GroundPoundSpin then
			return
		end

		canDive = false
		doDive()
	end
	dive_func()

	-- Dive action
	while isDivingAction do
		roll_func()
		RunService.Heartbeat:Wait()
	end

	-- Roll ended
	if currentPlayerState == playerStates.Roll then
		setStanding()
	end
end

local function onDiveEnded()
	isDivingAction = false
end


local function doGroundPound()
	local playerInfo = getPlayerInfo()
	local humanoidRootPart = playerInfo.humanoidRootPart

	-- Validate info
	if not humanoidRootPart then
		return
	end

	-- Initial spin
	isInJumpingSequence = false
	setPlayerState(playerStates.GroundPoundSpin)

	showMovement("ground pound spin")

	local startTime = time()
	latestGroundPoundStartTime = startTime
	humanoidRootPart.Anchored = true
	while true do
		if time() - startTime > groundPoundSpinTime then
			break
		end
		RunService.Heartbeat:Wait()
	end

	if latestGroundPoundStartTime - startTime > 0.1 then
		return
	end

	-- Ground pound
	setPlayerState(playerStates.GroundPound)

	humanoidRootPart.Anchored = false
	humanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, groundPoundVelocityY_magnitude, 0)

	showMovement("ground pound")
end

local function doGroundPoundCancel()
	local playerInfo = getPlayerInfo()
	local humanoidRootPart = playerInfo.humanoidRootPart

	-- Validate info
	if not humanoidRootPart then
		return
	end

	-- Ground pound cancel
	setPlayerState(playerStates.GroundPoundCancel)

	humanoidRootPart.Anchored = false
	humanoidRootPart.AssemblyLinearVelocity = Vector3.new()

	showMovement("ground pound cancel")
end

local function doDiveCancel()
	local playerInfo = getPlayerInfo()
	local humanoidRootPart = playerInfo.humanoidRootPart

	-- Validate info
	if not humanoidRootPart then
		return
	end

	-- Dive cancel
	setPlayerState(playerStates.DiveCancel)

	humanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, diveCancelVelocityY_magnitude, 0)

	showMovement("dive cancel")
end

local function crouch_func()
	-- Check rolling
	if currentPlayerState == playerStates.Roll then
		return
	end

	-- Check jumping
	if isPlayerJumping() then
		return
	end

	-- Validate grounded
	if not isPlayerGrounded() then
		return
	end

	-- Crouch
	setPlayerState(playerStates.Crouch)

	showMovement("crouching")
end

local function onCrouchAction()
	if isCrouchingAction then return end
	isCrouchingAction = true

	-- Ground pound if not ground pounding & mid air
	if currentPlayerState ~= playerStates.GroundPoundSpin and currentPlayerState ~= playerStates.GroundPound then
		if not isPlayerGrounded() then
			doGroundPound()
		end
	end

	-- Crouch action
	while isCrouchingAction do
		crouch_func()
		RunService.Heartbeat:Wait()
	end

	-- Crouch ended
	if currentPlayerState == playerStates.Crouch then
		setStanding()
	end
end

local function onCrouchEnded()
	isCrouchingAction = false
end


local function doLongJump()
	local playerInfo = getPlayerInfo()
	local humanoid = playerInfo.humanoid
	local humanoidRootPart = playerInfo.humanoidRootPart

	-- Validate info
	if not (humanoid and humanoidRootPart) then
		return
	end

	-- Get movement direction
	local moveDirection = humanoid.MoveDirection
	if humanoid.MoveDirection.Magnitude == 0 then
		moveDirection = Vector3.yAxis:Cross(humanoidRootPart.CFrame.RightVector)
	end

	-- Long jump
	isInJumpingSequence = false
	setPlayerState(playerStates.LongJump)

	local longJumpVeloity = moveDirection * getPlayerHorizontalVelocity().Magnitude
	humanoidRootPart.AssemblyLinearVelocity = longJumpVeloity

	refreshPlayerSpeedJump()
	playerJump()

	showMovement("long jump")
end

local function doBackFlip()
	local playerInfo = getPlayerInfo()
	local humanoid = playerInfo.humanoid
	local humanoidRootPart = playerInfo.humanoidRootPart

	-- Validate info
	if not (humanoid and humanoidRootPart) then
		return
	end

	-- Get character direction
	local moveDirection = Vector3.yAxis:Cross(humanoidRootPart.CFrame.RightVector)

	-- Back flip
	isInJumpingSequence = false
	setPlayerState(playerStates.BackFlip)

	local backFlipVeloity = moveDirection * backFlipVelocityXZ_magnitude
	humanoidRootPart.AssemblyLinearVelocity = backFlipVeloity

	refreshPlayerSpeedJump()
	playerJump()

	showMovement("back flip")
end

local function doJump(resetConsecutive: boolean?)
	local playerInfo = getPlayerInfo()
	local humanoid = playerInfo.humanoid

	-- Validate info
	if not humanoid then
		return
	end

	-- Consecutive jump info
	local isConsecutive = isLastLandFromJump and (time() - lastLandTime < jumpConsecutiveTime)
	if isConsecutive and isInJumpingSequence and not resetConsecutive then
		jumpIndex += 1
	else
		jumpIndex = 1
	end
	if jumpIndex > 3 then
		jumpIndex = 1
	end

	-- Jump
	isInJumpingSequence = true
	local setState
	if jumpIndex == 1 then
		setState = playerStates.Jump1 
	elseif jumpIndex == 2 then
		setState = playerStates.Jump2
	elseif jumpIndex >= 3 then
		setState = playerStates.Jump3
	end
	setPlayerState(setState)

	refreshPlayerSpeedJump()
	playerJump()

	showMovement(`jump {jumpIndex}`)
end

local function doSpecialJump()
	-- Check player state
	if isPlayerClimbing() then
		----- Climbing -----

		-- Jump
		doJump(true)
	elseif not isPlayerGrounded() then
		----- Not grounded / mid air -----

		-- Gound pound cancel
		if currentPlayerState == playerStates.GroundPound then
			doGroundPoundCancel()
			return
		end

		-- Dive cancel
		if currentPlayerState == playerStates.Dive then
			doDiveCancel()
			return
		end
	else
		----- Grounded -----

		-- Long jump if rolling
		if currentPlayerState == playerStates.Roll then
			doLongJump()
			return
		end

		-- Back flip if crouching
		if currentPlayerState == playerStates.Crouch then
			doBackFlip()
			return
		end

		-- Jump
		doJump()
	end
end

local function jump_func()
	-- Check player state
	if isPlayerClimbing() then
		----- Climbing -----

		-- Jump
		doJump(true)
	elseif not isPlayerGrounded() then
		----- Not grounded / mid air -----

		-- nothing
	else
		----- Grounded -----

		-- Jump
		doJump()
	end
end

local function onJumpAction()
	if isJumpingAction then return end
	isJumpingAction = true

	-- Special jump
	doSpecialJump()

	RunService.Heartbeat:Wait()

	-- Jump action
	while isJumpingAction do
		jump_func()
		RunService.Heartbeat:Wait()
	end
end

local function onJumpEnded()
	isJumpingAction = false
end


---------- Action handler ----------

local function handleAction(actionName: string, inputState: Enum.UserInputState, inputObject: InputObject)
	local isBeginState = (inputState == Enum.UserInputState.Begin)
	local isCancelOrEndState = (inputState == Enum.UserInputState.Cancel) or (inputState == Enum.UserInputState.End)

	task.defer(function()
		if actionName == move_actionName.Dive then
			-- Dive action
			if isBeginState then
				onDiveAction()
			elseif isCancelOrEndState then
				onDiveEnded()
			end
		elseif actionName == move_actionName.Crouch then
			-- Crouch action
			if isBeginState then
				onCrouchAction()
			elseif isCancelOrEndState then
				onCrouchEnded()
			end
		elseif actionName == move_actionName.Jump then
			-- Jump action
			if isBeginState then
				onJumpAction()
			elseif isCancelOrEndState then
				onJumpEnded()
			end
		end
	end)

	return Enum.ContextActionResult.Sink
end


---------- Keybind functions ----------

local function bindAction(moveName: string, inputTypes: {Enum.KeyCode | Enum.UserInputType | Enum.PlayerActions})
	if moveName == moveNames.Jump then
		warn("[Movement]: Jump doesn't need to be binded!")
	end

	ContextActionService:BindActionAtPriority(move_actionName[moveName], handleAction, true, 10000, table.unpack(inputTypes))
end


local function unbindActions()
	for _, actionName in move_actionName do
		ContextActionService:UnbindAction(actionName)
	end
end


---------- Connection functions ----------

local function disconnect()
	for _, connection in toolConnections do
		connection:Disconnect()
	end
	table.clear(toolConnections)

	-- Stop detecting player jump
	CheckPlayerJump.disconnect()
	RunService:UnbindFromRenderStep("Movement: Jump")

	-- Refresh player speed & jump power
	initializeVariables()
	refreshPlayerSpeedJump()
end

local function connect()
	-- Disconnect old
	disconnect()

	-- Initialize variables
	initializeVariables()

	-- Initialize user interfaces
	initializeUserInterfaces()

	-- Player jump detection
	CheckPlayerJump.connect(true)
	RunService:BindToRenderStep("Movement: Jump", Enum.RenderPriority.Input.Value + 2, function()
		local isJumping = CheckPlayerJump.isJumping
		if isJumping and not lastFrameIsJumping then
			handleAction(move_actionName.Jump, Enum.UserInputState.Begin, nil)
		elseif not isJumping and lastFrameIsJumping then
			handleAction(move_actionName.Jump, Enum.UserInputState.End, nil)
		end
		lastFrameIsJumping = isJumping
	end)


	----- Connect new -----

	-- Player move and jump stats
	table.insert(toolConnections, RunService.Heartbeat:Connect(function()
		refreshPlayerSpeedJump()
	end))

	-- Grounded check
	table.insert(toolConnections, RunService.Heartbeat:Connect(function()
		if not isPlayerFloorMaterialAir() then
			lastGroundedTime = time()
		end
	end))

	-- Standing check
	if not isPlayerFloorMaterialAir() then
		task.defer(setStanding)
	end
	table.insert(toolConnections, landedEvent.Event:Connect(function()
		setStanding()
	end))

	-- Character added
	local initialCharacter = localPlayer.Character
	task.defer(function()
		onCharacterAdded(initialCharacter)
	end)
	table.insert(toolConnections, localPlayer.CharacterAdded:Connect(onCharacterAdded))
end


---------- Module fields ----------

table.freeze(moveNames)
module.moveNames = moveNames

module.bindAction = bindAction

module.connect = connect

module.showUI = showUI
module.hideUI = hideUI

module.unbindAndDisconnect = function()
	unbindActions()
	disconnect()
end


---------- Return module ----------

return module
