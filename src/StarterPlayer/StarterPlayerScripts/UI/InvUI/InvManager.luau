local InvManager = {}

local Player = game.Players.LocalPlayer

local InvGUI = Player.PlayerGui:WaitForChild("Inventory")
local InvFrame = InvGUI.Inventory
local Tabs = InvFrame.Tabs

local HeaderItems = InvFrame.Header_Items
local HeaderQuests = InvFrame.Header_Quests
local HeaderRecipes = InvFrame.Header_Recipes

local ItemsTab = Tabs:FindFirstChild("Items")

local PrimaryInventory = ItemsTab.Primary
local SecondaryInventory = ItemsTab.Secondary
local TertiaryInventory = ItemsTab.Tertiary

local Hotbar = InvGUI.Hotbar
local HotbarMainSlots = Hotbar.Main.Slots

local Variables = InvGUI.Variables
local CurrentTab = Variables.CurrentTab
local CurrentHeader = Variables.CurrentHeader

local UserInputService = game:GetService("UserInputService")


function InvManager:InitialiseSlots(CurrentInventory: ImageLabel, InventoryType: string)
	for _, Previews in ipairs(CurrentInventory:GetDescendants()) do
		if Previews:IsA("ImageButton") and Previews:HasTag("Preview") then

			Previews.Activated:Connect(function()
				if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and Previews.Parent.Occupied.Value then
					InvManager:MoveItemBetweenInventories(Previews.Parent, InventoryType)
				end
			end)

		end
	end
end

function InvManager:FindUnoccupiedSlot(InventoryType: string): ImageButton
	
	local Inventory
	
	if InventoryType == "Primary" then
		Inventory = PrimaryInventory
	elseif InventoryType == "Secondary" then
		Inventory = SecondaryInventory
	elseif InventoryType == "Tertiary" then
		Inventory = TertiaryInventory
	end
	
	for _, Slots in ipairs(Inventory:GetChildren()) do
		if Slots:HasTag("Slot") then
			local OccupiedBool = Slots:FindFirstChild("Occupied")
			if OccupiedBool.Value then
				continue
			else
				print(Slots.Name)
				return Slots
			end
		end
	end

	return nil
end

function InvManager:ChangeTab(Button: Frame)

	if CurrentTab.Value and CurrentHeader.Value then
		CurrentTab.Value.Visible = false
		CurrentHeader.Value.Visible = false
	else
		for _, Tabs in ipairs(Tabs:GetChildren()) do
			if Tabs:IsA("Frame") then
				Tabs.Visible  = false
			end
		end

		for _, Headers in ipairs(InvFrame:GetChildren()) do
			if Headers:IsA("Frame") and Headers:HasTag("Header") then
				Headers.Visible  = false
			end
		end
	end

	CurrentTab.Value = Tabs:FindFirstChild(Button.Name)
	CurrentHeader.Value = InvFrame:FindFirstChild(Button.Name)

	CurrentTab.Value.Visible = true
	CurrentHeader.Value.Visible = true

end

function InvManager:MoveOrSwapItem(CurrentSlot: ImageButton, NewSlot: ImageButton)
	
	local CurrentPreview: ImageButton = CurrentSlot:FindFirstChild("Preview")
	local NewPreview: ImageButton = NewSlot:FindFirstChild("Preview")
	
	if CurrentPreview ~= NewPreview then
		local CurrentItem = CurrentPreview.Image
		local NewItem = NewPreview.Image
		
		CurrentPreview.Image = NewItem
		NewPreview.Image = CurrentItem
		
		NewSlot.Occupied.Value = true
		CurrentSlot.Occupied.Value = false
	end
	
end

function InvManager:SyncHotbarAndPrimaryInventory()
	
	for _, PrimarySlots in ipairs(PrimaryInventory:GetDescendants()) do
		if PrimarySlots:IsA("ImageButton") then
			if PrimarySlots:HasTag("Preview") then
				local HotbarPreview = HotbarMainSlots:FindFirstChild(PrimarySlots.Parent.Name):FindFirstChild("Preview")
				
				HotbarPreview.Image = PrimarySlots.Image
			end
		end
	end
	
end

function InvManager:MoveItemBetweenInventories(CurrentSlot: ImageButton, InventoryType: string)
	local NewSlot = InvManager:FindUnoccupiedSlot(InventoryType)
	
	if CurrentSlot and NewSlot then
		InvManager:MoveOrSwapItem(CurrentSlot, NewSlot)
	end
end

return InvManager