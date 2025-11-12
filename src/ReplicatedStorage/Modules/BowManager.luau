local BowManager = {}

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local DebrisService = game:GetService("Debris")
local workspace = workspace

-- Folders / Assets
local Assets = ReplicatedStorage:WaitForChild("Assets")
local VFX = Assets:WaitForChild("VFX").Bow
local Weapons = Assets:WaitForChild("Weapons")

local Animations = Assets:WaitForChild("Animations").BowSystem
local PlayerAnimations = Animations.PlayerAnimations
local BowAnimations = Animations.BowAnimations
local FPVAnimations = Animations.FPVAnimations

local ItemsSFX = SoundService:WaitForChild("ItemsSFX")
local BowSounds = ItemsSFX:WaitForChild("Bow")

local Settings = ReplicatedStorage:WaitForChild("Settings")
local BowSettings = Settings:WaitForChild("Bow")

-- Animations // Player
local PlayerChargeAnimation = PlayerAnimations:WaitForChild("Charge")
local PlayerHoldAnimation = PlayerAnimations:WaitForChild("Hold")
local PlayerShootAnimation = PlayerAnimations:WaitForChild("Shoot")

-- Animations // Bow 
local BowChargeAnimation = BowAnimations:WaitForChild("Charge")
local BowHoldAnimation = BowAnimations:WaitForChild("Hold")
local BowShootAnimation = BowAnimations:WaitForChild("Shoot")

-- Animations // FPV (kept if present)
local ChargeFPVAnimation = FPVAnimations:FindFirstChild("Charge")
local HoldFPVAnimation = FPVAnimations:FindFirstChild("Hold")
local ShootFPVAnimation = FPVAnimations:FindFirstChild("Shoot")

-- Sounds // Bow
local BowChargeSFX = BowSounds:WaitForChild("Stretch")
local ModeChangeSFX = BowSounds:FindFirstChild("ModeChange")
local BowShootSFX = BowSounds:WaitForChild("Fire")

-- Sounds // Arrow
local ArrowHitSFX = BowSounds:WaitForChild("Hit")

-- Bow System
local BowSystem = Weapons:WaitForChild("BowSystem")
local Models = BowSystem:WaitForChild("Models")
local Joints = BowSystem:WaitForChild("Joints")

-- Modules
local FastCastRedux = require(ReplicatedStorage.Modules:WaitForChild("FastCastRedux"))
local PartCache = require(ReplicatedStorage.Modules:WaitForChild("PartCache"))

local ArrowsFolder: Folder = workspace:FindFirstChild("ArrowFolder") or Instance.new("Folder", workspace)
ArrowsFolder.Name = "ArrowFolder"

local ArrowTemplate = VFX:WaitForChild("Arrow")
local ArrowCache = PartCache.new(ArrowTemplate, 300, ArrowsFolder)

-- Settings // Directories
local AccuracySpread = BowSettings:WaitForChild("AccuracySpread")
local MinAccuracySpread = AccuracySpread:WaitForChild("MinAccuracySpread")
local MaxAccuracySpread = AccuracySpread:WaitForChild("MaxAccuracySpread")

local DrawTime = BowSettings:WaitForChild("DrawTime")
local MinDrawTime = DrawTime:WaitForChild("MinDrawTime")
local MaxDrawTime = DrawTime:WaitForChild("MaxDrawTime")

local Damage = BowSettings:WaitForChild("Damage")
local MinDamage = Damage:WaitForChild("MinDamage")
local MaxDamage = Damage:WaitForChild("MaxDamage")

local ArrowVelocity = BowSettings:WaitForChild("ArrowVelocity")
local MinArrowVelocity = ArrowVelocity:WaitForChild("MinArrowVelocity")
local MaxArrowVelocity = ArrowVelocity:WaitForChild("MaxArrowVelocity")

local ArcDrop = BowSettings:WaitForChild("ArcDrop")
local ArcDropMultiplier = ArcDrop:WaitForChild("ArcDropMultiplier")

local DistanceDrawColors = BowSettings:FindFirstChild("DistanceDrawColors")

-- Settings // Constants
local ACCURACY_SPREAD_MIN = MinAccuracySpread.Value
local ACCURACY_SPREAD_MAX = MaxAccuracySpread.Value

local DRAW_TIME_MIN = MinDrawTime.Value
local DRAW_TIME_MAX = MaxDrawTime.Value

local DAMAGE_MIN = MinDamage.Value
local DAMAGE_MAX = MaxDamage.Value
local DAMAGE_CURVE_EXPONENT = 2

local ARROW_VELOCITY_MIN = MinArrowVelocity.Value
local ARROW_VELOCITY_MAX = MaxArrowVelocity.Value

local ARC_DROP_MULTIPLIER = ArcDropMultiplier.Value

-- Per-player state to avoid cross-player races
BowManager._playerState = {} -- map player -> {Equipped = bool, ActiveChargeTracks = {...}, ActiveHoldTracks = {...}, ActiveSound = sound}

local function ensureState(Player)
	if not BowManager._playerState[Player] then
		BowManager._playerState[Player] = {}
	end
	return BowManager._playerState[Player]
end

-- Corrected ReturnPlayerVariables: fixed Animator creation bug and BowAnimator creation
local function ReturnPlayerVariables(Player: Player): (Model, Humanoid, Animator, Animator)
	if Player then
		local Character: Model = Player.Character or Player.CharacterAdded:Wait()
		local Humanoid: Humanoid = Character:WaitForChild("Humanoid")

		local PlayerBow: Model = BowManager:HasPlayerABow(Player)
		if not PlayerBow then return false end

		-- ensure character animator
		local Animator: Animator = Humanoid:FindFirstChildWhichIsA("Animator")
		if not Animator then
			local AnimatorN = Instance.new("Animator")
			AnimatorN.Parent = Humanoid
			Animator = AnimatorN
		end

		-- ensure bow animator under its AnimationController (if present)
		local BowAnimationController = PlayerBow:WaitForChild("AnimationController")
		local BowAnimator: AnimationController = PlayerBow:FindFirstChildWhichIsA("Animator")
		if not BowAnimator then
			local newBA = Instance.new("Animator")
			newBA.Parent = BowAnimationController
			BowAnimator = newBA
		end

		return Character, Humanoid, Animator, BowAnimator
	end
end

function BowManager:HasPlayerABow(Player: Player): Model
	if not Player then return false end
	local Character = Player.Character or Player.CharacterAdded:Wait()
	if not Character then return false end

	for _, Child in ipairs(Character:GetChildren()) do
		if not Child:IsA("Tool") and Child.Name == "Bow" then
			return Child
		end
	end

	return false
end

function BowManager:HasArrowHit(Arrow: BasePart)
	if not (Arrow and Arrow:FindFirstChild("Variables")) then return false end
	local ArrowVariables: Folder = Arrow:FindFirstChild("Variables")
	local HasHit: BoolValue = ArrowVariables:FindFirstChild("HasHit")
	return HasHit and HasHit.Value
end

function BowManager:OnEquip(Player: Player)
	if not Player then return end
	if BowManager:HasPlayerABow(Player) then return end

	local Character = Player.Character or Player.CharacterAdded:Wait()
	if not Character then return end

	local ArrowJointPart0 = Character:FindFirstChild(Joints.Arrow.PartName.Value)
	local BowJointPart0 = Character:FindFirstChild(Joints.Bow.PartName.Value)

	if not ArrowJointPart0 or not BowJointPart0 then
		warn("Missing Part0s for arrow or bow")
		return
	end

	local NewBow = Models.Bow:Clone()
	local NewArrow = Models.Arrow:Clone()

	NewBow.Parent = Character
	NewArrow.Parent = Character

	local ArrowJointTemplate = Joints.Arrow:FindFirstChildWhichIsA("Motor6D")
	local BowJointTemplate = Joints.Bow:FindFirstChildWhichIsA("Motor6D")
	if not ArrowJointTemplate or not BowJointTemplate then
		warn("Missing Motor6D templates for joints")
		return
	end

	local ArrowJointName: string = ArrowJointTemplate.Name
	local BowJointName: string = BowJointTemplate.Name

	local ArrowJointPart1: BasePart = NewArrow:FindFirstChild(ArrowJointName)
	local BowJointPart1: BasePart = NewBow:FindFirstChild(BowJointName)

	if not ArrowJointPart1 or not BowJointPart1 then
		warn("Missing Part1s in arrow or bow models")
		return
	end

	local ArrowJoint: Motor6D = ArrowJointTemplate:Clone()
	local BowJoint: Motor6D = BowJointTemplate:Clone()

	ArrowJoint.Part0 = ArrowJointPart0
	ArrowJoint.Part1 = ArrowJointPart1
	ArrowJoint.Parent = ArrowJointPart0

	BowJoint.Part0 = BowJointPart0
	BowJoint.Part1 = BowJointPart1
	BowJoint.Parent = BowJointPart0

	local state = ensureState(Player)
	state.Equipped = true
end

function BowManager:_stopAllPlayerAnimationsAndSounds(Player)
	-- helper to stop charge/hold/shoot animations and sounds for a specific player
	if not Player then return end
	local state = ensureState(Player)

	-- stop charge tracks
	if state.ActiveChargeTracks then
		for _, Track in ipairs(state.ActiveChargeTracks) do
			if Track and Track.IsPlaying then
				Track:Stop()
			end
		end
		state.ActiveChargeTracks = nil
	end

	-- stop hold tracks
	if state.ActiveHoldTracks then
		for _, Track in ipairs(state.ActiveHoldTracks) do
			if Track and Track.IsPlaying then
				Track:Stop()
			end
		end
		state.ActiveHoldTracks = nil
	end

	-- stop any shoot animation playing on the humanoid (defensive)
	local Character = Player.Character
	if Character then
		local Humanoid = Character:FindFirstChildWhichIsA("Humanoid")
		if Humanoid then
			for _, anim in ipairs(Humanoid:GetPlayingAnimationTracks()) do
				-- stop any known animation names that can get stuck
				if anim.Name == "Shoot" or anim.Name == "Hold" or anim.Name == "HoldFPV" or anim.Name == "Charge" then
					if anim.IsPlaying then
						anim:Stop()
					end
				end
			end
		end
	end

	-- stop sound
	if state.ActiveSound then
		pcall(function()
			if state.ActiveSound.IsPlaying then
				state.ActiveSound:Stop()
			end
			if state.ActiveSound.Parent then
				state.ActiveSound:Destroy()
			end
		end)
		state.ActiveSound = nil
	end
end

function BowManager:OnUnequip(Player: Player)
	if not Player then return end
	local Character = Player.Character or Player.CharacterAdded:Wait()
	if not Character then return end

	-- Remove arrow model if present
	local Arrow: Model = Character:FindFirstChild("Arrow")
	if Arrow then
		Arrow:Destroy()
	end

	-- Remove Motor6Ds safely
	local ArrowJointTemplate = Joints.Arrow:FindFirstChildWhichIsA("Motor6D")
	local BowJointTemplate = Joints.Bow:FindFirstChildWhichIsA("Motor6D")
	local ArrowJointName = ArrowJointTemplate and ArrowJointTemplate.Name
	local BowJointName = BowJointTemplate and BowJointTemplate.Name

	local ArrowJointPart0 = Character:FindFirstChild(Joints.Arrow.PartName.Value)
	local BowJointPart0 = Character:FindFirstChild(Joints.Bow.PartName.Value)

	if ArrowJointName and ArrowJointPart0 then
		local ArrowJoint: Motor6D = ArrowJointPart0:FindFirstChild(ArrowJointName)
		if ArrowJoint then
			ArrowJoint:Destroy()
		end
	end

	if BowJointName and BowJointPart0 then
		local BowJoint: Motor6D = BowJointPart0:FindFirstChild(BowJointName)
		if BowJoint then
			BowJoint:Destroy()
		end
	end

	-- short wait to avoid racing with animations/markers
	wait()

	-- cleanup per-player animations/sounds
	self:_stopAllPlayerAnimationsAndSounds(Player)

	-- destroy bow model if present
	local Bow: Model = BowManager:HasPlayerABow(Player)
	if Bow then
		Bow:Destroy()
	end

	-- Mark as unequipped
	local state = ensureState(Player)
	state.Equipped = false
end

function BowManager:ChargeAndHoldBow(Player: Player)
	local Character, Humanoid, Animator, BowAnimator = ReturnPlayerVariables(Player)
	if not (Character and Humanoid and Animator and BowAnimator) then return end

	local PlayerVariables: Folder = Character:FindFirstChild("Variables")
	if not PlayerVariables then return end
	local CanShoot = PlayerVariables:FindFirstChild("CanShoot")
	if not (CanShoot and CanShoot.Value) then
		return
	end

	-- slow walk while drawing
	Humanoid.WalkSpeed = 4

	-- ensure HasShot exists
	local HasShot = PlayerVariables:FindFirstChild("HasShot")
	if not HasShot then
		HasShot = Instance.new("BoolValue")
		HasShot.Name = "HasShot"
		HasShot.Value = false
		HasShot.Parent = PlayerVariables
	else
		HasShot.Value = false
	end

	-- defensive: ensure arrow exists
	local PlayerArrow = Character:FindFirstChild("Arrow") and Character.Arrow:FindFirstChild("Cylinder.001")
	if PlayerArrow then
		PlayerArrow.Transparency = 0
	end

	-- play charge animations
	local ChargeAnimTrackPlayer: AnimationTrack = Animator:LoadAnimation(PlayerChargeAnimation)
	local ChargeAnimTrackBow: AnimationTrack = BowAnimator:LoadAnimation(BowChargeAnimation)

	local Sound = BowChargeSFX:Clone()
	Sound.Parent = Character
	Sound:Play()

	local Connection
	Connection  = Sound.Ended:Connect(function()
		pcall(function() Sound:Destroy() end)
		if Connection then Connection:Disconnect() end
		Connection = nil
	end)

	ChargeAnimTrackPlayer:Play()
	ChargeAnimTrackBow:Play()

	local state = ensureState(Player)
	state.ActiveChargeTracks = {ChargeAnimTrackPlayer, ChargeAnimTrackBow}
	state.ActiveSound = Sound
	state.Equipped = true

	local function HoldToCharge()
		-- If unequipped during charge, restore speed and bail
		local st = ensureState(Player)
		if not st.Equipped then
			if Humanoid and Humanoid.Parent then
				Humanoid.WalkSpeed = 16
			end
			return
		end
		if HasShot.Value then return end

		-- Play hold animations
		local HoldAnimTrackPlayer: AnimationTrack = Animator:LoadAnimation(PlayerHoldAnimation)
		local HoldAnimTrackBow: AnimationTrack = BowAnimator:LoadAnimation(BowHoldAnimation)

		HoldAnimTrackPlayer:Play()
		HoldAnimTrackBow:Play()

		state.ActiveHoldTracks = {HoldAnimTrackPlayer, HoldAnimTrackBow}

		-- stop charge tracks (we're now holding)
		if state.ActiveChargeTracks then
			for _, t in ipairs(state.ActiveChargeTracks) do
				if t and t.IsPlaying then
					t:Stop()
				end
			end
			state.ActiveChargeTracks = nil
		end
	end

	-- transition to hold when charge finishes
	ChargeAnimTrackPlayer.Ended:Connect(function()
		HoldToCharge()
	end)

	-- fallback in case the Ended event doesn't fire as expected
	task.delay(math.max(0, ChargeAnimTrackPlayer.Length - 0.05), function()
		if ChargeAnimTrackPlayer and not ChargeAnimTrackPlayer.IsPlaying then
			HoldToCharge()
		end
	end)
end

function BowManager:StopChargeAnimation(Player: Player)
	-- Stop charge animation for a single player (if no player provided, do nothing)
	if not Player then return end
	local state = ensureState(Player)
	if state.ActiveChargeTracks then
		for _, Track in ipairs(state.ActiveChargeTracks) do
			if Track and Track.IsPlaying then
				Track:Stop()
			end
		end
		state.ActiveChargeTracks = nil
	end
	if state.ActiveSound then 
		pcall(function() 
			if state.ActiveSound.IsPlaying then state.ActiveSound:Stop() end
			if state.ActiveSound.Parent then state.ActiveSound:Destroy() end
		end)
		state.ActiveSound = nil
	end
end

function BowManager:StopHoldAnimation(Player: Player)
	local Character, Humanoid, Animator, BowAnimator = ReturnPlayerVariables(Player)
	if not (Character and Humanoid and Animator and BowAnimator) then return end

	-- Stop any hold animations on the humanoid animator
	for _, PlayerAnimations: AnimationTrack in ipairs(Animator:GetPlayingAnimationTracks()) do
		if PlayerAnimations.Name == "Hold" or PlayerAnimations.Name == "HoldFPV" then
			PlayerAnimations:Stop()
		end
	end

	-- Stop hold tracks from state
	local state = ensureState(Player)
	if state.ActiveHoldTracks then
		for _, Track in ipairs(state.ActiveHoldTracks) do
			if Track and Track.IsPlaying then
				Track:Stop()
			end
		end
		state.ActiveHoldTracks = nil
	end
end

function BowManager:ShootBow(Player: Player, MousePosition: Vector3, TimeElapsed: number)
	print("Shoot")
	local Character, Humanoid, Animator, BowAnimator = ReturnPlayerVariables(Player)
	if not (Character and Humanoid and Animator and BowAnimator) then return end

	local ShootAnimTrackPlayer: AnimationTrack = Animator:LoadAnimation(PlayerShootAnimation)
	local ShootAnimTrackBow: AnimationTrack = BowAnimator:LoadAnimation(BowShootAnimation)

	local PlayerVariables: Folder = Character:FindFirstChild("Variables")
	local HasShot = PlayerVariables and PlayerVariables:FindFirstChild("HasShot")

	if HasShot then
		HasShot.Value = true
	end

	-- restore speed
	if Character and Character:FindFirstChild("Humanoid") then
		Character.Humanoid.WalkSpeed = 16
	end

	wait()

	-- stop hold & charge for this player
	self:StopHoldAnimation(Player)
	self:StopChargeAnimation(Player)

	if TimeElapsed and TimeElapsed > DRAW_TIME_MIN then
		local Sound = BowShootSFX:Clone()
		Sound.Parent = Character
		Sound:Play()

		local Connection
		Connection  = Sound.Ended:Connect(function()
			pcall(function() Sound:Destroy() end)
			if Connection then Connection:Disconnect() end
			Connection = nil
		end)

		ShootAnimTrackPlayer:Play()
		ShootAnimTrackBow:Play()

		-- When marker reached, spawn the arrow
		ShootAnimTrackPlayer:GetMarkerReachedSignal("Shoot"):Connect(function()
			-- ensure still equipped
			local state = ensureState(Player)
			if state.Equipped then
				self:ShootArrow(Player, MousePosition, TimeElapsed)
			end
		end)
	end
end

function BowManager:ShootArrow(Player: Player, MousePosition: Vector3, TimeElapsed: never)
	local Character: Model = Player.Character
	if not Character or not Character:FindFirstChild("Arrow") then return end
	local PlayerArrow: MeshPart = Character.Arrow and Character.Arrow:FindFirstChild("Cylinder.001")
	if PlayerArrow then
		PlayerArrow.Transparency = 1
	end

	local Caster = FastCastRedux.new()
	local CastParams = RaycastParams.new()
	CastParams.FilterType = Enum.RaycastFilterType.Exclude
	CastParams.IgnoreWater = true

	local CastBehavior = FastCastRedux.newBehavior()
	CastBehavior.RaycastParams = CastParams
	CastBehavior.Acceleration = Vector3.new(0, - workspace.Gravity * 1 / ARC_DROP_MULTIPLIER, 0)
	CastBehavior.AutoIgnoreContainer = false

	CastBehavior.CosmeticBulletContainer = ArrowsFolder
	CastBehavior.CosmeticBulletProvider = ArrowCache

	CastParams.FilterDescendantsInstances = {Character, ArrowsFolder}

	local function OnLengthChanged(Cast, LastPoint, Direction, Length, Velocity, Arrow)
		if Arrow then 
			BowManager:AssignArrow(Player, Arrow)
			local ArrowLength = Arrow.Size.Z / 2
			local Offset = CFrame.new(0, 0, -(Length - ArrowLength))
			Arrow.CFrame = CFrame.lookAt(LastPoint, LastPoint + Direction):ToWorldSpace(Offset)
		end
	end

	local function OnRayHit(Cast, Result, Velocity, Arrow)
		local HitPart: Instance = Result and Result.Instance
		BowManager:OnArrowTouched(Arrow, HitPart, Velocity)

		task.delay(2, function()
			if Arrow and Arrow.Parent then
				local arrowReal = Arrow:FindFirstChild("ArrowReal")
				if arrowReal then
					local Trail = arrowReal:FindFirstChild("Trail")
					--Trail.Enabled = false
				end
				ArrowCache:ReturnPart(Arrow)
			end
		end)
	end

	local function CalculateVelocity(TimeElapsedsSinceBow): number
		if TimeElapsedsSinceBow > DRAW_TIME_MAX then
			TimeElapsedsSinceBow = DRAW_TIME_MAX
		end

		return TimeElapsedsSinceBow * 200
	end

	-- connect BEFORE firing to avoid race
	Caster.LengthChanged:Connect(OnLengthChanged)
	Caster.RayHit:Connect(OnRayHit)

	local function DetermineTargetPosition(TargetPosition)
		local SpreadX = math.random(-ACCURACY_SPREAD_MIN * 10, ACCURACY_SPREAD_MAX * 10)/10
		local SpreadY = math.random(-ACCURACY_SPREAD_MIN * 10, ACCURACY_SPREAD_MAX * 10)/10
		local SpreadZ = math.random(-ACCURACY_SPREAD_MIN * 10, ACCURACY_SPREAD_MAX * 10)/10

		local Offset = Vector3.new(SpreadX, SpreadY, SpreadZ)
		local AdjustedPosition = TargetPosition --+ Offset

		return AdjustedPosition
	end

	local origin = PlayerArrow and PlayerArrow.Position or (Character.PrimaryPart and Character.PrimaryPart.Position) or Vector3.new()
	local target = DetermineTargetPosition(MousePosition or origin)
	local direction = (target - origin).Unit

	Caster:Fire(origin, direction, CalculateVelocity(TimeElapsed), CastBehavior)
end

function BowManager:AssignArrow(Player: Player, Arrow: BasePart)
	if not (Arrow and Arrow:FindFirstChild("Variables")) then return end
	local ArrowVariables: Folder = Arrow:FindFirstChild("Variables")
	local PlayerWhoShot: ObjectValue = ArrowVariables:FindFirstChild("PlayerWhoShot")

	if PlayerWhoShot and not PlayerWhoShot.Value then
		PlayerWhoShot.Value = Player
	end
end

function BowManager:OnArrowTouched(Arrow: BasePart, HitPart: BasePart, Velocity: number)	
	if not (Arrow and Arrow:FindFirstChild("Variables")) then return end
	local ArrowVariables: Folder = Arrow:FindFirstChild("Variables")
	local HasHit: BoolValue = ArrowVariables:FindFirstChild("HasHit")
	if not HasHit or HasHit.Value then return end

	HasHit.Value = true

	local Trail: Trail = Arrow:FindFirstChild("ArrowReal") and Arrow.ArrowReal:FindFirstChild("Trail")

	local ArrowCentralAttachment: Attachment = Arrow:FindFirstChild("CentralAttachment")
	local AlignPosition: AlignPosition = ArrowCentralAttachment and ArrowCentralAttachment:FindFirstChild("AlignPosition")
	local AlignOrientation: AlignOrientation = ArrowCentralAttachment and ArrowCentralAttachment:FindFirstChild("AlignOrientation")

	local CharacterOther: Model = HitPart and HitPart:FindFirstAncestorWhichIsA("Model")
	local Sound

	if CharacterOther and CharacterOther:FindFirstChildWhichIsA("Humanoid") then
		local Humanoid: Humanoid = CharacterOther:FindFirstChildWhichIsA("Humanoid")

		local function CalculateDamage(Velocity: Vector3): number
			local Speed = Velocity and Velocity.Magnitude or 0
			local SpeedRatio = math.clamp(Speed / ARROW_VELOCITY_MAX, 0, 1)

			local ScaledRatio = SpeedRatio ^ DAMAGE_CURVE_EXPONENT
			local Damage = DAMAGE_MIN + (DAMAGE_MAX - DAMAGE_MIN) * ScaledRatio

			return Damage
		end

		pcall(function()
			Humanoid:TakeDamage(CalculateDamage(Velocity))
		end)
	end

	Sound = ArrowHitSFX:Clone()
	Sound.Parent = Arrow
	Sound:Play()

	local Connection
	Connection  = Sound.Ended:Connect(function()
		pcall(function() Sound:Destroy() end)
		if Connection then Connection:Disconnect() end
		Connection = nil
	end)

	if AlignPosition and AlignOrientation then
		AlignPosition.Position = Arrow.Position
		AlignOrientation.CFrame = Arrow.CFrame

		AlignOrientation.Enabled = true
		AlignPosition.Enabled = true

		task.wait(0.1)

		Arrow.Anchored = true
	end
end

return BowManager
