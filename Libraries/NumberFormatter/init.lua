--!strict
local Suffixes: {string} = require(script.Suffixes)

local NumberFormatter = {}

--[[
    Formats a number to a shortened version with a suffix at the end.
    If there is no information for a suffix of this denomination it will shorten it and add "?".
    ex: 1234 -> 1.2k
]]
function NumberFormatter.FormatWithSuffix(Number: number) : string

    -- We only format numbers > 1000.
    if Number >= 1000 then
        local MultiplesOfThree: number = math.floor(math.log(Number, 10) / 3)
        local Divisor: number = 10 ^ (3 * MultiplesOfThree)

        return tostring(math.floor(Number / Divisor * 10) / 10) .. (Suffixes[MultiplesOfThree] or "?")
    else
        return tostring(Number)
    end
end

return NumberFormatter
