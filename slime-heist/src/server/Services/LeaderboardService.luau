-- Clasificaciones globales (OrderedDataStore) mostradas en los tablones del mapa.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)

local Registry = require(script.Parent.Parent.Registry)

local LeaderboardService = {}

local REFRESH_INTERVAL = 120

type Board = {
	Name: string,
	Store: OrderedDataStore?,
	GetScore: (data: any) -> number,
	FormatValue: (stored: number) -> string,
}

local boards: { Board } = {
	{
		Name = "TopEarned",
		Store = nil,
		GetScore = function(data)
			return Economy.EncodeScore(data.TotalEarned)
		end,
		FormatValue = function(stored)
			return Format.Money(Economy.DecodeScore(stored))
		end,
	},
	{
		Name = "TopRebirths",
		Store = nil,
		GetScore = function(data)
			return data.Rebirths
		end,
		FormatValue = function(stored)
			return tostring(stored)
		end,
	},
	{
		Name = "TopSteals",
		Store = nil,
		GetScore = function(data)
			return data.Stats.Steals
		end,
		FormatValue = function(stored)
			return Format.Abbreviate(stored)
		end,
	},
}

local nameCache: { [number]: string } = {}

local function getName(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local result = if ok and name then name else "Player"
	nameCache[userId] = result
	return result
end

local function setRow(boardName: string, rank: number, text: string)
	local gui = Registry.MapService.Boards[boardName]
	local row = gui and gui:FindFirstChild("Row" .. rank)
	if row and row:IsA("TextLabel") then
		row.Text = text
	end
end

function LeaderboardService.Submit(player: Player)
	local data = Registry.DataService.Get(player)
	if not data or player.UserId <= 0 then
		return
	end
	for _, board in boards do
		if board.Store then
			local score = math.floor(board.GetScore(data))
			if score > 0 then
				pcall(function()
					(board.Store :: OrderedDataStore):SetAsync(tostring(player.UserId), score)
				end)
			end
		end
	end
end

function LeaderboardService.Refresh()
	for _, board in boards do
		if board.Store then
			local ok, pages = pcall(function()
				return (board.Store :: OrderedDataStore):GetSortedAsync(false, 10)
			end)
			if ok and pages then
				local entries = pages:GetCurrentPage()
				for rank = 1, 10 do
					local entry = entries[rank]
					if entry then
						local userId = tonumber(entry.key) or 0
						setRow(board.Name, rank, ("  #%d  %s  •  %s"):format(rank, getName(userId), board.FormatValue(entry.value)))
					else
						setRow(board.Name, rank, ("  #%d  ---"):format(rank))
					end
				end
			end
		end
	end
end

function LeaderboardService.Start()
	if not Registry.DataService.IsPersistent() then
		for _, board in boards do
			setRow(board.Name, 1, "  Publish the game to")
			setRow(board.Name, 2, "  enable leaderboards")
		end
		return
	end
	for _, board in boards do
		local ok, store = pcall(function()
			return DataStoreService:GetOrderedDataStore(Config.LeaderboardStorePrefix .. board.Name)
		end)
		if ok then
			board.Store = store
		end
	end
	task.spawn(function()
		task.wait(10)
		while true do
			for _, player in Players:GetPlayers() do
				LeaderboardService.Submit(player)
			end
			LeaderboardService.Refresh()
			task.wait(REFRESH_INTERVAL)
		end
	end)
end

function LeaderboardService.OnPlayerRemoving(player: Player)
	if Registry.DataService.IsPersistent() then
		LeaderboardService.Submit(player)
	end
end

return LeaderboardService
