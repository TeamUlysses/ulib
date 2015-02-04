local function hook_calc()
	local x = 13*5
end

local function run_once(numHooks, times)
	local startTime = SysTime()

	for priority = -2, 2 do
		for i = 1, numHooks do
			hook.Add("HookPerfTest", "hPerfTest" .. priority .. "-" .. i, hook_calc, priority)
		end
	end

	local hookAddTime = SysTime()

	for i = 1, times do
		hook.Call("HookPerfTest")
	end

	local hookCallTime = SysTime()

	for priority = -2, 2 do
		for i = 0, numHooks do
			hook.Remove("HookPerfTest", "hPerfTest" .. priority .. "-" .. i)
		end
	end

	local hookRemoveTime = SysTime()


	return hookAddTime - startTime, hookCallTime - hookAddTime, hookRemoveTime - hookCallTime
end

function hook_test(numHooks, times, timesToAverage)
	local addTime = 0
	local callTime = 0
	local removeTime = 0

	for i = 0, timesToAverage do
		local a, c, r = run_once(numHooks, times)
		addTime = addTime + a
		callTime = callTime + c
		removeTime = removeTime + r
	end

	addTime = addTime / timesToAverage
	hookCallTime = callTime / timesToAverage
	hookRemoveTime = removeTime / timesToAverage


	print("Results:\n")
	print("hook.Add    * " .. numHooks * 5, addTime)
	print("hook.Call   * " .. times * numHooks * 5, hookCallTime)
	print("hook.Remove * " .. numHooks * 5, hookRemoveTime)


end

print("Hook performance loaded!")