local bucketKey = KEYS[1]
local maxTokens = tonumber(ARGV[1])
local fillRate = tonumber(ARGV[2])
local currentTimestamp = tonumber(ARGV[3])

local state = redis.call('hmget', bucketKey, 'tokens', 'last_update')
local tokens = tonumber(state[1])
local lastUpdate = tonumber(state[2])

if not tokens then
  tokens = maxTokens
  lastUpdate = currentTimestamp
else
  local delta = math.max(0, currentTimestamp - lastUpdate)
  tokens = math.min(maxTokens, tokens + (delta * fillRate))
end

if tokens >= 1 then
  tokens = tokens - 1
  redis.call('hmset', bucketKey, 'tokens', tokens, 'last_update', currentTimestamp)
  redis.call('expire', bucketKey, 86400)
  return 1
end

return 0
