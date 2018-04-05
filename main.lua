require("helper")
require("fancymodel")
require("gui")

local G = love.graphics
love.keyboard.setKeyRepeat(true)

-- C64 color palette
local colors = {
	{ 0, 0, 0 },
	{ 1, 1, 1 },
	{ 0.41, 0.22, 0.17 },
	{ 0.44, 0.64, 0.7 },
	{ 0.44, 0.24, 0.53 },
	{ 0.35, 0.55, 0.26 },
	{ 0.21, 0.16, 0.47 },
	{ 0.72, 0.78, 0.44 },
	{ 0.44, 0.31, 0.15 },
	{ 0.26, 0.22, 0 },
	{ 0.6, 0.4, 0.35 },
	{ 0.27, 0.27, 0.27 },
	{ 0.42, 0.42, 0.42 },
	{ 0.6, 0.82, 0.52 },
	{ 0.42, 0.37, 0.71 },
	{ 0.58, 0.58, 0.58 },
}


local cam = {
	x    = 0,
	y    = -75,
	zoom = 0.5,
}
local edit = {
	file_name   = arg[2] or "save.model",
	show_fill   = true,
	show_grid   = true,
	show_joints = true,
	show_bones  = true,

	-- mouse
	mx = 0,
	my = 0,

	modes = {},
}

local model = Model(edit.file_name)


edit.modes.bone = {
	ik_length     = 2,
	selected_bone = model.root,
	bone_buffer   = nil, -- for copying
}
function edit.modes.bone:keypressed(k)
end
function edit.modes.bone:mousepressed(x, y, button)
	if button == 1 and love.keyboard.isDown("c") then
		-- add new bone
		local b = self.selected_bone
		local si = math.sin(b.global_a)
		local co = math.cos(b.global_a)
		local dx = edit.mx - b.global_x
		local dy = edit.my - b.global_y
		local k = Bone(dx * co + dy * si, dy * co - dx * si)
		model:add_bone(k)
		b:add_kid(k)
		k:update()
		self.selected_bone = k
	elseif button == 2 then
		-- select bone
		local dist = 10
		for _, b in ipairs(model.bones) do
			local d = math.max(
				math.abs(b.global_x - edit.mx),
				math.abs(b.global_y - edit.my)) / cam.zoom
			if d < dist then
				dist = d
				self.selected_bone = b
			end
		end
	end
end
function edit.modes.bone:mousereleased(x, y, button)
end
function edit.modes.bone:mousemoved(x, y, dx, dy)
	local function move(dx, dy)
		local b = self.selected_bone
		local si = math.sin(b.global_a - b.a)
		local co = math.cos(b.global_a - b.a)
		b.x = b.x + dx * co + dy * si
		b.y = b.y + dy * co - dx * si
		b:update()
	end

	if love.keyboard.isDown("g") then
		-- move
		move(dx, dy)

	elseif love.keyboard.isDown("r") then
		-- rotate
		local b = self.selected_bone
		local bx = edit.mx - b.global_x
		local by = edit.my - b.global_y
		local a = math.atan2(bx - dx, by - dy) - math.atan2(bx, by)
		if a < -math.pi then a = a + 2 * math.pi end
		if a > math.pi then a = a - 2 * math.pi end
		b.a = b.a + a
		b:update()

	elseif love.mouse.isDown(1) then
		-- ik
		if not self.selected_bone.parent then
			move(dx, dy)
			return
		end

		local tx = self.selected_bone.global_x + dx
		local ty = self.selected_bone.global_y + dy

		local function calc_error()
			return distance(self.selected_bone.global_x, self.selected_bone.global_y, tx, ty)
		end

		for _ = 1, 200 do
			local delta = 0.0005

			local improve = false
			local b = self.selected_bone
			for _ = 1, self.ik_length do
				b = b.parent
				if not b then break end

				local e = calc_error()
				b.a = b.a + delta
				b:update()
				if calc_error() > e then
					b.a = b.a - delta * 2
					b:update()
					if calc_error() > e then
						b.a = b.a + delta
						b:update()
					else
						improve = true
					end
				else
					improve = true
				end

				-- give parents a smaller weight
				delta = delta * 1.0
			end
			if not improve then break end
		end

	end
end
function edit.modes.bone:do_gui()
	gui:select_win(1)

	gui:separator()
	gui:item_min_size(125, 0)
	gui:drag_value("IK chain", self, "ik_length", 1, 1, 5, "%d")

	-- duplicate bone
	local function duplicate(b, p)
		local k = Bone(b.x, b.y, b.rot)
		k.keyframes = {}
		if p then p:add_kid(k) end
		for i, l in ipairs(b.kids) do
			duplicate(l, k)
		end
		return k
	end
	gui:item_min_size(60, 0)
	if gui:button("copy") then
		if self.selected_bone ~= model.root then
			self.bone_buffer = duplicate(self.selected_bone, nil)
		end
	end
	gui:same_line()
	gui:item_min_size(60, 0)
	if gui:button("paste") and self.bone_buffer then
		self.selected_bone = duplicate(self.bone_buffer, self.selected_bone)
		model:add_bone(self.selected_bone)
		self.selected_bone:update()
	end

	gui:item_min_size(125, 0)
	if gui:button("delete")
	or gui.was_key_pressed["x"] then
		-- delete bone
		if self.selected_bone.parent then
			local k = self.selected_bone
			self.selected_bone = k.parent
			model:delete_bone(k)
		end
	end


	local b = self.selected_bone
	gui:text("x  %.2f", b.x)
	gui:text("y  %.2f", b.y)
	gui:text("a  %.2f°", b.a * 180 / math.pi)
	gui:text("X  %.2f", b.global_x)
	gui:text("Y  %.2f", b.global_y)
end


edit.modes.mesh = {
	poly_index        = 0,
	selected_vertices = {},
}
function edit.modes.mesh:select_poly()
	local index = self.poly_index
	self.poly_index = 0
	for i = 1, #model.polys do
		if index > 0 then
			i = (i + index - 1) % #model.polys + 1
		end
		local poly = model.polys[i]
		local click = false
		local x1 = poly.data[#poly.data - 1]
		local y1 = poly.data[#poly.data]
		for j = 1, #poly.data, 2 do
			local x2 = poly.data[j]
			local y2 = poly.data[j + 1]
			local dx = x2 - x1
			local dy = y2 - y1
			local ex = edit.mx - x1
			local ey = edit.my - y1
			if (y1 <= edit.my) == (y2 > edit.my)
			and ex < dx * ey / dy then
				click = not click
			end
			x1 = x2
			y1 = y2
		end
		if click then
			self.poly_index = i
			self.selected_vertices = {}
			for i = 1, #poly.data, 2 do
				table.insert(self.selected_vertices, i)
			end
			break
		end
	end
end
function edit.modes.mesh:keypressed(k)
	local poly = model.polys[self.poly_index]
	if poly then

		if k == "x" then
			-- delete selected vertice
			for j = #self.selected_vertices, 1, -1 do
				local i = self.selected_vertices[j]
				table.remove(poly.data, i)
				table.remove(poly.data, i)
			end
			self.selected_vertices = {}

			-- remove polygon if less than 3 three vertices are left
			if #poly.data < 6 then
				table.remove(model.polys, self.poly_index)
				self.poly_index = 0
			end

		elseif k == "a" then
			-- toggle select
			local v = {}
			if #self.selected_vertices == 0 then
				for i = 1, #poly.data, 2 do
					v[#v + 1] = i
				end
			end
			self.selected_vertices = v
		end
	end
end
function edit.modes.mesh:mousepressed(x, y, button)
	local poly = model.polys[self.poly_index]
	if poly then
		if button == 1 and love.keyboard.isDown("c") then
			-- add new vertex
			local index = 1
			local min_l = nil
			for i = 1, #poly.data, 2 do
				local ax = poly.data[i]
				local ay = poly.data[i + 1]
				local bx = poly.data[(i + 2) % #poly.data]
				local by = poly.data[(i + 2) % #poly.data + 1]
				local d0 = distance(ax, ay, bx, by)
				local d1 = distance(ax, ay, edit.mx, edit.my)
				local d2 = distance(bx, by, edit.mx, edit.my)
				l = (d1 + d2) / d0
				if not min_l or l < min_l then
					min_l = l
					index = i + 2
				end
			end

			table.insert(poly.data, index, edit.mx)
			table.insert(poly.data, index + 1, edit.my)
			self.selected_vertices = { index }

		elseif button == 2 then
			-- vertex selection rect
			self.sx = edit.mx
			self.sy = edit.my
		end

	else
		if button == 1 and love.keyboard.isDown("c") then
			-- create new poly
			local s = cam.zoom * 20
			table.insert(model.polys, {
				data = {
					edit.mx - s, edit.my - s, edit.mx + s, edit.my - s,
					edit.mx + s, edit.my + s, edit.mx - s, edit.my + s
				},
				color = 11,
				shade = 1,
				bone  = nil,
			})
			self.poly_index = #model.polys
			self.selected_vertices = { 1, 3, 5, 7 }
		end
	end
end
function edit.modes.mesh:mousereleased(x, y, button)
	local poly = model.polys[self.poly_index]
	if poly then
		if button == 2 then
			-- select vertices
			local shift = love.keyboard.isDown("lshift", "rshift")
			if not shift then
				self.selected_vertices = {}
			end
			if edit.mx == self.sx and edit.my == self.sy then
				local dist = 10
				local vertex = nil
				for i = 1, #poly.data, 2 do
					local d = math.max(
						math.abs(poly.data[i    ] - edit.mx),
						math.abs(poly.data[i + 1] - edit.my)) / cam.zoom
					if d < dist then
						dist = d
						vertex = i
					end
				end
				if vertex then
					table.insert(self.selected_vertices, vertex)
				end
				if not shift and #self.selected_vertices == 0 then
					self:select_poly()
				end
			else
				local min_x = math.min(edit.mx, self.sx)
				local min_y = math.min(edit.my, self.sy)
				local max_x = math.max(edit.mx, self.sx)
				local max_y = math.max(edit.my, self.sy)
				for i = 1, #poly.data, 2 do
					local x = poly.data[i]
					local y = poly.data[i + 1]
					local s = x >= min_x and x <= max_x and y >= min_y and y <= max_y
					if s then
						table.insert(self.selected_vertices, i)
					end
				end
			end
			self.sx = nil
			self.sy = nil
		end
	else
		if button == 2 then
			-- select poly
			self:select_poly()
		end
	end
end
function edit.modes.mesh:mousemoved(x, y, dx, dy)
	local poly = model.polys[self.poly_index]

	if poly then
		local function get_selection_center()
			local cx = 0
			local cy = 0
			for _, i in ipairs(self.selected_vertices) do
				cx = cx + poly.data[i    ]
				cy = cy + poly.data[i + 1]
			end
			cx = cx / #self.selected_vertices
			cy = cy / #self.selected_vertices
			return cx, cy
		end

		if love.mouse.isDown(1) or love.keyboard.isDown("g") then
			-- move
			for _, i in ipairs(self.selected_vertices) do
				poly.data[i    ] = poly.data[i    ] + dx
				poly.data[i + 1] = poly.data[i + 1] + dy
			end

		elseif love.keyboard.isDown("s") then
			-- scale
			local cx, cy = get_selection_center()
			local l1 = distance(edit.mx, edit.my, cx + dx, cy + dy)
			local l2 = distance(edit.mx, edit.my, cx, cy)
			local s = l2 / l1

			for _, i in ipairs(self.selected_vertices) do
				poly.data[i    ] = cx + (poly.data[i    ] - cx) * s
				poly.data[i + 1] = cy + (poly.data[i + 1] - cy) * s
			end

		elseif love.keyboard.isDown("r") then
			-- rotate
			local cx, cy = get_selection_center()

			local bx = edit.mx - cx
			local by = edit.my - cy
			local a = math.atan2(bx - dx, by - dy)- math.atan2(bx, by)
			if a < -math.pi then a = a + 2 * math.pi end
			if a > math.pi then a = a - 2 * math.pi end
			local si = math.sin(a)
			local co = math.cos(a)

			for _, i in ipairs(self.selected_vertices) do
				local dx = poly.data[i    ] - cx
				local dy = poly.data[i + 1] - cy
				poly.data[i    ] = cx + dx * co - dy * si
				poly.data[i + 1] = cy + dy * co + dx * si
			end
		end
	end
end
function edit.modes.mesh:do_gui()
	gui:select_win(1)

	local poly = model.polys[self.poly_index]
	if poly then
		gui:separator()

		gui:text("vertices  %d", #poly.data / 2)

		gui:item_min_size(75, 20)
		gui:text("index  %d", self.poly_index)
		gui:same_line()
		gui:item_min_size(20, 0)
		if gui:button("<") then
			if self.poly_index > 1 then
				model.polys[self.poly_index], model.polys[self.poly_index - 1] =
					model.polys[self.poly_index - 1], model.polys[self.poly_index]
				self.poly_index = self.poly_index - 1
			end
		end
		gui:same_line()
		gui:item_min_size(20, 0)
		if gui:button(">") then
			if self.poly_index < #model.polys then
				model.polys[self.poly_index], model.polys[self.poly_index + 1] =
					model.polys[self.poly_index + 1], model.polys[self.poly_index]
				self.poly_index = self.poly_index + 1
			end
		end

		gui:item_min_size(125, 0)
		gui:drag_value("color", poly, "color", 1, 1, 16, "%d")
		gui:item_min_size(125, 0)
		gui:drag_value("shade", poly, "shade", 0.05, 0.3, 1.3, "%.2f")

		gui:item_min_size(60, 0)
		if gui:button("assign") then
			poly.bone = edit.modes.bone.selected_bone
		end
		gui:same_line()
		gui:item_min_size(60, 0)
		if gui:button("orphan") then
			poly.bone = nil
		end
	end
end


edit.mode = edit.modes.mesh


function love.keypressed(k)
	gui:keypressed(k)
	edit.mode:keypressed(k)
end
function love.mousepressed(x, y, button)
	edit.mode:mousepressed(x, y, button)
end
function love.mousereleased(x, y, button)
	edit.mode:mousereleased(x, y, button)
end
function love.mousemoved(x, y, dx, dy)
	if gui:mousemoved(x, y, dx, dy) then return end

	-- update mouse pos
	edit.mx = cam.x + (x - G.getWidth() / 2) * cam.zoom
	edit.my = cam.y + (y - G.getHeight() / 2) * cam.zoom

	-- scale movement
	dx = dx * cam.zoom
	dy = dy * cam.zoom
	if love.keyboard.isDown("lshift", "rshift") then
		dx = dx * 0.1
		dy = dy * 0.1
	end

	-- move camera
	if love.mouse.isDown(3) then
		cam.x = cam.x - dx
		cam.y = cam.y - dy
		return
	end

	edit.mode:mousemoved(x, y, dx, dy)
end
function love.wheelmoved(_, y)
	if gui:wheelmoved(y) then return end
	cam.zoom = cam.zoom * (0.9 ^ y)

	-- update mouse pos
	local x, y = love.mouse.getPosition()
	edit.mx = cam.x + (x - G.getWidth() / 2) * cam.zoom
	edit.my = cam.y + (y - G.getHeight() / 2) * cam.zoom
end
function love.update()
end


function do_gui()
	G.origin()
	G.setLineWidth(1)
	gui:begin_frame()

	do
		gui:select_win(1)

		gui:item_min_size(60, 0)
		gui:checkbox("fill", edit, "show_fill")
		gui:same_line()
		gui:checkbox("joint", edit, "show_joints")
		gui:item_min_size(60, 0)
		gui:checkbox("bone", edit, "show_bones")
		gui:same_line()
		gui:checkbox("grid", edit, "show_grid")
		if gui.was_key_pressed["#"] then
			local v = not edit.show_grid
			edit.show_grid   = v
			edit.show_bones  = v
		end


--		if gui.was_key_pressed["b"] then
--			bg.enabled = not bg.enabled
--		end
--		gui:checkbox("image", bg, "enabled")


		gui:item_min_size(125, 0)
		gui:separator()

		local m = edit.mode == edit.modes.bone and "bone" or "mesh"
		local t = { m }
		gui:item_min_size(60, 0)
		gui:radio_button("mesh", "mesh", t)
		gui:same_line()
		gui:item_min_size(60, 0)
		gui:radio_button("bone", "bone", t)
		if m ~= t[1]
		or gui.was_key_pressed["tab"] then
			m = m == "bone" and "mesh" or "bone"
			edit.mode = edit.modes[m]
		end
	end


	local ctrl = love.keyboard.isDown("lctrl", "rctrl")
	local shift = love.keyboard.isDown("lshift", "rshift")

	do
		gui:select_win(2)

		if gui:button("new")
		or (gui.was_key_pressed["n"] and ctrl) then
			model:reset()
			edit.modes.mesh.selected_vertices = {}
			edit.modes.mesh.poly_index = 0
			edit.modes.bone.selected_bone = model.root
		end
		gui:same_line()
		if gui:button("load")
		or (gui.was_key_pressed["l"] and ctrl) then
			if model:load(edit.file_name) then
				print("model loaded")
			else
				print("error loading model")
			end
			edit.modes.mesh.selected_vertices = {}
			edit.modes.mesh.poly_index = 0
			edit.modes.bone.selected_bone = model.root
		end
		gui:same_line()
		if gui:button("save")
		or (gui.was_key_pressed["s"] and ctrl) then
			model:save(edit.file_name)
			print("model saved")
		end
		gui:same_line()

		if gui:button("quit")
		or gui.was_key_pressed["escape"] then
			love.event.quit()
		end
	end

	do
--		gui:select_win(3)
--
--		-- timeline
--		local w = gui.current_window.columns[1].max_x - gui.current_window.max_cx - 5
--		local box = gui:item_box(w, 45)
--
--		-- change frame
--		if gui.was_key_pressed["backspace"] then
--			if edit.current_anim then
--				edit:set_frame(edit.current_anim.start)
--			else
--				edit:set_frame(0)
--			end
--		end
--		local dx = (gui.was_key_pressed["right"] and 1 or 0)
--				- (gui.was_key_pressed["left"] and 1 or 0)
--		if dx ~= 0 then
--			if shift then dx = dx * 10 end
--			local f = edit.frame + dx
--			if ctrl and edit.current_anim then
--				local a = edit.current_anim
--				f = a.start + (f - a.start) % (a.stop - a.start)
--			end
--			edit:set_frame(f)
--		end
--		if not gui.active_item and gui:mouse_in_box(box) and gui.is_mouse_down then
--			edit:set_frame(math.floor((gui.mx - box.x - 5) / 10 + 0.5))
--		end
--
--		G.setScissor(box.x, box.y, box.w, box.h)
--		G.push()
--		G.translate(box.x, box.y)
--
--		local is_keyframe = {}
--		for _, b in ipairs(model.bones) do
--			for _, k in ipairs(b.keyframes) do
--				is_keyframe[k[1]] = true
--			end
--		end
--
--		G.setColor(0.39, 0.39, 0.39, 0.78)
--		G.rectangle("fill", 0, 0, box.w, box.h)
--
--		-- current frame
--		G.setColor(0, 1, 0)
--		local x = 5 + edit.frame * 10
--		G.line(x, 0, x, 45)
--
--		-- animations
--		G.setColor(0, 1, 0, 0.59)
--		for _, a in ipairs(model.anims) do
--			local x1 = 5 + a.start * 10
--			local x2 = 5 + a.stop * 10
--			G.rectangle("fill", x1, 5, x2 - x1, 10)
--		end
--
--		-- lines
--		local i = 0
--		for x = 5, box.w, 10 do
--			G.setColor(1, 1, 1)
--			if i % 10 == 0 then
--				G.line(x, 35, x, 45)
--				G.printf(i, x - 50, 18, 100, "center")
--			else
--				G.line(x, 40, x, 45)
--			end
--
--			-- keyframe
--			if is_keyframe[i] then
--				G.setColor(1, 0.78, 0.39)
--				G.circle("fill", x, 10, 5, 4)
--			end
--			i = i + 1
--		end
--
--		G.pop()
--		G.setScissor()
--
--		-- play
--		local t = { edit.is_playing }
--		gui:radio_button("stop", false, t)
--		gui:same_line()
--		gui:radio_button("play", true, t)
--		gui:same_line()
--		if edit.is_playing ~= t[1]
--		or gui.was_key_pressed["space"] then
--			edit:set_playing(not edit.is_playing)
--		end
--		gui:separator()
--
--		-- animation
--		local t = edit.current_anim or edit
--		gui:item_min_size(400, 0)
--		gui:drag_value("animation speed", t, "speed", 0.01, 0.01, 1, "%.2f")
--		gui:same_line()
--		gui:separator()
--
--		-- keyframe buttons
--		gui:text("keyframe:")
--		gui:same_line()
--		if gui:button("insert") or gui.was_key_pressed["i"] then
--			model:insert_keyframe(edit.frame)
--		end
--		gui:same_line()
--		if gui:button("copy") then
--			model:copy_keyframe(edit.frame)
--		end
--		gui:same_line()
--		if gui:button("paste") then
--			model:paste_keyframe(edit.frame)
--		end
--		gui:same_line()
--		local alt = love.keyboard.isDown("lalt", "ralt")
--		if gui:button("delete")
--		or (gui.was_key_pressed["i"] and alt) then
--			model:delete_keyframe(edit.frame)
--		end
--
	end


--	-- background
--	gui:select_win(2)
--	gui:item_min_size(600, 0)
--	gui:drag_value("x", bg, "x", 10, -8000, 0, "%d")
--	gui:item_min_size(600, 0)
--	gui:drag_value("y", bg, "y", 10, -4000, 0, "%d")
--	gui:item_min_size(600, 0)
--	gui:drag_value("scale", bg, "scale", 1, 1, 10, "%d")

	edit.mode:do_gui()

	gui:end_frame()
end

--bg = {
--	enabled = false,
--	img = G.newImage("super_turri_2.png"),
--	x = -140,
--	y = -392,
--	scale = 8,
--}
--bg.img:setFilter("nearest", "nearest")


local function draw_concav_poly(p)
	if #p < 6 then return end
	local status, err = pcall(function()
		local tris = love.math.triangulate(p)
		for _, t in ipairs(tris) do G.polygon("fill", t) end
	end)
	if not status then
		print(err)
	end
end
function love.draw()
	G.translate(G.getWidth() / 2, G.getHeight() / 2)
	G.scale(1 / cam.zoom)
	G.translate(-cam.x, -cam.y)
	G.setLineWidth(cam.zoom)

	-- axis and grid
	do
		G.setColor(1, 1, 1, 0.2)
		G.line(-1000, 0, 1000, 0)
		G.line(0, -1000, 0, 1000)

		if edit.show_grid then
			for x = -1000, 1000, 100 do
				G.line(x, -1000, x, 1000)
			end
			for y = -1000, 1000, 100 do
				G.line(-1000, y, 1000, y)
			end

			-- fine grid
			if cam.zoom < 1 then
				local d = 10
				local x1 = math.floor((cam.x - cam.zoom * G.getWidth() / 2) / d) * d
				local y1 = math.floor((cam.y - cam.zoom * G.getHeight() / 2) / d) * d
				local x2 = cam.x + cam.zoom * G.getWidth() / 2
				local y2 = cam.y + cam.zoom * G.getHeight() / 2

				for x = x1, x2, d do
					G.line(x, y1, x, y2)
				end
				for y = y1, y2, d do
					G.line(x1, y, x2, y)
				end
			end
		end
	end


	-- polys
	for _, p in ipairs(model.polys) do
		local c = colors[p.color]
		local s = p.shade
		G.setColor(c[1] * s, c[2] * s, c[3] * s)
		if edit.show_fill then
			draw_concav_poly(p.data)
		else
			G.polygon("line", p.data)
		end
	end

	-- bone
	if edit.show_bones then
		for _, b in ipairs(model.bones) do
			if b.parent then
				local dx = b.global_x - b.parent.global_x
				local dy = b.global_y - b.parent.global_y
				local l = length(dx, dy) * 0.1 / cam.zoom
				G.setColor(0.4, 0.6, 0.8, 0.6)
				G.polygon("fill",
					b.parent.global_x + dy / l,
					b.parent.global_y - dx / l,
					b.parent.global_x - dy / l,
					b.parent.global_y + dx / l,
					b.global_x,
					b.global_y)
			end
		end
	end

	-- joint
	if edit.show_joints then
		for _, b in ipairs(model.bones) do
			G.setColor(1, 1, 1, 0.6)
			G.circle("fill", b.global_x, b.global_y, 5 * cam.zoom)
		end
	end

	-- selected
	local b = edit.modes.bone.selected_bone
	G.setColor(1, 1, 0, 0.6)
	G.circle("fill", b.global_x, b.global_y, 10 * cam.zoom)


	local m = edit.mode
	if m == edit.modes.mesh then

		local poly = model.polys[m.poly_index]
		if poly then

			-- selected poly
			G.setColor(1, 1, 1, 0.75)
			G.polygon("line", poly.data)

			G.setColor(1, 1, 1)
			G.setPointSize(5)
			G.points(poly.data)

			-- selected vertices
			local s = {}
			for _, i in ipairs(m.selected_vertices) do
				s[#s + 1] = poly.data[i]
				s[#s + 1] = poly.data[i + 1]
			end
			G.setColor(1, 1, 0)
			G.setPointSize(7)
			G.points(s)

			-- selection box
			if m.sx then
				G.setColor(0.7, 0.7, 0.7)
				G.rectangle("line", m.sx, m.sy, edit.mx - m.sx, edit.my - m.sy)
			end

			-- parent bone
			if poly.bone then
				G.setColor(1, 1, 0)
				G.setLineWidth(cam.zoom * 2)
				G.circle("line", poly.bone.global_x, poly.bone.global_y, 13 * cam.zoom)
			end
		end
	end



--	if bg.enabled then
--		G.setColor(1, 1, 1, 0.27)
--		G.draw(bg.img, bg.x, bg.y, 0, bg.scale)
--	end

	do_gui()
end
