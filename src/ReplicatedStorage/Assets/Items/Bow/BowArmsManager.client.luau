wait()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera

local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()
local oldIcon = Mouse.Icon
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local UpperTorso = Character:WaitForChild("UpperTorso")
local BowUI = Player.PlayerGui:WaitForChild("BowUI")
local Crosshair : ImageLabel = BowUI:WaitForChild("Crosshair")

local RightArm = Character:WaitForChild("RightUpperArm")
local LeftArm = Character:WaitForChild("LeftUpperArm")

local RightShoulder = RightArm:WaitForChild("RightShoulder")
local LeftShoulder = LeftArm:WaitForChild("LeftShoulder")

local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

local AIM_UPDATE_SPEED = 0.75
local FIRST_PERSON_DISTANCE = 1.5

local DefaultRightC0 = RightShoulder.C0
local DefaultLeftC0 = LeftShoulder.C0

local function checkerPartUpdate(pos : Vector3)
	local part = workspace:FindFirstChild("checker")
	if not part then return end
	
	if not pos then
		part.Transparency = 1
		return
	end
	
	part.Transparency = 0.7
	part.Position = pos
end

RunService.RenderStepped:Connect(function()
	-- another way
	local screenSize = Camera.ViewportSize
	local centerX, centerY = screenSize.X / 2, screenSize.Y / 2
	
	local offsetValue = Player:FindFirstChild("OffsetValue")
	local visualOffset = if offsetValue then offsetValue.Value else Vector3.new()
	local finalCf = Camera:GetRenderCFrame() * CFrame.new(visualOffset)
	local ViewportRay = Camera:ViewportPointToRay(centerX, centerY)

	-- cast
	local rayparms = RaycastParams.new()
	rayparms.FilterType = Enum.RaycastFilterType.Exclude
	
	local list = Character:GetChildren()
	if workspace:FindFirstChild("checker") then table.insert(list, workspace.checker) end
	
	rayparms.FilterDescendantsInstances = list

	local result = workspace:Raycast(finalCf.Position, ViewportRay.Direction * 10000, rayparms)
	local corresponding = result and result.Position or finalCf.Position + ViewportRay.Direction * 150
	
	corresponding = Vector3.new(corresponding.X, corresponding.Y, corresponding.Z)
	Player:SetAttribute("AimPosition", corresponding)

	checkerPartUpdate(corresponding)
	
	local HasBow = Character:FindFirstChild("Bow")
	if not HasBow or Humanoid.Health <= 0 then
		-- Reset to default if no bow or dead
		RightShoulder.C0 = RightShoulder.C0:Lerp(DefaultRightC0, AIM_UPDATE_SPEED)
		LeftShoulder.C0 = LeftShoulder.C0:Lerp(DefaultLeftC0, AIM_UPDATE_SPEED)
		--Mouse.Icon = oldIcon
		return
	end
	
	--Mouse.Icon = "rbxassetid://82087165201461"

	local CamCF = Camera.CFrame
	local Head = Character:FindFirstChild("Head")
	local HeadPos = Head and Head.Position or UpperTorso.Position
	local CamDistance = (HeadPos - CamCF.Position).Magnitude
	local TorsoCF = UpperTorso.CFrame

	local TargetRight
	local TargetLeft

	if CamDistance <= FIRST_PERSON_DISTANCE then
		-- First Person: Arms aim toward the camera's view direction
		TargetRight = (CamCF * CFrame.new(0.85, -1, -0.75)):ToObjectSpace(TorsoCF):Inverse() --* CFrame.Angles(math.rad(8), math.rad(52), 0)
		TargetLeft = (CamCF * CFrame.new(-0.45, -0.75, -0.25)):ToObjectSpace(TorsoCF):Inverse() --* CFrame.Angles(0, math.rad(50), math.rad(10))
	else
		-- Third Person: Use camera rotation, anchored to torso position
		--local LookCF = CFrame.lookAt(UpperTorso.Position, UpperTorso.Position + Camera.CFrame.LookVector)

		--TargetRight = (LookCF * CFrame.new(1, 0.5, -0.25)):ToObjectSpace(TorsoCF):Inverse() 
		--TargetLeft = (LookCF * CFrame.new(-1, 0.5, -0.25)):ToObjectSpace(TorsoCF):Inverse()
		TargetRight = DefaultRightC0
		TargetLeft = DefaultLeftC0
	end

	RightShoulder.C0 = RightShoulder.C0:Lerp(TargetRight, AIM_UPDATE_SPEED)
	LeftShoulder.C0 = LeftShoulder.C0:Lerp(TargetLeft, AIM_UPDATE_SPEED)
end)

