local BowUIManager = {}

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")


-- Settings // Directories

local Settings = ReplicatedStorage.Settings
local BowSettings = Settings.Bow

local ItemsSFX = SoundService.ItemsSFX
local BowSounds = ItemsSFX.Bow

local DrawStage = BowSettings.DistanceDrawColors
local FovStage = BowSettings.FovStages

local ShortRange = DrawStage.ShortRange
local MediumRange = DrawStage.MediumRange
local LongRange = DrawStage.LongRange

-- Settings // Fov

local Aim = FovStage.Aim
local AimZoomIn = Aim.ZoomIn
local AimZoomOut = Aim.ZoomOut

local Equip = FovStage.Equip
local EquipZoomIn = Equip.ZoomIn
local EquipZoomOut = Equip.ZoomOut

local Zoom = FovStage.Zoom
local ZoomIn = Zoom.ZoomIn
local ZoomOut = Zoom.ZoomOut

-- Settings // Values

local SHORT_RANGE = ShortRange.Value
local MEDIUM_RANGE = MediumRange.Value
local LONG_RANGE = LongRange.Value

local AIM_ZOOM_IN = AimZoomIn.Value
local AIM_ZOOM_OUT = AimZoomOut.Value

local EQUIP_ZOOM_IN = EquipZoomIn.Value
local EQUIP_ZOOM_OUT = EquipZoomOut.Value

local ZOOM_IN = ZoomIn.Value
local ZOOM_OUT = ZoomOut.Value

-- Sounds // Bow
local ModeChangeSFX = BowSounds.ModeChange

function BowUIManager:EnableBowUI(Player: Player, Enable: boolean): ScreenGui
	local PlayerGui = Player:WaitForChild("PlayerGui")
	local BowUI = PlayerGui:WaitForChild("BowUI")
	BowUI.Enabled = Enable

	local MobileGUI = PlayerGui:WaitForChild("MobileGUI")
	MobileGUI.MobileButtons.ShootButton.Visible = Enable

	return BowUI
end

function BowUIManager:ReturnBowUI(Player: Player): ScreenGui
	local PlayerGui = Player:WaitForChild("PlayerGui")
	local BowUI = PlayerGui:WaitForChild("BowUI")
	return BowUI
end

function BowUIManager:ModeChange(Character: Model)
	local Sound = ModeChangeSFX:Clone()
	Sound.Parent = Character
	Sound:Play()
	
	local Connection
	Connection  = Sound.Ended:Connect(function()
		Sound:Destroy()
		Connection:Disconnect()
		Connection = nil
	end)
end

function BowUIManager:TweenDrawStages(Player: Player)
	local BowUI = BowUIManager:ReturnBowUI(Player)
	local Crosshair: ImageLabel = BowUI:WaitForChild("Crosshair")

	local NormalToShortTween = TweenService:Create(Crosshair, TweenInfo.new(0.4), {ImageColor3 = SHORT_RANGE})
	local ShortToMediumTween = TweenService:Create(Crosshair, TweenInfo.new(0.85), {ImageColor3 = MEDIUM_RANGE})
	local MediumToLongTween = TweenService:Create(Crosshair, TweenInfo.new(1.25), {ImageColor3 = LONG_RANGE})

	local LongToShortTween = TweenService:Create(Crosshair, TweenInfo.new(0.85), {ImageColor3 = Color3.new(255, 255, 255)})
	NormalToShortTween:Play()

	NormalToShortTween.Completed:Connect(function(PlaybackState)
		ShortToMediumTween:Play()
		BowUIManager:ModeChange(Player.Character)
		--print("play 1")
	end)

	ShortToMediumTween.Completed:Connect(function(PlaybackState)
		if PlaybackState ~= Enum.PlaybackState.Cancelled then
			MediumToLongTween:Play()
			BowUIManager:ModeChange(Player.Character)
			--print("play 2")
		end
	end)

	MediumToLongTween.Completed:Connect(function(PlaybackState)
		if PlaybackState ~= Enum.PlaybackState.Cancelled then
			BowUIManager:ModeChange(Player.Character)
		end
	end)

	function BowUIManager:FlushTweens()

		--NormalToShortTween:Cancel()
		NormalToShortTween:Destroy()

		--ShortToMediumTween:Cancel()
		ShortToMediumTween:Destroy()

		--MediumToLongTween:Cancel()
		MediumToLongTween:Destroy()

		LongToShortTween:Play()
	end
end

function BowUIManager:ZoomForTool(Camera: Camera, Equip: boolean)
	local CameraFOV = Camera.FieldOfView

	if Equip then
		local EquipZoomIn = TweenService:Create(Camera, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {FieldOfView = EQUIP_ZOOM_IN})
		EquipZoomIn:Play()
	else
		local EquipZoomOut = TweenService:Create(Camera, TweenInfo.new(0.75, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {FieldOfView = EQUIP_ZOOM_OUT})
		EquipZoomOut:Play()
	end

end

function BowUIManager:ZoomForAim(Camera: Camera, ZoomIn: boolean)
	local CameraFOV = Camera.FieldOfView

	if ZoomIn then
		local AimZoomIn = TweenService:Create(Camera, TweenInfo.new(0.75, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {FieldOfView = AIM_ZOOM_IN})
		AimZoomIn:Play()
	else
		local AimZoomOut = TweenService:Create(Camera, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {FieldOfView = AIM_ZOOM_OUT})
		AimZoomOut:Play()
	end
end

function BowUIManager:ZoomRMB(Camera: Camera, ZoomIn: boolean)
	local CameraFOV = Camera.FieldOfView
	print(Camera.FieldOfView, "ZOOM CAMERA PRINT")

	if ZoomIn then
		if Camera.FieldOfView >= ZOOM_OUT - 2 then
			UserInputService.MouseDeltaSensitivity = 0.15
			local RMBZoomIn = TweenService:Create(Camera, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {FieldOfView = ZOOM_IN})
			RMBZoomIn:Play()
		end
	else
		if Camera.FieldOfView >= ZOOM_IN + 2 then
			UserInputService.MouseDeltaSensitivity = 1
			local RMBZoomOut = TweenService:Create(Camera, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {FieldOfView = ZOOM_OUT})
			RMBZoomOut:Play()
		end
	end
end

return BowUIManager
