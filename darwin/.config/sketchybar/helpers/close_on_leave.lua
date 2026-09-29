-- Calls close once the mouse has left all of items. It waits a moment for the
-- next mouse.entered, so the mouse can cross from an item to its popup.
-- Returns a function that adds items later.
return function(items, close)
	local generation = 0
	local function watch(item)
		item:subscribe("mouse.entered", function()
			generation = generation + 1
		end)
		item:subscribe("mouse.exited", function()
			generation = generation + 1
			local mine = generation
			sbar.delay(0.3, function()
				if mine == generation then
					close()
				end
			end)
		end)
	end
	for _, item in ipairs(items) do
		watch(item)
	end
	return watch
end
