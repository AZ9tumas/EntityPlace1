local TabManager = {}

local UIManager_AnimSlabsM = require(script.Parent.AnimationManager)

local function makeInvisible(stuff, exception)
	for _, v in pairs(stuff) do
		if v:IsA("Frame") and v ~= exception then
			v.Visible = false
		end
	end
end

function TabManager.Init(AnimatableTabObjects, headerFrames, tabFrame)
	local lastOpened = AnimatableTabObjects["Items"]

	for _, headerFrame in pairs(headerFrames) do
		for _, child in pairs(headerFrame:GetChildren()) do
			if child:IsA("ImageButton") then
				child.MouseButton1Click:Connect(function()
					if lastOpened.UIObject.Name == child.Name then return end

					local correspondingFrameAnim = AnimatableTabObjects[child.Name]
					local correspondingHeaderAnim = AnimatableTabObjects["Header_" .. child.Name]

					AnimatableTabObjects["Header_" .. lastOpened.UIObject.Name]:PlayAnimation(UIManager_AnimSlabsM.FadeOutChildren, function()
						makeInvisible(headerFrames, correspondingHeaderAnim.UIObject)
						correspondingHeaderAnim.UIObject.Visible = true
						correspondingHeaderAnim:PlayAnimation(UIManager_AnimSlabsM.FadeInChildren)
					end)

					lastOpened:PlayAnimation(UIManager_AnimSlabsM.SlideDownAndFadeOutChildren, function()
						makeInvisible(tabFrame:GetChildren(), correspondingFrameAnim.UIObject)
						correspondingFrameAnim.UIObject.Visible = true
						correspondingFrameAnim:PlayAnimation(UIManager_AnimSlabsM.SlideUpAndFadeInChildren)

						lastOpened = correspondingFrameAnim
					end)
				end)
			end
		end
	end
end

return TabManager