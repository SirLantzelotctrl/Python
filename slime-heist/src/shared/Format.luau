-- Utilidades de formato: números abreviados ($1.25M), tiempos, etc.

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc", "Ud", "Dd", "Td" }

local function stripZeros(text: string): string
	if string.find(text, ".", 1, true) then
		text = (string.gsub(text, "0+$", ""))
		text = (string.gsub(text, "%.$", ""))
	end
	return text
end

function Format.Abbreviate(n: number): string
	if n ~= n or n == math.huge or n == -math.huge then
		return "0"
	end
	local negative = n < 0
	local value = math.abs(n)
	local text: string
	if value < 1000 then
		if value < 10 and value % 1 ~= 0 then
			text = stripZeros(string.format("%.1f", math.floor(value * 10) / 10))
		else
			text = tostring(math.floor(value))
		end
	else
		local tier = math.floor(math.log10(value) / 3)
		if tier >= #SUFFIXES then
			text = string.format("%.2e", value)
		else
			local scaled = value / (10 ^ (tier * 3))
			if scaled >= 100 then
				text = tostring(math.floor(scaled))
			elseif scaled >= 10 then
				text = stripZeros(string.format("%.1f", math.floor(scaled * 10) / 10))
			else
				text = stripZeros(string.format("%.2f", math.floor(scaled * 100) / 100))
			end
			text ..= SUFFIXES[tier + 1]
		end
	end
	return (if negative then "-" else "") .. text
end

function Format.Money(n: number): string
	return "$" .. Format.Abbreviate(n)
end

function Format.PerSecond(n: number): string
	return "$" .. Format.Abbreviate(n) .. "/s"
end

function Format.Commas(n: number): string
	local text = tostring(math.floor(math.abs(n)))
	local result = string.reverse((string.gsub(string.reverse(text), "(%d%d%d)", "%1,")))
	if string.sub(result, 1, 1) == "," then
		result = string.sub(result, 2)
	end
	return (if n < 0 then "-" else "") .. result
end

-- 75 -> "1:15", 3725 -> "1:02:05"
function Format.Clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = seconds % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end

-- 90 -> "1m 30s", 7200 -> "2h 0m"
function Format.Duration(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = seconds % 60
	if h > 0 then
		return if m > 0 then string.format("%dh %dm", h, m) else string.format("%dh", h)
	elseif m > 0 then
		return if s > 0 then string.format("%dm %ds", m, s) else string.format("%dm", m)
	end
	return string.format("%ds", s)
end

function Format.Percent(fraction: number): string
	return stripZeros(string.format("%.1f", fraction * 100)) .. "%"
end

function Format.Multiplier(mult: number): string
	return "x" .. stripZeros(string.format("%.2f", mult))
end

return Format
