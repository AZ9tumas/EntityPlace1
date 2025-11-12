local rep = game:GetService("ReplicatedStorage")
local Player = game:GetService("Players").LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()

Player:GetMouse().Icon = "rbxassetid://68308747"
require(rep:FindFirstChild("Modules"):WaitForChild("SmoothShiftLock"))