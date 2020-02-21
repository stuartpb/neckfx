local rawcode, reason = node.bootreason();

-- if the necklace booted normally
if reason == 0 then
  dofile 'live.lua'
-- if it booted under any other condition (ie. watchdog timeout)
else
  -- fail safe for service via TTL without needing to reflash
  dofile 'fallback.lua'
end
