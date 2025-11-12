--[[ 
@ Name: SmoothShiftLock 
@ Author: x33 
@ Version: 1.3.0 
@ Variables: 
└ .Enabled - ShiftLock's enabled state. 
@ Methods: 
│ :Enable() - Enables the whole module. 
│ :Disable() - Disables the whole module. 
│ :IsEnabled(): boolean - Returns ShiftLock's enabled state. 
└ :ToggleShiftLock(Enable: boolean?) - Toggles the ShiftLock, if Enable parameter is provided then ShiftLock will be toggled to it. 
--]]

local SmoothShiftLock = {}
SmoothShiftLock.__index = SmoothShiftLock

--// [ Locals: ]
--// Services
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

--// Utilities
local Maid = require(script:WaitForChild("Maid"))
local Spring = require(script:WaitForChild("Spring"))

--// Instances
local LocalPlayer = Players.LocalPlayer
local PlayerMouse = LocalPlayer:GetMouse()
local Camera = Workspace.CurrentCamera

--// Configuration
local Config = {
	MOBILE_SUPPORT = true, --// Adds a button to toggle the shift lock for touchscreen devices
	SMOOTH_CHARACTER_ROTATION = true, --// If your character should rotate smoothly or not
	CHARACTER_ROTATION_SPEED = 3, --// How quickly character rotates smoothly
	TRANSITION_SPRING_DAMPER = 0.7, --// Camera transition spring damper, test it out to see what works for you
	CAMERA_TRANSITION_IN_SPEED = 10, --// How quickly locked camera moves to offset position
	CAMERA_TRANSITION_OUT_SPEED = 14, --// How quickly locked camera moves back from offset position
	LOCKED_CAMERA_OFFSET = Vector3.new(1.75, 0.25, 0), --// Locked camera offset
	LOCKED_MOUSE_ICON = "rbxassetid://137745848074171", --// Locked mouse icon
	DEFAULT_MOUSE_ICON = "rbxassetid://68308747",
	SHIFT_LOCK_KEYBINDS = {Enum.KeyCode.LeftControl, Enum.KeyCode.RightControl}, --// Shift lock keybinds
	NO_ICON = "rbxassetid://0"
}

local Bow_Config = {
	MOBILE_SUPPORT = true,
	CHARACTER_ROTATION_SPEED = 3,
	TRANSITION_SPRING_DAMPER = 1,
	CAMERA_TRANSITION_IN_SPEED = 12,
	CAMERA_TRANSITION_OUT_SPEED = 12,
	LOCKED_CAMERA_OFFSET = Vector3.new(3, 1.25, 0)
}
SmoothShiftLock.Bow_Config = Bow_Config

--// [ Constructor: ]
function SmoothShiftLock.new()
	local self = setmetatable({}, SmoothShiftLock)

	--// Utilities
	self._runtimeMaid = Maid.new()
	self._shiftlockMaid = Maid.new()
	self._cameraOffsetSpring = Spring.new(Vector3.new(0, 0, 0))
	self._cameraOffsetSpring.Damper = Config.TRANSITION_SPRING_DAMPER

	--// Variables
	self.Enabled = false
	
	self.OffsetValue = LocalPlayer:FindFirstChild("OffsetValue") or Instance.new("Vector3Value", LocalPlayer)
	self.OffsetValue.Name = "OffsetValue"

	--// Setup
	self:Enable()
	return self
end

--// [ Module Functions: ]
function SmoothShiftLock:Enable()
	self:_refreshCharacterVariables()
	self._runtimeMaid:GiveTask(LocalPlayer.CharacterAdded:Connect(function()
		self:_refreshCharacterVariables()
	end))

	local toggleEvent = script:FindFirstChild("ToggleShiftLockEvent")
	local changeOffsetEvent = script:FindFirstChild("ChangeOffsetEvent")

	if toggleEvent and toggleEvent:IsA("BindableEvent") then
		self._runtimeMaid:GiveTask(toggleEvent.Event:Connect(function(cmd, type)
			self:ToggleShiftLock(not self.Enabled, cmd, type)
		end))
	end

	if changeOffsetEvent and changeOffsetEvent:IsA("BindableEvent") then
		self._runtimeMaid:GiveTask(changeOffsetEvent.Event:Connect(function(offset, cmd)
			if cmd == "Bow" and typeof(offset) == "Vector3" then
				if self.Enabled then
					self._cameraOffsetSpring.Speed = Bow_Config.CAMERA_TRANSITION_IN_SPEED
				else
					self._cameraOffsetSpring.Speed = Bow_Config.CAMERA_TRANSITION_OUT_SPEED
				end
				--print(self._cameraOffsetSpring.Speed, "speed print")
				self._cameraOffsetSpring.Target = offset
			end
		end))
	end

	--// Bind Keybinds
	ContextActionService:BindActionAtPriority(
		"ShiftLockSwitchAction",
		function(Name, State, Input)
			return self:_doShiftLockSwitch(Name, State, Input)
		end,
		Config.MOBILE_SUPPORT,
		Enum.ContextActionPriority.Medium.Value,
		unpack(Config.SHIFT_LOCK_KEYBINDS)
	)

	--// Camera Offset
	self._runtimeMaid:GiveTask(RunService.RenderStepped:Connect(function()
		if self.Head.LocalTransparencyModifier > 0.6 then
			return
		end

		local CameraCFrame = Camera.CoordinateFrame
		local NewCFrame = CameraCFrame * CFrame.new(CameraCFrame.Position, self.Head.Position)
		local Distance = (self.Head.Position - CameraCFrame.Position).magnitude

		-- changes made here by az9
		if Distance <= 1 then return end
		self.OffsetValue.Value = self._cameraOffsetSpring.Position
		
		Camera.CFrame = (Camera.CFrame * CFrame.new(self._cameraOffsetSpring.Position))

		if self.Enabled and UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
			self:_updateMouseState()
		end
	end))
end

function SmoothShiftLock:Disable()
	self._runtimeMaid:DoCleaning()
	self._shiftlockMaid:DoCleaning()

	--// Unbind Keybinds
	ContextActionService:UnbindAction("ShiftLockSwitchAction")
end

--// [ Internal Functions: ]
function SmoothShiftLock:_refreshCharacterVariables()
	self.Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	self.RootPart = self.Character:WaitForChild("HumanoidRootPart")
	self.Humanoid = self.Character:WaitForChild("Humanoid")
	self.Head = self.Character:WaitForChild("Head")
end

--// Internal function for ContextActionService
function SmoothShiftLock:_doShiftLockSwitch(_, State: Enum.UserInputState)
	if State == Enum.UserInputState.Begin then
		self:ToggleShiftLock()
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end

--// Update the mouse behaviour
function SmoothShiftLock:_updateMouseState()
	UserInputService.MouseBehavior = (self.Enabled and Enum.MouseBehavior.LockCenter) or Enum.MouseBehavior.Default
end

--// Update the mouse icon
function SmoothShiftLock:_updateMouseIcon(icon: string)
	if icon ~= nil then
		PlayerMouse.Icon = icon
		if icon == Config.NO_ICON then
			UserInputService.MouseIconEnabled = false
		end
	else
		UserInputService.MouseIconEnabled = true
		PlayerMouse.Icon = (self.Enabled and Config.LOCKED_MOUSE_ICON) or Config.DEFAULT_MOUSE_ICON
	end
end

--// Transition the camera to lock offset
function SmoothShiftLock:_transitionLockOffset(type: string)
	local ConfigReal
	if type and type == "Bow" then
		ConfigReal = Bow_Config
	else
		ConfigReal = Config
	end

	if self.Enabled then
		self._cameraOffsetSpring.Speed = ConfigReal.CAMERA_TRANSITION_IN_SPEED
		self._cameraOffsetSpring.Target = ConfigReal.LOCKED_CAMERA_OFFSET
	else
		self._cameraOffsetSpring.Speed = ConfigReal.CAMERA_TRANSITION_OUT_SPEED
		self._cameraOffsetSpring.Target = Vector3.new(0, 0, 0)
	end
end

--// [ External Functions: ]
function SmoothShiftLock:IsEnabled(): boolean
	return self.Enabled
end

--// ShiftLock toggle function
function SmoothShiftLock:ToggleShiftLock(Enable: boolean?, cmd: string, type: string)
	if Enable ~= nil then
		self.Enabled = Enable
	else
		self.Enabled = not self.Enabled
	end

	self:_updateMouseState()
	self:_updateMouseIcon()

	if cmd ~= nil then
		if cmd == "None" then
			self:_updateMouseIcon(Config.NO_ICON) --Config.NO_ICON
		end
	end

	local ConfigReal
	if type and type == "Bow" then
		ConfigReal = Bow_Config
	else
		ConfigReal = Config
	end

	self:_transitionLockOffset(type)

	if self.Enabled then
		self._shiftlockMaid:GiveTask(RunService.RenderStepped:Connect(function(Delta: number)
			if (self.Humanoid and self.RootPart) then
				self.Humanoid.AutoRotate = not self.Enabled
			end

			--// Rotate the character
			if self.Humanoid.Sit then return end

			if Config.SMOOTH_CHARACTER_ROTATION then
				local x, y, z = Camera.CFrame:ToOrientation()
				self.RootPart.CFrame = self.RootPart.CFrame:Lerp(
					CFrame.new(self.RootPart.Position) * CFrame.Angles(0, y, 0),
					Delta * 5 * ConfigReal.CHARACTER_ROTATION_SPEED
				)
			else
				local x, y, z = Camera.CFrame:ToOrientation()
				self.RootPart.CFrame = CFrame.new(self.RootPart.Position) * CFrame.Angles(0, y, 0)
			end
		end))
	else
		self.Humanoid.AutoRotate = true
		self._shiftlockMaid:DoCleaning()
	end
end

return SmoothShiftLock.new()
