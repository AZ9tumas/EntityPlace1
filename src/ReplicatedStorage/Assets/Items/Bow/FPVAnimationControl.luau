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
	--local BowAnimator = Character:WaitForChild("BowAnimator")
	return Character, Humanoid, Animator
end

function BowManager:ChargeAndHoldBow(Player: Player)
	print("Charge")
	local Character, Humanoid, Animator  = ReturnPlayerVariables(Player)

	local PlayerVariables: Folder = Character:FindFirstChild("Variables")
	local CanShoot = PlayerVariables:FindFirstChild("CanShoot")

	if not CanShoot.Value then
		return
	end

	local HasShot = PlayerVariables:FindFirstChild("HasShot")
	if not HasShot then
		HasShot = Instance.new("BoolValue")
		HasShot.Name = "HasShot"
		HasShot.Value = false
		HasShot.Parent = PlayerVariables
	else
		HasShot.Value = false
	end

	local ChargeAnimTrackPlayer: AnimationTrack = Animator:LoadAnimation(ChargeFPVAnimation)
	--local ChargeAnimTrackBow: AnimationTrack = BowAnimator:LoadAnimation(ChargeAnimation)

	local PlayerArrow: MeshPart = Character.Arrow["Cylinder.001"]
	PlayerArrow.Transparency = 0

	ChargeAnimTrackPlayer:Play()
	--ChargeAnimTrackBow:Play()

	self.ActiveChargeTracks = {ChargeAnimTrackPlayer}

	--wait(ChargeAnimTrackPlayer.Length)

	ChargeAnimTrackPlayer.Ended:Connect(function()
		if HasShot.Value then return end

		print("Hold")
		local HoldAnimTrackPlayer: AnimationTrack = Animator:LoadAnimation(HoldFPVAnimation)
		--local HoldAnimTrackBow: AnimationTrack = BowAnimator:LoadAnimation(HoldAnimation)

		HoldAnimTrackPlayer:Play()
		--HoldAnimTrackBow:Play()

		self.ActiveHoldTracks = {HoldAnimTrackPlayer}

		wait()

		self:StopChargeAnimation()
	end)
	
end

function BowManager:StopChargeAnimation()
	if self.ActiveChargeTracks then
		for _, Track in ipairs(self.ActiveChargeTracks) do
			if Track.IsPlaying then
				Track:Stop()
			end
		end
		self.ActiveChargeTracks = nil
	end
end

function BowManager:StopHoldAnimation(Player: Player)
	local Character, Humanoid, Animator  = ReturnPlayerVariables(Player)

	for _, PlayerAnimations: AnimationTrack in ipairs(Animator:GetPlayingAnimationTracks()) do
		if PlayerAnimations.Name == "Hold" or PlayerAnimations.Name == "HoldFPV" then
			PlayerAnimations:Stop()
			print("Stopped hold", PlayerAnimations.Name)
		end
	end

	if self.ActiveHoldTracks then
		for _, Track in ipairs(self.ActiveHoldTracks) do
			if Track.IsPlaying then
				Track:Stop()
			end
		end
		self.ActiveHoldTracks = nil
	end
end

function BowManager:ShootBow(Player: Player, MousePosition: Vector3, TimeElapsed: never)
	print("Shoot")
	local Character, Humanoid, Animator  = ReturnPlayerVariables(Player)

	local ShootAnimTrackPlayer: AnimationTrack = Animator:LoadAnimation(ShootFPVAnimation)
	--local ShootAnimTrackBow: AnimationTrack = BowAnimator:LoadAnimation(BowShootAnimation)

	local PlayerVariables: Folder = Character:FindFirstChild("Variables")
	local HasShot = PlayerVariables:FindFirstChild("HasShot")

	if HasShot then
		HasShot.Value = true
	end

	wait()

	self:StopHoldAnimation(Player)
	self:StopChargeAnimation()

	if TimeElapsed > DRAW_TIME_MIN then
		ShootAnimTrackPlayer:Play()
		--ShootAnimTrackBow:Play()

		--ShootAnimTrackPlayer:GetMarkerReachedSignal("Shoot"):Connect(function()
		--	self:ShootArrow(Player, MousePosition, TimeElapsed)
		--end)
	end
end


return BowManager
