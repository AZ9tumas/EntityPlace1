local ArcService = {}

local TweenService = game:GetService("TweenService")
local Assets = game.ReplicatedStorage.Assets
local Vfx = Assets.VFX
local BowAssets = Vfx.Bow
local Container = BowAssets.Container
local Beam = Container.Beam
local BowSettings = game.ReplicatedStorage.Settings.Bow
local ArcDropMultiplier = BowSettings.ArcDrop.ArcDropMultiplier
function ArcService:VisualiseTrajectory(Character: Model, DrawTime: number, TargetPosition: Vector3)

local Bow

for _, Bows in ipairs(Character:GetChildren()) do
    if Bows.Name == "Bow" and Bows.ClassName == "Model" then
        Bow = Bows
        break
    end
end

if not Bow then return end

local Attachment0 = Bow.Cylinder:FindFirstChild("Attachment0")
if not Attachment0 then return end

local Origin = Attachment0.WorldPosition

local RawDirection = TargetPosition - Attachment0.WorldPosition
local Direction = RawDirection.Magnitude > 0 and RawDirection.Unit or Vector3.new(0, 0, -1)
	local RawDirection = TargetPosition - Attachment0.WorldPosition
	local Direction

	if RawDirection.Magnitude > 0 then
		Direction = RawDirection.Unit
		--print("Using RawDirection.Unit:", Direction)
	else
		Direction = Vector3.new(0, 0, -1)
		print("Using fallback direction:", Direction)
	end

-- Calculate initial velocity based on draw time

local function CalculateInitialVelocity()

    if DrawTime > 2.5 then
        DrawTime = 2.5
    end

    local Speed = DrawTime * 200
    return Direction * Speed
end



local InitialVelocity = CalculateInitialVelocity()
local Acceleration = Vector3.new(0, -workspace.Gravity * (1/ArcDropMultiplier.Value) , 0)


if Character:FindFirstChild("TrajectoryFolder") then
    Character.TrajectoryFolder:Destroy()
end

local Folder = Instance.new("Folder")
Folder.Name = "TrajectoryFolder"
Folder.Parent = Character

local Step = 0.05
local MaxTime = 2.5
local LastAttachment

for T = 0, MaxTime, Step do

    local Position = Origin + (InitialVelocity * T) + 0.5 * Acceleration * (T ^ 2)

    if Position.Y <= 0 then break end

	local Marker = Instance.new("Part")
	
    Marker.Size = Vector3.new(0.8, 0.8, 0.8)
		Marker.Shape =Enum.PartType.Ball
		Marker.Anchored = true
		Marker.CanCollide = false
		Marker.Material = Enum.Material.Neon
		Marker.Color = Color3.fromRGB(34, 122, 255)
		Marker.CFrame = CFrame.new(Position)
		Marker.Transparency = 1
		Marker.Parent = Folder

		local MarkerAttachment = Instance.new("Attachment")
		MarkerAttachment.Parent = Marker

		if LastAttachment then
			local BeamClone = Beam:Clone()

			BeamClone.Parent = Folder
			BeamClone.Attachment0 = LastAttachment
			BeamClone.Attachment1 = MarkerAttachment

		end

		LastAttachment = MarkerAttachment
	end
end

return ArcService