local G = love.graphics

local PADDING = 5

local colors = {
	text        = { 1, 1, 1 },
	window      = { 0.2, 0.2, 0.2, 0.8 },
	separator   = { 0.4, 0.4, 0.4, 0.4 },

	active      = { 0.8, 0.4, 0.4, 0.8 },
	hover       = { 0.6, 0.4, 0.4, 0.8 },
	normal      = { 0.4, 0.4, 0.4, 0.8 },
	check       = { 1, 1, 1, 0.8 },

	drag_active = { 0.6, 0.4, 0.4, 0.4 },
	drag_hover  = { 0.6, 0.4, 0.4, 0.4 },
	drag_normal = { 0.4, 0.4, 0.4, 0.4 },
	drag_handle = { 0.8, 0.4, 0.4, 0.8 },
}
local function set_color(c)
	G.setColor(unpack(colors[c]))
end


gui = {
	mx                = 0,
	my                = 0,
	iw                = 0,
	ih                = 0,

	wheel             = 0,
	is_mouse_down     = false,
	was_mouse_clicked = false,
	was_key_pressed   = {},
	hover_item        = nil,
	active_item       = nil,
	windows           = { {}, {}, {} },
}
for _, win in ipairs(gui.windows) do
	win.columns = {
		{
			min_x = 0,
			max_x = 0,
			min_y = 0,
			max_y = 0,
		}
	}
end

function gui:get_id(label)
	return self.id_prefix .. label
end
function gui:has_focus()
	for _, win in ipairs(self.windows) do
		local c = win.columns[#win.columns]
		local box = {
			x = c.min_x,
			y = c.min_y,
			w = c.max_x - c.min_x + PADDING,
			h = c.max_y - c.min_y + PADDING,
		}
		if self:mouse_in_box(box) then return true end
	end
	return self.active_item ~= nil
end
function gui:keypressed(k)
	self.was_key_pressed[k] = true
end
function gui:wheelmoved(y)
	self.wheel = y
	return self:has_focus()
end
function gui:mousemoved(x, y, dx, dy)
	self.mx = x
	self.my = y
	return self:has_focus()
end
function gui:select_win(nr)
	self.current_window = self.windows[nr]
	self.id_prefix = tostring(nr)
end
function gui:item_min_size(w, h)
	self.iw = w
	self.ih = h
end
function gui:item_box(w, h, pad)
	w = math.max(w, self.iw)
	h = math.max(h, self.ih)
	self.iw = 0
	self.ih = 0

	pad = pad or PADDING
	local win = self.current_window
	local box = {}
	if win.same_line then
		win.same_line = false
		box.x = win.max_cx + pad
		box.y = win.min_cy + pad
		if win.max_cy - win.min_cy - pad > h then
			box.y = box.y + (win.max_cy - win.min_cy - pad - h) / 2
		end
		win.max_cx = math.max(win.max_cx, box.x + w)
		win.max_cy = math.max(win.max_cy, box.y + h)
	else
		box.x = win.min_cx + pad
		box.y = win.max_cy + pad
		win.min_cy = win.max_cy
		win.max_cx = box.x + w
		win.max_cy = box.y + h
	end

	local c = win.columns[#win.columns]
	c.max_x = math.max(c.max_x, win.max_cx)
	c.max_y = math.max(c.max_y, win.max_cy)
	box.w = w
	box.h = h
	return box
end
function gui:mouse_in_box(box)
	return self.mx >= box.x and self.mx <= box.x + box.w
		and self.my >= box.y and self.my <= box.y + box.h
end


-- public functions
function gui:same_line()
	self.current_window.same_line = true
end
function gui:begin_frame()

	-- input
	local p = self.is_mouse_down
	self.is_mouse_down = love.mouse.isDown(1)
	self.was_mouse_clicked = self.is_mouse_down and not p
	if not self.is_mouse_down then
		self.active_item = nil
	end
	self.hover_item = nil


	-- draw windows
	for _, win in ipairs(self.windows) do
		if win.columns then
			local c = win.columns[1]
			set_color("window")
			G.rectangle("fill", c.min_x, c.min_y, c.max_x - c.min_x + PADDING, c.max_y - c.min_y + PADDING,
					PADDING)
		end
	end

	do
		-- custom window size and position policies

		-- left window
		-- shrink height
		self.windows[1].columns[1].max_y = 0

		-- right window
		local c = self.windows[2].columns[1]
		if c.min_x == 0 then
			c.min_x = G.getWidth()
		else
			c.min_x = G.getWidth() - (c.max_x - c.min_x) - PADDING
		end
		c.max_x = G.getWidth() - PADDING
		c.min_y = 0
		c.max_y = 0


		-- bottom window
		local c = self.windows[3].columns[1]
		if c.min_y == 0 then
			c.min_y = G.getHeight()
		else
			c.min_y = G.getHeight() - (c.max_y - c.min_y) - PADDING
		end
		c.max_y = c.min_y
		c.max_x = G.getWidth() - PADDING
	end



	for _, win in ipairs(self.windows) do
		local c = win.columns[1]
		win.min_cx = c.min_x
		win.max_cx = c.min_x
		win.min_cy = c.min_y
		win.max_cy = c.min_y
	end

	self:select_win(1)
end
function gui:end_frame()
	self.was_key_pressed = {}
	self.wheel = 0
end
function gui:begin_column()
	local win = self.current_window
	local c = {}
	if win.same_line then
		c.min_x = win.max_cx
		c.min_y = win.min_cy
	else
		c.min_x = win.min_cx
		c.min_y = win.max_cy
	end
	c.max_x = c.min_x
	c.max_y = c.min_y
	table.insert(win.columns, c)
	win.min_cx = c.min_x
	win.max_cx = c.min_x
	win.min_cy = c.min_y
	win.max_cy = c.min_y
end
function gui:end_column()
	local win = self.current_window
	local c = table.remove(win.columns)
	win.min_cx = c.min_x
	win.min_cy = c.min_y
	win.max_cx = c.max_x
	win.max_cy = c.max_y
	local c = win.columns[#win.columns]
	c.max_x = math.max(c.max_x, win.max_cx)
	c.max_y = math.max(c.max_y, win.max_cy)
end
function gui:separator()
	local win = self.current_window
	set_color("separator")
	if win.same_line then
		local box = self:item_box(4, win.max_cy - win.min_cy - PADDING)
		G.rectangle("fill", box.x, box.y - PADDING, box.w, box.h + PADDING * 2)
		win.same_line = true
	else
		local c = win.columns[#win.columns]
		local box = self:item_box(c.max_x - c.min_x - PADDING, 4)
		G.rectangle("fill", box.x - PADDING, box.y, box.w + PADDING * 2, box.h)
	end
end
function gui:text(fmt, ...)
	local str = fmt:format(...)
	local w = G.getFont():getWidth(str)
	local box = self:item_box(w, 14)
	set_color("text")
	G.print(str, box.x, box.y + box.h / 2 - 8)
end
function gui:button(label)
	local id = self:get_id(label)
	local w = G.getFont():getWidth(label) + 10
	local box = self:item_box(w, 20)

	local hover = self:mouse_in_box(box)
	if hover then
		self.hover_item = id
		if self.was_mouse_clicked then
			self.active_item = id
		end
	end

	if id == self.active_item then
		set_color("active")
	elseif hover then
		set_color("hover")
	else
		set_color("normal")
	end
	G.rectangle("fill", box.x, box.y, box.w, box.h, PADDING)

	set_color("text")
	G.printf(label, box.x, box.y + box.h / 2 - 8, box.w, "center")

	return hover and self.was_mouse_clicked
end
function gui:checkbox(label, t, n)
	local id = self:get_id(label)
	local w = G.getFont():getWidth(label) + 20 + PADDING
	local box = self:item_box(w, 20)

	local hover = self:mouse_in_box(box)
	if hover then
		self.hover_item = id
		if self.wasmouse_clicked then
			self.active_item = id
			t[n] = not t[n]
		end
	end

	if id == self.active_item then
		set_color("active")
	elseif hover then
		set_color("hover")
	else
		set_color("normal")
	end
	G.rectangle("fill", box.x, box.y, box.h, box.h, PADDING)

	if t[n] then
		set_color("check")
		G.rectangle("fill", box.x + 5, box.y + 5, box.h - 10, box.h - 10)
	end

	set_color("text")
	G.print(label, box.x + box.h + PADDING, box.y + box.h / 2 - 8)

	return hover and self.was_mouse_clicked
end
function gui:radio_button(label, v, t)
	local id = self:get_id(label)
	local w = G.getFont():getWidth(label) + 10
	local box = self:item_box(w, 20)

	local hover = self:mouse_in_box(box)
	if hover then
		self.hover_item = id
		if self.was_mouse_clicked then
			self.active_item = id
			t[1] = v
		end
	end

	if t[1] == v or id == self.active_item then
		set_color("active")
	elseif hover then
		set_color("hover")
	else
		set_color("normal")
	end
	G.rectangle("fill", box.x, box.y, box.w, box.h, PADDING)

	set_color("text")
	G.printf(label, box.x, box.y + box.h / 2 - 8, box.w, "center")

	return hover and self.was_mouse_clicked
end
function gui:drag_value(label, t, n, step, min, max, fmt)
	local id = self:get_id(label)
	local v = t[n]
	local text = label .. "  " .. fmt:format(v)
	local w = G.getFont():getWidth(text) + 10
	local box = self:item_box(w, 20)

	local hover = self:mouse_in_box(box)
	if hover then
		self.hover_item = id
		if self.was_mouse_clicked then
			self.active_item = id
		end
	end

	local handle_w = math.max(4, box.w / (1 + (max - min) / step))
	local handle_x = (v - min) / (max - min) * (box.w - handle_w)

	if id == self.active_item then
		local x = (self.mx - box.x - handle_w * 0.5) / (box.w - handle_w)
		x = min + math.floor(x * (max - min) / step + 0.5) * step
		t[n] = clamp(x, min, max)
		set_color("drag_active")
	elseif hover then
		t[n] = clamp(v + step * self.wheel, min, max)
		set_color("drag_hover")
	else
		set_color("drag_normal")
	end
	G.rectangle("fill", box.x, box.y, box.w, box.h)


	set_color("drag_handle")
	G.rectangle("fill", box.x + handle_x, box.y, handle_w, box.h)

	set_color("text")
	G.printf(text, box.x, box.y + box.h / 2 - 8, box.w, "center")

	return v ~= t[n]
end
