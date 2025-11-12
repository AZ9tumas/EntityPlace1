local Tool = script.Parent
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Events = ReplicatedStorage.Remotes
local BowEvent = Events.BowEvent

local EventsFunc = Tool.Events
local EquipRF = EventsFunc.Equip
local UnequipRF = EventsFunc.Unequip
local ToolActivateRF = EventsFunc.ToolActivate
local ToolDeactivateRF = EventsFunc.ToolDeactivate

local Player = game.Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid: Humanoid = Character:WaitForChild("Humanoid")
local Mouse = Player:GetMouse()
local repModules = ReplicatedStorage:WaitForChild("Modules")

local Camera = workspace.CurrentCamera

local Slm = repModules.SmoothShiftLock
local ShiftLockModule = require(Slm)
local SlEvent = Slm:FindFirstChild("ToggleShiftLockEvent")

local As = Tool.ArcService
local ArcService = require(As)
local Offset = Vector3.new(3, 0, 0)

local ActivationStartTime = nil

local Variables = Tool:WaitForChild("Variables")
local Attributes = Tool:WaitForChild("Attributes")

local IsAiming = Variables:WaitForChild("IsAiming")
local TimeElapsedNumberValue = Variables:WaitForChild("TimeElapsed")
local CanShoot = Attributes:WaitForChild("CanShoot")

local BowUI = Player.PlayerGui:WaitForChild("BowUI")
local Crosshair = BowUI:WaitForChild("Crosshair")

local MobileGUI = Player.PlayerGui:WaitForChild("MobileGUI")
local MobileButtons = MobileGUI:WaitForChild("MobileButtons")
local ShootButton = MobileButtons:WaitForChild("ShootButton")

local function IsToolEquipped(): boolean
	return Tool:IsDescendantOf(Character)
end

local BowUIManager = require(script.Parent.BowUIManager)
local FpvAnimationControl = require(script.Parent.FPVAnimationControl)

local RenderConnection
local function ClearTrajectory(Character)
	if Character:FindFirstChild("TrajectoryFolder") then
		Character.TrajectoryFolder:Destroy()
	end
end

local function StopAiming()
	if RenderConnection then
		RenderConnection:Disconnect()
		RenderConnection = nil
	end
	ClearTrajectory(Character)
	IsAiming.Value = false
end

local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera

local function GetMouseHit(IgnoreList): Vector3
	return Camera:GetAttribute("AimPosition")
end

local function GetScreenCenterHit(IgnoreList): Vector3
	return Camera:GetAttribute("AimPosition")
end

Mouse.Button2Down:Connect(function()
	if IsToolEquipped() then
		--BowUiManager:ZoomRmb(Camera, true)
	end
end)

Mouse.Button2Up:Connect(function()
	if IsToolEquipped() then
		--BowUiManager:ZoomRmb(Camera, false)
	end
end)

EquipRF.Event:Connect(function()
	BowEvent:FireServer("Equipped")
	
	local part = workspace:FindFirstChild("checker") or Instance.new("Part", workspace)
	part.Transparency = 0.7
	part.CanCollide = false
	part.Anchored = true
	part.Name = "checker"
	part.Size = Vector3.new(1, 1, 1)
	part.BrickColor = BrickColor.Red()
	
	Mouse.TargetFilter = part

	if SlEvent then
		SlEvent:Fire("None", "Bow")
	end

	BowUIManager:EnableBowUI(Player, true)
	BowUIManager:ZoomForTool(Camera, true)
	
	--Humanoid:EquipTool(Tool)
end)

UnequipRF.Event:Connect(function()
	StopAiming()
	BowEvent:FireServer("Unequipped")
	
	if workspace:FindFirstChild("checker") then
		workspace.checker:Destroy()
	end

	if SlEvent then
		SlEvent:Fire()
	end

	BowUIManager:EnableBowUI(Player, false)
	BowUIManager:ZoomForTool(Camera, false)
	
	--Humanoid:UnequipTools()
end)

ToolActivateRF.Event:Connect(function()
	print("Activated")
	if CanShoot.Value and not MobileButtons.Visible then
		ActivationStartTime = tick()
		BowEvent:FireServer("Activated")

		BowUIManager:TweenDrawStages(Player)
		BowUIManager:ZoomForAim(Camera, true)

		local Head = Character:WaitForChild("Head")

		if Head.LocalTransparencyModifier > 0.6 then
			FpvAnimationControl:ChargeAndHoldBow(Player)
		end

		IsAiming.Value = true
	end
end)
--[[
Tool.Activated:Connect(function()
	print("Activated")
	if CanShoot.Value and not MobileButtons.Visible then
		ActivationStartTime = tick()
		BowEvent:FireServer("Activated")

		BowUIManager:TweenDrawStages(Player)
		BowUIManager:ZoomForAim(Camera, true)

		local Head = Character:WaitForChild("Head")

		if Head.LocalTransparencyModifier > 0.6 then
			FpvAnimationControl:ChargeAndHoldBow(Player)
		end

		IsAiming.Value = true
	end
end)

Tool.Deactivated:Connect(function()
	if CanShoot.Value and not MobileButtons.Visible then
		if ActivationStartTime then
			local ElapsedTimeSince = tick() - ActivationStartTime
			ActivationStartTime = nil

			local HitPosition = GetMouseHit({Player.Character}) -- Mouse.Hit.Position
			BowUIManager:FlushTweens()
			BowUIManager:ZoomForAim(Camera, false)

			local Head = Character:WaitForChild("Head")

			BowEvent:FireServer("Deactivated", HitPosition, ElapsedTimeSince)

			if Head.LocalTransparencyModifier > 0.6 then
				FpvAnimationControl:ShootBow(Player, HitPosition, ElapsedTimeSince)
			end

			StopAiming()
		else
			warn("Tool was deactivated without being activated first.")
			StopAiming()
		end
	end
end)]]

ToolDeactivateRF.Event:Connect(function()
	if CanShoot.Value and not MobileButtons.Visible then
		if ActivationStartTime then
			local ElapsedTimeSince = tick() - ActivationStartTime
			ActivationStartTime = nil

			local HitPosition = GetMouseHit({Player.Character}) -- Mouse.Hit.Position
			BowUIManager:FlushTweens()
			BowUIManager:ZoomForAim(Camera, false)

			local Head = Character:WaitForChild("Head")

			BowEvent:FireServer("Deactivated", HitPosition, ElapsedTimeSince)

			if Head.LocalTransparencyModifier > 0.6 then
				FpvAnimationControl:ShootBow(Player, HitPosition, ElapsedTimeSince)
			end

			StopAiming()
		else
			warn("Tool was deactivated without being activated first.")
			StopAiming()
		end
	end
end)

ShootButton.MouseButton1Down:Connect(function()
	local AimingStart

	IsAiming.Changed:Connect(function(IsAimingNow)
		if IsAimingNow then
			local HitPosition = GetScreenCenterHit({Player.Character})
			print(HitPosition)
			AimingStart = tick()
	
			RenderConnection = RunService.RenderStepped:Connect(function()
				local DrawTime = tick() - AimingStart
				ArcService:VisualiseTrajectory(Character, DrawTime, GetScreenCenterHit({Player.Character}))
			end)
		else
			StopAiming()
		end
	end)
	
	if CanShoot.Value then
		ActivationStartTime = tick()
		BowEvent:FireServer("Activated")

		BowUIManager:TweenDrawStages(Player)
		BowUIManager:ZoomForAim(Camera, true)

		local Head = Character:WaitForChild("Head")

		if Head.LocalTransparencyModifier > 0.6 then
			FpvAnimationControl:ChargeAndHoldBow(Player)
		end

		IsAiming.Value = true
	end
end)

ShootButton.MouseButton1Up:Connect(function()
	if CanShoot.Value then
		if ActivationStartTime then
			local ElapsedTimeSince = tick() - ActivationStartTime
			ActivationStartTime = nil

			local HitPosition = GetScreenCenterHit({Player.Character})
			BowUIManager:FlushTweens()
			BowUIManager:ZoomForAim(Camera, false)

			local Head = Character:WaitForChild("Head")

			BowEvent:FireServer("Deactivated", HitPosition, ElapsedTimeSince)

			if Head.LocalTransparencyModifier > 0.6 then
				FpvAnimationControl:ShootBow(Player, HitPosition, ElapsedTimeSince)
			end

			StopAiming()
		else
			warn("Tool was deactivated without being activated first.")
			StopAiming()
		end
	end
end)

Character.Humanoid.Died:Connect(function()
	if SlEvent then
		SlEvent:Fire()
	end
	StopAiming()
end)
