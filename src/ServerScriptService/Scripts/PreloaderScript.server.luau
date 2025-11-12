local CP = game:GetService("ContentProvider")
local Animations = game.ReplicatedStorage.Assets:WaitForChild("Animations")

warn("Preloading Animations...")
CP:PreloadAsync(Animations:GetChildren())
print("Animations Preloaded!")
