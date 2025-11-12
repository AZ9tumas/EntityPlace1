local Trail = script.Parent
local ArrowReal = Trail.Parent
local Arrow = ArrowReal.Parent
local Variables = Arrow:WaitForChild("Variables")
local HasHit = Variables:WaitForChild("HasHit")

if Trail.Enabled == false then
	Trail.Enabled = true
	print("trail enabled!")
end

HasHit.Changed:Connect(function(Value)
	if Value == true and Arrow:IsDescendantOf(workspace) then
		Trail.Enabled = false
		print("trail disabled!")
		script:Destroy()
	end
end)