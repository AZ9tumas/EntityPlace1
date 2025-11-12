-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Folders / Assets
local Assets = ReplicatedStorage.Assets
local Animations = Assets.Animations.BowSystem
local FPVAnimations = Animations.FPVAnimations

-- Animations // FPV
local ChargeFPVAnimation = FPVAnimations.Charge
local HoldFPVAnimation = FPVAnimations.Hold
local ShootFPVAnimation = FPVAnimations.Shoot

-- Module
local BowManager = {}
local DRAW_TIME_MIN = 0.5
local ActiveChargeTrack: AnimationTrack? = nil

local function ReturnPlayerVariables(Player: Player)
	local Character = Player.Character or Player.CharacterAdded:Wait()
	local Humanoid = Character:WaitForChild("Humanoid")
	local Animator = Humanoid:WaitForChild("Animator")
	local BowAnimator = Character:WaitForChild("BowAnimator")
	return Character, Humanoid, Animator, BowAnimator
end

local function StopAnimationsByName(Animator: Animator, AnimationNames: {string})
	for _, Track in ipairs(Animator:GetPlayingAnimationTracks()) do
		for _, Name in ipairs(AnimationNames) do
			if Track.Name == Name then
				Track:Stop()
				print("Stopped animation:", Name)
			end
		end
	end
end

function BowManager:ChargeAndHoldBowFPV(Player: Player)
	print("ChargeAndHoldFPV")
	local Character, Humanoid, Animator, BowAnimator = ReturnPlayerVariables(Player)

	-- Stop server-side charge + hold
	StopAnimationsByName(Animator, {"Charge", "Hold"})
	StopAnimationsByName(BowAnimator, {"Charge", "Hold"})

	-- Play FPV charge
	ActiveChargeTrack = Animator:LoadAnimation(ChargeFPVAnimation)
	ActiveChargeTrack:Play()

	-- Transition into hold after charge ends
	task.delay(ActiveChargeTrack.Length, function()
		if ActiveChargeTrack and ActiveChargeTrack.IsPlaying then
			ActiveChargeTrack:Stop()
			ActiveChargeTrack = nil

			local HoldAnimTrack: AnimationTrack = Animator:LoadAnimation(HoldFPVAnimation)
			HoldAnimTrack:Play()
		end
	end)
end

function BowManager:StopChargeFPV(Player: Player)
	if ActiveChargeTrack and ActiveChargeTrack.IsPlaying then
		ActiveChargeTrack:Stop()
		print("Stopped FPV charge animation")
		ActiveChargeTrack = nil
	end
end

function BowManager:StopHoldFPV(Player: Player)
	local Character, Humanoid, Animator, BowAnimator = ReturnPlayerVariables(Player)

	StopAnimationsByName(Animator, {"Hold"})
	StopAnimationsByName(BowAnimator, {"Hold"})
end

function BowManager:ShootBowFPV(Player: Player, MousePosition: Vector3, TimeElapsed: number)
	print("ShootFPV")
	local Character, Humanoid, Animator, BowAnimator = ReturnPlayerVariables(Player)

	-- Stop charge + hold before shooting
	self:StopChargeFPV(Player)
	self:StopHoldFPV(Player)
	StopAnimationsByName(Animator, {"Shoot"})
	StopAnimationsByName(BowAnimator, {"Shoot"})

	-- Only shoot if bow was drawn long enough
	if TimeElapsed > DRAW_TIME_MIN then
		local ShootAnimTrack: AnimationTrack = Animator:LoadAnimation(ShootFPVAnimation)
		ShootAnimTrack:Play()
	end
end

return BowManager
