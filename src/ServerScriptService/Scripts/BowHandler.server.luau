local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage.Modules
local BowManager = require(Modules.BowManager)

local Events = ReplicatedStorage.Remotes
local BowEvent = Events.BowEvent
local DisableShooting = Events.DisableBowShooting

local Settings = ReplicatedStorage.Settings
local BowSettings = Settings.Bow

local DrawTime = BowSettings.DrawTime
local MinDrawTime = DrawTime.MinDrawTime

local DRAW_TIME_MIN = MinDrawTime.Value

BowEvent.OnServerEvent:Connect(function(Player: Player, Function: string, MousePosition: Vector3, TimeHeld: number)
	
	if Function == "Equipped" then
		
		BowManager:OnEquip(Player)
		
	elseif Function == "Activated" then
		
		BowManager:ChargeAndHoldBow(Player)
		
	elseif Function == "ActivatedFPV" then
		
		BowManager:ChargeBowFPV(Player)
		
	elseif Function == "DeactivatedFPV" then

		BowManager:ShootBowFPV(Player, MousePosition, TimeHeld)
		
	elseif Function == "Deactivated" then
		
		--if TimeHeld > DRAW_TIME_MIN then
			BowManager:ShootBow(Player, MousePosition, TimeHeld)
		--end
		
	elseif Function == "Unequipped" then
		
		BowManager:OnUnequip(Player)
		
	end
	
end)

DisableShooting.OnServerEvent:Connect(function(Player: Player)
	local Character = Player.Character or Player.CharacterAdded:Wait()
	
	local PlayerVariables = Character:FindFirstChild("Variables")
	local CanShoot = PlayerVariables:FindFirstChild("CanShoot")
	
	CanShoot.Value = not CanShoot.Value
end)


