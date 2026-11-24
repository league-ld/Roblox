local SessionLock = {}

local MemoryStore = game:GetService("MemoryStoreService")

local SLEnum = require(script.SLEnum)
local SessionData = require(script.SessionData)

export type SLEnum = typeof(SLEnum)
type SessionData = typeof(SessionData)

const SECOND = 1
const MINUTE = 60 * SECOND
const HOUR = 60 * MINUTE
const DAY = 24 * HOUR

const SESSION_HOLD_DURATION = 2 * MINUTE
const RETRY_RENEW_INTERVAL = 2 * SECOND

const API_CALL_ATTEMPTS = 3
const REATTEMPT_INTERVAL = 2

local sessionsHashMap = MemoryStore:GetHashMap("SessionLocks")
local heldSessionLocks: {SessionData} = {}

local processingRequests = {}

SessionLock.SLEnum = SLEnum
for _, v in pairs(SLEnum) do table.freeze(v) end
table.freeze(SLEnum)

SessionLock.getSessionOwner = function(dataKey: string): string?
	while processingRequests[dataKey] do task.wait() end
	
	local sessionOwner
	local attempts = 0
	local success, errormsg
	
	repeat
		success, errormsg = pcall(function()
			sessionOwner = sessionsHashMap:GetAsync(dataKey)
		end)
		
		attempts += 1
		if not success then
			task.wait(REATTEMPT_INTERVAL)
		end
	until success or attempts >= API_CALL_ATTEMPTS
	
	if not success then
		warn(`Error checking {dataKey} session owner: {errormsg}`)
		return "dead"
	end
	
	return if sessionOwner == "released" then nil else sessionOwner
end

SessionLock.AllowSaving = function(dataKey: string): boolean
	local data = heldSessionLocks[dataKey]
	if not data then return false end
	
	return data.AllowSaving and data.ExpirationTime > os.clock()
end

SessionLock.claimSessionLock = function(dataKey: string): SLEnum
	while processingRequests[dataKey] do task.wait() end
	
	local alreadyClaimed = true
	local renewed = false
	local attempts = 0
	local success, errormsg
	
	local claimTime = os.clock()
	
	processingRequests[dataKey] = true
	repeat
		success, errormsg = pcall(function()
			sessionsHashMap:UpdateAsync(dataKey, function(oldValue)
				alreadyClaimed = true
				renewed = false
				
				if oldValue ~= nil and oldValue ~= "released" then
					if oldValue == game.JobId then
						renewed = true
						return oldValue
					end

					return nil
				end

				alreadyClaimed = false
				return game.JobId
			end, SESSION_HOLD_DURATION)
		end)
		attempts += 1
		if not success then
			task.wait(REATTEMPT_INTERVAL)
		end
	until success or attempts >= API_CALL_ATTEMPTS
	processingRequests[dataKey] = nil
	
	local status = -1
	if not success then
		status = SLEnum.ClaimResponseStatus.Failed
	elseif renewed then
		status = SLEnum.ClaimResponseStatus.Renewed
	elseif alreadyClaimed then
		status = SLEnum.ClaimResponseStatus.AlreadyClaimed
	else
		status = SLEnum.ClaimResponseStatus.Success
	end
	
	if not success then
		warn(`Error claiming session lock: {errormsg}`)
		return status
	end
	
	if not alreadyClaimed or renewed then
		heldSessionLocks[dataKey] = {
			ExpirationTime = claimTime + SESSION_HOLD_DURATION - 5,
			AllowSaving = true
		}
	end
	
	return status
end

SessionLock.releaseSessionLock = function(dataKey: string)
	while processingRequests[dataKey] do task.wait() end
	
	local released = false
	local attempts = 0
	local success, errormsg
	
	processingRequests[dataKey] = true
	repeat
		success, errormsg = pcall(function()
			sessionsHashMap:UpdateAsync(dataKey, function(oldValue)
				released = false
				
				if oldValue == game.JobId then
					released = true
					return "released"
				end

				return nil
			end, SECOND)
		end)
		attempts += 1
		if not success then
			task.wait(REATTEMPT_INTERVAL)
		end
	until success or attempts >= API_CALL_ATTEMPTS
	processingRequests[dataKey] = nil
	
	if not success then
		warn(`Error removing session lock: {errormsg}`)
	end
	heldSessionLocks[dataKey] = nil
	
	return success and released
end

local renewalThread = task.spawn(function()
	while true do task.wait(SESSION_HOLD_DURATION / 3)
		for dataKey, sessionData in pairs(heldSessionLocks) do
			task.spawn(function()
				for i = 1, 2 do
					if not heldSessionLocks[dataKey] then break end
					
					local code = SessionLock.claimSessionLock(dataKey)
					if code == SLEnum.ClaimResponseStatus.Failed then
						if i == 2 then
							sessionData.AllowSaving = false
						end
						task.wait(RETRY_RENEW_INTERVAL)
						continue
					elseif code == SLEnum.ClaimResponseStatus.AlreadyClaimed then
						heldSessionLocks[dataKey] = nil
					end
					break
				end
			end)
		end
	end
end)

SessionLock.GameClosing = function()
	task.cancel(renewalThread)
	local remainingLeases = 0
	
	for _ in pairs(heldSessionLocks) do
		remainingLeases += 1
	end
	
	for dataKey in pairs(heldSessionLocks) do
		task.spawn(function()
			pcall(SessionLock.releaseSessionLock, dataKey)
			remainingLeases -= 1
		end)
	end
	
	while remainingLeases > 0 do task.wait() end
end



return SessionLock
