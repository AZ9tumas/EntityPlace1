local CP = game:GetService("ContentProvider")
local Animations = game.ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Animations")

CP:PreloadAsync(Animations:GetDescendants())