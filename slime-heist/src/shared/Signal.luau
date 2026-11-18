-- Signal simple (sin BindableEvent) para comunicación interna.

export type Connection = { Disconnect: (self: Connection) -> (), Connected: boolean }

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _handlers = {} :: { any } }, Signal)
end

function Signal:Connect(fn: (...any) -> ())
	local handlers = self._handlers
	local connection = { Connected = true }
	local entry = { Fn = fn, Connection = connection }
	function connection.Disconnect(conn)
		conn.Connected = false
		local index = table.find(handlers, entry)
		if index then
			table.remove(handlers, index)
		end
	end
	table.insert(handlers, entry)
	return connection
end

function Signal:Once(fn: (...any) -> ())
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		fn(...)
	end)
	return connection
end

function Signal:Fire(...)
	for _, entry in table.clone(self._handlers) do
		if entry.Connection.Connected then
			task.spawn(entry.Fn, ...)
		end
	end
end

function Signal:Wait()
	local thread = coroutine.running()
	self:Once(function(...)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

return Signal
