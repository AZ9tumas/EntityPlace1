local Player = game.Players.LocalPlayer
local InvScripts = script.Parent
local InvManager = require(InvScripts.InvManager)

local InvGUI = Player.PlayerGui:WaitForChild("InventoryGui")
local InvFrame = InvGUI.Inventory
local Tabs = InvFrame.Tabs

local HeaderItems = InvFrame.Items
local HeaderQuests = InvFrame.Quests
local HeaderRecipes = InvFrame.Recipes

local ItemsTab = Tabs:FindFirstChild("Items").MainInventory

local PrimaryInventory = ItemsTab.Primary
local SecondaryInventory = ItemsTab.Secondary
local TertiaryInventory = ItemsTab.Tertiary

local Hotbar = InvGUI.Hotbar
local HotbarMainSlots = Hotbar.Main.Slots

local Variables = InvGUI.Variables
local CurrentHotbarSlot = Variables.CurrentHotbarSlot

local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local SlotKeybinds = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
	Enum.KeyCode.Eight,
}

local UIScale = Instance.new("UIScale")
UIScale.Scale = 0
UIScale.Name = "InventoryTweenScale"
UIScale.Parent = InvFrame

local UIAspect = Instance.new("UIAspectRatioConstraint")
UIAspect.AspectRatio = 1.6
UIAspect.DominantAxis = Enum.DominantAxis.Width
UIAspect.Parent = InvFrame

UserInputService.InputBegan:Connect(function(Input, GPE)
	if GPE then return end

	if Input.KeyCode == Enum.KeyCode.E then
		InvFrame.Visible = not InvFrame.Visible
		Hotbar.Visible = not Hotbar.Visible
		InvManager:SyncHotbarAndPrimaryInventory()

		if InvFrame.Visible then
			UIScale.Scale = 0
			local tween = TweenService:Create(UIScale, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
				Scale = 1
			})
			tween:Play()
		end
	end

	for i, Key in ipairs(SlotKeybinds) do
		if Input.KeyCode == Key and CurrentHotbarSlot.Value then
			InvManager:MoveOrSwapItem(CurrentHotbarSlot.Value, PrimaryInventory:FindFirstChild(tostring(i)))
		end
	end
end)

for _, Headers in ipairs(CollectionService:GetTagged("Header")) do
	if Headers:IsA("Frame") then
		for _, Buttons in ipairs(Headers:GetChildren()) do
			if Buttons:IsA("ImageButton") then
				Buttons.MouseButton1Click:Connect(function()
					if Buttons.Name ~= Headers.Name then
						InvManager:ChangeTab(Buttons)
						local pulseOut = TweenService:Create(UIScale, TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
							Scale = 0.97
						})
						local pulseIn = TweenService:Create(UIScale, TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
							Scale = 1
						})
						pulseOut:Play()
						pulseOut.Completed:Wait()
						pulseIn:Play()
					end
				end)
			end
		end
	end
end

for _, PrimarySlots in ipairs(PrimaryInventory:GetChildren()) do
	if PrimarySlots:IsA("ImageButton") then
		PrimarySlots.MouseEnter:Connect(function()
			CurrentHotbarSlot.Value = PrimarySlots
		end)
		PrimarySlots.MouseLeave:Connect(function()
			CurrentHotbarSlot.Value = nil
		end)
	end
end

for _, SecondarySlots in ipairs(SecondaryInventory:GetChildren()) do
	if SecondarySlots:IsA("ImageButton") then
		SecondarySlots.MouseEnter:Connect(function()
			CurrentHotbarSlot.Value = SecondarySlots
		end)
		SecondarySlots.MouseLeave:Connect(function()
			CurrentHotbarSlot.Value = nil
		end)
	end
end

InvManager:InitialiseSlots(SecondaryInventory, "Primary")
InvManager:InitialiseSlots(PrimaryInventory,   "Secondary")
