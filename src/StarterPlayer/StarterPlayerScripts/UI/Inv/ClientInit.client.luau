local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local InvokeInventoryAction : RemoteFunction = Remotes:WaitForChild("InvokeInventoryAction")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

local inventoryScreenGui = playerGui:WaitForChild("Inventory")
local inventoryFrame = inventoryScreenGui:WaitForChild("InventoryFrame")
local tabFrame = inventoryFrame:WaitForChild("Tabs")

local UIManager_AnimSlabsM = require(script.Parent.AnimationManager)
local TabManager = require(script.Parent.TabAnims)
local itemInputController = require(script.Parent.ItemInputController)
local secondaryInventoryM = require(script.Parent.SecondaryInv)
local inventoryAnimations = UIManager_AnimSlabsM:ApplyAnimationSlabs(inventoryFrame)

local headerFrames = {
	inventoryFrame:WaitForChild("Header_Items"),
	inventoryFrame:WaitForChild("Header_Quests"),
	inventoryFrame:WaitForChild("Header_Recipes")
}

local AnimatableTabObjects = {}
local tabNames = {"Items", "Quests", "Recipes"}
for _, v in pairs(tabNames) do
	AnimatableTabObjects[v] = UIManager_AnimSlabsM:ApplyAnimationSlabs(tabFrame:FindFirstChild(v))
	AnimatableTabObjects["Header_" .. v] = UIManager_AnimSlabsM:ApplyAnimationSlabs(inventoryFrame:FindFirstChild("Header_" .. v))
end

-- tabs
TabManager.Init(AnimatableTabObjects, headerFrames, tabFrame)

-- items
local tabItemsFrames = tabFrame:WaitForChild("Items")
local tabmainFrame = tabItemsFrames:WaitForChild("Frame"):WaitForChild("Main") :: Frame
local tabMenuFrame = tabItemsFrames:WaitForChild("Frame"):WaitForChild("Menu") :: Frame
local tabSeparatedMenuFrame = tabItemsFrames:WaitForChild("Frame"):WaitForChild("SeparatedMenu") :: Frame
local templateFrame = inventoryFrame.Parent:WaitForChild("template")
local dragFrame = inventoryScreenGui:WaitForChild("Drag")

--itemManagerM.init({tabmainFrame, tabMenuFrame, tabSeparatedMenuFrame}, inventoryFrame, templateFrame)
local inptControllerObj = itemInputController.new(inventoryFrame)
local clientinv = secondaryInventoryM.new(24)
clientinv:Init()

-- Hotbar Equip stuff
local hotbarKeys = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2, 
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
}

local paramsLocal = {
	debounce = false
}

InvokeInventoryAction.OnClientInvoke = function(functionName, ...)
	return inptControllerObj._inventory[functionName](inptControllerObj._inventory, ...)
end

player.CharacterRemoving:Connect(function(char)
	inptControllerObj:CleanUp()
	inptControllerObj = itemInputController.new(inventoryFrame)
	
	clientinv = secondaryInventoryM.new(24)
	clientinv:Init()
	inptControllerObj:Initialize()
end)

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent then return end
	if inventoryAnimations.debounce then return end
	if paramsLocal.debounce then return end
	paramsLocal.debounce = true

	if input.KeyCode == Enum.KeyCode.E then
		if inventoryFrame.Visible then
			-- false
			templateFrame.Visible = false
			dragFrame.Visible = false
			UIManager_AnimSlabsM.blurTween(false)
			inventoryAnimations:PlayAnimation(UIManager_AnimSlabsM.SlideDownAndFadeOutChildren, function()
				inventoryFrame.Visible = false
			end)
			
			inptControllerObj:CleanUp()
		else
			UIManager_AnimSlabsM.blurTween(true)
			inventoryFrame.Visible = true
			inventoryAnimations:PlayAnimation(UIManager_AnimSlabsM.SlideUpAndFadeInChildren)
			
			inptControllerObj:Initialize()
		end
		
	elseif input.KeyCode == Enum.KeyCode.Q then
		inptControllerObj:DropItem()
		
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
		inptControllerObj:ActivateCurrentTool()
		
	elseif hotbarKeys[input.KeyCode] then
		inptControllerObj:ActiveHotbarSlot(hotbarKeys[input.KeyCode])	
	end
	
	paramsLocal.debounce = false
end)

UserInputService.InputEnded:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent then return end
	
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		inptControllerObj:DeactivateCurrentTool()
	end
end)