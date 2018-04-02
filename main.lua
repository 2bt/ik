require("helper")
require("fancymodel")
require("gui")


colors = {
	{ 0x00, 0x00, 0x00 },
	{ 0xFF, 0xFF, 0xFF },
	{ 0x68, 0x37, 0x2B },
	{ 0x70, 0xA4, 0xB2 },
	{ 0x6F, 0x3D, 0x86 },
	{ 0x58, 0x8D, 0x43 },
	{ 0x35, 0x28, 0x79 },
	{ 0xB8, 0xC7, 0x6F },
	{ 0x6F, 0x4F, 0x25 },
	{ 0x43, 0x39, 0x00 },
	{ 0x9A, 0x67, 0x59 },
	{ 0x44, 0x44, 0x44 },
	{ 0x6C, 0x6C, 0x6C },
	{ 0x9A, 0xD2, 0x84 },
	{ 0x6C, 0x5E, 0xB5 },
	{ 0x95, 0x95, 0x95 },
}


G = love.graphics
love.keyboard.setKeyRepeat(true)

model = Model()
--model:load("save")
--model.anims = {
--	{
--		start = 10,
--		stop  = 20,
--		loop  = true,
--		speed = 0.1,
--	}
--}

cam = {
	x    = 0,
	y    = -150,
	zoom = 1,
}
edit = {
	file_name         = "save.model",
	is_playing        = false,
	speed             = 0.5,
	frame             = 0,

	show_fill         = true,
	show_grid         = true,
	show_bones        = true,
	show_joints       = true,

	mode              = "bone",
	ik_length         = 2,
	poly              = {},
	selected_vertices = {},
	selected_bone     = model.root,

	bone_buffer	      = nil,
}


if arg[2] then
	edit.file_name = arg[2]
	model:load(edit.file_name)
	edit.selected_bone = model.root
end


function edit:set_frame(f)
	if self.mode == "mesh" then self:toggle_mode() end
	self.frame = math.max(0, f)
	model:set_frame(self.frame)

	self.current_anim = nil
	for _, a in ipairs(model.anims) do
		if self.frame >= a.start
		and self.frame < a.stop then
			self.current_anim = a
			break
		end
	end

end
function edit:update_frame()
	if not self.is_playing then return end
	local f = self.frame + self.speed
	if self.current_anim then
		f = self.frame + self.current_anim.speed
		if f >= self.current_anim.stop then
			if self.current_anim.loop then
				f = self.current_anim.start + f - self.current_anim.stop
			else
				f = self.current_anim.start
				self.is_playing = false
			end
		end
	end
	self:set_frame(f)
end
function edit:set_playing(p)
	self.is_playing = p
	if self.is_playing then
		if self.mode == "mesh" then self:toggle_mode() end
	else
		self:set_frame(math.floor(self.frame + 0.5))
	end
end
function edit:toggle_mode()
	self.mode = self.mode == "bone" and "mesh" or "bone"

	if self.mode == "mesh" then
		if self.is_playing then
			self.is_playing = false
			self.frame = math.floor(self.frame + 0.5)
			model:set_frame(self.frame)
		end

		-- transform poly into world space
		local b = self.selected_bone
		local si = math.sin(b.global_ang)
		local co = math.cos(b.global_ang)
		self.poly = {}
		for i = 1, #b.poly, 2 do
			self.poly[i    ] = b.global_x + b.poly[i] * co - b.poly[i + 1] * si
			self.poly[i + 1] = b.global_y + b.poly[i + 1] * co + b.poly[i] * si
		end

	elseif self.mode == "bone" then

		-- transform poly back into bone space
		local b = self.selected_bone
		local si = math.sin(b.global_ang)
		local co = math.cos(b.global_ang)
		b.poly = {}
		for i = 1, #self.poly, 2 do
			local dx = self.poly[i    ] - b.global_x
			local dy = self.poly[i + 1] - b.global_y
			b.poly[i    ] = dx * co + dy * si
			b.poly[i + 1] = dy * co - dx * si
		end
		self.poly = {}
		self.selected_vertices = {}
	end
end


function love.wheelmoved(_, y)
	if gui:wheelmoved(y) then return end
	cam.zoom = cam.zoom * (0.9 ^ y)
end


function love.keypressed(k)
	gui:keypressed(k)

	if k == "x" and edit.mode == "mesh" then
		-- delete selected vertice
		for j = #edit.selected_vertices, 1, -1 do
			local i = edit.selected_vertices[j]
			table.remove(edit.poly, i)
			table.remove(edit.poly, i)
		end
		edit.selected_vertices = {}

	elseif k == "a" and edit.mode == "mesh" then
		-- toggle select
		local v = {}
		if #edit.selected_vertices == 0 then
			for i = 1, #edit.poly, 2 do
				v[#v + 1] = i
			end
		end
		edit.selected_vertices = v
	end
end


function love.mousepressed(x, y, button)
	if edit.mode == "bone" and button == 2 then
		-- select bone
		local dist = 10
		for _, b in ipairs(model.bones) do
			local d = math.max(
				math.abs(b.global_x - edit.mx),
				math.abs(b.global_y - edit.my)) / cam.zoom
			if d < dist then
				dist = d
				edit.selected_bone = b
			end
		end

	elseif edit.mode == "bone" and button == 1 and love.keyboard.isDown("c") then
		-- add new bone
		local b = edit.selected_bone
		local si = math.sin(b.global_ang)
		local co = math.cos(b.global_ang)
		local dx = edit.mx - b.global_x
		local dy = edit.my - b.global_y
		local k = Bone(dx * co + dy * si, dy * co - dx * si)
		model:add_bone(k)
		b:add_kid(k)
		k:update()
		edit.selected_bone = k

	elseif edit.mode == "mesh" and button == 1 and love.keyboard.isDown("c") then
		-- add new vertex
		local index = 1
		local min_l = nil
		for i = 1, #edit.poly, 2 do
			local ax = edit.poly[i]
			local ay = edit.poly[i + 1]
			local bx = edit.poly[(i + 2) % #edit.poly]
			local by = edit.poly[(i + 2) % #edit.poly + 1]
			local d0 = distance(ax, ay, bx, by)
			local d1 = distance(ax, ay, edit.mx, edit.my)
			local d2 = distance(bx, by, edit.mx, edit.my)
			l = (d1 + d2) / d0
			if not min_l or l < min_l then
				min_l = l
				index = i + 2
			end
		end

		table.insert(edit.poly, index, edit.mx)
		table.insert(edit.poly, index + 1, edit.my)
	edit.selected_vertices = { index }

	elseif edit.mode == "mesh" and button == 2 then
		-- vertex selection rect
		edit.sx = edit.mx
		edit.sy = edit.my
	end
end


function love.mousereleased(x, y, button)
	if edit.mode == "mesh" and button == 2 then

		-- select vertices

		if not love.keyboard.isDown("lshift", "rshift") then
			edit.selected_vertices = {}
		end
		if edit.mx == edit.sx and edit.my == edit.sy then
			local dist = 10
			for i = 1, #edit.poly, 2 do
				local d = math.max(
					math.abs(edit.poly[i    ] - edit.mx),
					math.abs(edit.poly[i + 1] - edit.my)) / cam.zoom
				if d < dist then
					dist = d
					edit.selected_vertices[1] = i
				end
			end
		else
			min_x = math.min(edit.mx, edit.sx)
			min_y = math.min(edit.my, edit.sy)
			max_x = math.max(edit.mx, edit.sx)
			max_y = math.max(edit.my, edit.sy)

			for i = 1, #edit.poly, 2 do
				local x = edit.poly[i]
				local y = edit.poly[i + 1]
				local s = x >= min_x and x <= max_x and y >= min_y and y <= max_y
				if s then
					table.insert(edit.selected_vertices, i)
				end
			end
		end

		edit.sx = nil
		edit.sy = nil
		return
	end
end


function love.mousemoved(x, y, dx, dy)
	if gui:mousemoved(x, y, dx, dy) then return end

	edit.mx = cam.x + (x - G.getWidth() / 2) * cam.zoom
	edit.my = cam.y + (y - G.getHeight() / 2) * cam.zoom
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


	if edit.mode == "bone" then
		local function move(dx, dy)
			local b = edit.selected_bone
			local si = math.sin(b.global_ang - b.ang)
			local co = math.cos(b.global_ang - b.ang)
			b.x = b.x + dx * co + dy * si
			b.y = b.y + dy * co - dx * si
			b:update()
		end


		if love.keyboard.isDown("g") then
			-- move
			move(dx, dy)

		elseif love.keyboard.isDown("r") then
			-- rotate
			local b = edit.selected_bone
			local bx = edit.mx - b.global_x
			local by = edit.my - b.global_y
			local a = math.atan2(bx - dx, by - dy) - math.atan2(bx, by)
			if a < -math.pi then a = a + 2 * math.pi end
			if a > math.pi then a = a - 2 * math.pi end
			b.ang = b.ang + a
			b:update()

		elseif love.mouse.isDown(1) then
			-- ik
			if not edit.selected_bone.parent then
				move(dx, dy)
				return
			end

			local tx = edit.selected_bone.global_x + dx
			local ty = edit.selected_bone.global_y + dy

			local function calc_error()
				return distance(edit.selected_bone.global_x, edit.selected_bone.global_y, tx, ty)
			end

			for _ = 1, 200 do
				local delta = 0.0005

				local improve = false
				local b = edit.selected_bone
				for _ = 1, edit.ik_length do
					b = b.parent
					if not b then break end

					local e = calc_error()
					b.ang = b.ang + delta
					b:update()
					if calc_error() > e then
						b.ang = b.ang - delta * 2
						b:update()
						if calc_error() > e then
							b.ang = b.ang + delta
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

	elseif edit.mode == "mesh" then

		local function get_selection_center()
			local cx = 0
			local cy = 0
			for _, i in ipairs(edit.selected_vertices) do
				cx = cx + edit.poly[i    ]
				cy = cy + edit.poly[i + 1]
			end
			cx = cx / #edit.selected_vertices
			cy = cy / #edit.selected_vertices
			return cx, cy
		end

		if love.mouse.isDown(1) then
			-- move
			for _, i in ipairs(edit.selected_vertices) do
				edit.poly[i    ] = edit.poly[i    ] + dx
				edit.poly[i + 1] = edit.poly[i + 1] + dy
			end

		elseif love.keyboard.isDown("s") then
			-- scale
			local cx, cy = get_selection_center()
			local l1 = distance(edit.mx, edit.my, cx + dx, cy + dy)
			local l2 = distance(edit.mx, edit.my, cx, cy)
			local s = l2 / l1

			for _, i in ipairs(edit.selected_vertices) do
				edit.poly[i    ] = cx + (edit.poly[i    ] - cx) * s
				edit.poly[i + 1] = cy + (edit.poly[i + 1] - cy) * s
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

			for _, i in ipairs(edit.selected_vertices) do
				local dx = edit.poly[i    ] - cx
				local dy = edit.poly[i + 1] - cy
				edit.poly[i    ] = cx + dx * co - dy * si
				edit.poly[i + 1] = cy + dy * co + dx * si
			end

		end
	end
end



function love.update()
	edit:update_frame()
end


function do_gui()
	G.origin()
	G.setLineWidth(1)
	gui:begin_frame()

	do
		gui:select_win(1)
		local t = { edit.mode }
		gui:item_min_size(60, 0)
		gui:radio_button("bone", "bone", t)
		gui:same_line()
		gui:item_min_size(60, 0)
		gui:radio_button("mesh", "mesh", t)
		if edit.mode ~= t[1]
		or gui.was_key_pressed["tab"] then
			edit:toggle_mode()
		end
		gui:separator()

		if gui.was_key_pressed["#"] then
			local v = not edit.show_grid
			edit.show_grid   = v
			edit.show_joints = v
			edit.show_bones  = v
		end


		gui:checkbox("fill", edit, "show_fill")
		gui:checkbox("grid", edit, "show_grid")
		gui:checkbox("bones", edit, "show_bones")
		gui:checkbox("joints", edit, "show_joints")

--		if gui.was_key_pressed["1"] then
--			bg.enabled = not bg.enabled
--		end
--		gui:checkbox("image", bg, "enabled")


		gui:item_min_size(125, 0)
		gui:drag_value("IK chain", edit, "ik_length", 1, 2, 5, "%d")

		gui:separator()

		if edit.mode == "bone" then

			gui:item_min_size(125, 0)
			gui:drag_value("shade", edit.selected_bone, "shade", 0.05, 0.3, 1.3, "%.2f")

			gui:item_min_size(125, 0)
			gui:drag_value("color", edit.selected_bone, "color", 1, 1, 16, "%d")

			gui:item_min_size(60, 0)
			if gui:button("to front") then
				model:change_bone_layer(edit.selected_bone, 1)
			end
			gui:same_line()
			gui:item_min_size(60, 0)
			if gui:button("to back") then
				model:change_bone_layer(edit.selected_bone, -1)
			end


--			-- copy bone pos
--			if true then
--				gui:item_min_size(125, 0)
--				if gui:button("copy bone pos")
--				or gui.was_key_pressed["q"] then
--					qqq = {
--						edit.selected_bone.x,
--						edit.selected_bone.y,
--					}
--				end
--				gui:item_min_size(125, 0)
--				if gui:button("paste bone pos")
--				or gui.was_key_pressed["w"] then
--					if qqq then
--						edit.selected_bone.x = qqq[1]
--						edit.selected_bone.y = qqq[2]
--						edit.selected_bone:update()
--					end
--				end
--			end


			-- duplicate bone
			local function duplicate(b, p)
				local k = Bone(b.x, b.y, b.rot)
				k.poly      = { unpack(b.poly) }
				k.keyframes = {}
				k.shade     = b.shade
				k.color     = b.color
				if p then p:add_kid(k) end
				for i, l in ipairs(b.kids) do
					duplicate(l, k)
				end
				return k
			end
			gui:item_min_size(60, 0)
			if gui:button("copy") then
				edit.bone_buffer = duplicate(edit.selected_bone, nil)
			end
			gui:same_line()
			gui:item_min_size(60, 0)
			if gui:button("paste") and edit.bone_buffer then
				edit.selected_bone = duplicate(edit.bone_buffer, edit.selected_bone)
				local function add_bones(p)
					model:add_bone(p)
					for _, k in ipairs(p.kids) do add_bones(k) end
				end
				add_bones(edit.selected_bone)
				edit.selected_bone:update()
			end

			gui:item_min_size(125, 0)
			if gui:button("delete")
			or gui.was_key_pressed["x"] then
				-- delete bone
				if edit.selected_bone.parent then
					local k = edit.selected_bone
					edit.selected_bone = k.parent
					edit.selected_bone:delete_kid(k)
					model:delete_bone(k)
				end
			end

		end


		local b = edit.selected_bone
		gui:text("x: %.2f", b.x)
		gui:text("y: %.2f", b.y)
		gui:text("a: %.2f°", b.ang * 180 / math.pi)
		gui:text("gx: %.2f", b.global_x)
		gui:text("gy: %.2f", b.global_y)
	end

	local ctrl = love.keyboard.isDown("lctrl", "rctrl")
	local shift = love.keyboard.isDown("lshift", "rshift")

	do
		gui:select_win(2)
		if gui:button("new")
		or (gui.was_key_pressed["n"] and ctrl) then
			if edit.mode == "mesh" then edit:toggle_mode() end
			model:reset()
			edit.selected_bone = model.root
		end
		gui:same_line()
		if gui:button("load")
		or (gui.was_key_pressed["l"] and ctrl) then
			if edit.mode == "mesh" then edit:toggle_mode() end
			if model:load(edit.file_name) then
				print("model loaded")
			else
				print("error loading model")
			end
			edit.selected_bone = model.root
		end
		gui:same_line()
		if gui:button("save")
		or (gui.was_key_pressed["s"] and ctrl) then
			if edit.mode == "mesh" then edit:toggle_mode() end
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
		gui:select_win(3)

		-- timeline
		local w = gui.current_window.columns[1].max_x - gui.current_window.max_cx - 5
		local box = gui:item_box(w, 45)

		-- change frame
		if gui.was_key_pressed["backspace"] then
			if edit.current_anim then
				edit:set_frame(edit.current_anim.start)
			else
				edit:set_frame(0)
			end
		end
		local dx = (gui.was_key_pressed["right"] and 1 or 0)
				- (gui.was_key_pressed["left"] and 1 or 0)
		if dx ~= 0 then
			if shift then dx = dx * 10 end
			local f = edit.frame + dx
			if ctrl and edit.current_anim then
				local a = edit.current_anim
				f = a.start + (f - a.start) % (a.stop - a.start)
			end
			edit:set_frame(f)
		end
		if not gui.active_item and gui:mouse_in_box(box) and gui.is_mouse_down then
			edit:set_frame(math.floor((gui.mx - box.x - 5) / 10 + 0.5))
		end

		G.setScissor(box.x, box.y, box.w, box.h)
		G.push()
		G.translate(box.x, box.y)

		local is_keyframe = {}
		for _, b in ipairs(model.bones) do
			for _, k in ipairs(b.keyframes) do
				is_keyframe[k[1]] = true
			end
		end

		G.setColor(100, 100, 100, 200)
		G.rectangle("fill", 0, 0, box.w, box.h)

		-- current frame
		G.setColor(0, 255, 0)
		local x = 5 + edit.frame * 10
		G.line(x, 0, x, 45)

		-- animations
		G.setColor(0, 255, 0, 150)
		for _, a in ipairs(model.anims) do
			local x1 = 5 + a.start * 10
			local x2 = 5 + a.stop * 10
			G.rectangle("fill", x1, 5, x2 - x1, 10)
		end

		-- lines
		local i = 0
		for x = 5, box.w, 10 do
			G.setColor(255, 255, 255)
			if i % 10 == 0 then
				G.line(x, 35, x, 45)
				G.printf(i, x - 50, 18, 100, "center")
			else
				G.line(x, 40, x, 45)
			end

			-- keyframe
			if is_keyframe[i] then
				G.setColor(255, 200, 100)
				G.circle("fill", x, 10, 5, 4)
			end
			i = i + 1
		end

		G.pop()
		G.setScissor()

		-- play
		local t = { edit.is_playing }
		gui:radio_button("stop", false, t)
		gui:same_line()
		gui:radio_button("play", true, t)
		gui:same_line()
		if edit.is_playing ~= t[1]
		or gui.was_key_pressed["space"] then
			edit:set_playing(not edit.is_playing)
		end
		gui:separator()

		-- animation
		local t = edit.current_anim or edit
		gui:item_min_size(400, 0)
		gui:drag_value("animation speed", t, "speed", 0.01, 0.01, 1, "%.2f")
		gui:same_line()
		gui:separator()

		-- keyframe buttons
		gui:text("keyframe:")
		gui:same_line()
		if gui:button("insert") or gui.was_key_pressed["i"] then
			model:insert_keyframe(edit.frame)
		end
		gui:same_line()
		if gui:button("copy") then
			model:copy_keyframe(edit.frame)
		end
		gui:same_line()
		if gui:button("paste") then
			model:paste_keyframe(edit.frame)
		end
		gui:same_line()
		local alt = love.keyboard.isDown("lalt", "ralt")
		if gui:button("delete")
		or (gui.was_key_pressed["i"] and alt) then
			model:delete_keyframe(edit.frame)
		end

	end


--	-- background
--	gui:select_win(2)
--	gui:item_min_size(600, 0)
--	gui:drag_value("x", bg, "x", 10, -8000, 0, "%d")
--	gui:item_min_size(600, 0)
--	gui:drag_value("y", bg, "y", 10, -4000, 0, "%d")
--	gui:item_min_size(600, 0)
--	gui:drag_value("scale", bg, "scale", 1, 1, 10, "%d")

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
		G.setColor(255, 255, 255, 50)
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

	-- mesh
	for _, b in ipairs(model.bones) do
		if #b.poly >= 3 then
			if b ~= edit.selected_bone or edit.mode ~= "mesh" then
				G.push()
				G.translate(b.global_x, b.global_y)
				G.rotate(b.global_ang)
				local c = colors[b.color]
				local s = b.shade
				G.setColor(c[1] * s, c[2] * s, c[3] * s)
				if edit.show_fill then
					draw_concav_poly(b.poly)
					local s = b.shade * 0.9
					G.setColor(c[1] * s, c[2] * s, c[3] * s)
				end
				G.polygon("line", b.poly)
				G.pop()
			end
		end
	end

	-- bone
	if edit.show_bones then
		for _, b in ipairs(model.bones) do
			if b.parent then
				local dx = b.global_x - b.parent.global_x
				local dy = b.global_y - b.parent.global_y
				local l = length(dx, dy) * 0.1 / cam.zoom
				G.setColor(100, 150, 200, 150)
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
			if b == edit.selected_bone then
				G.setColor(255, 255, 0, 150)
				G.circle("fill", b.global_x, b.global_y, 10 * cam.zoom)
			end
			G.setColor(255, 255, 255, 150)
			G.circle("fill", b.global_x, b.global_y, 5 * cam.zoom)
		end
	end


	if edit.mode == "mesh" then

		-- mesh
		if #edit.poly >= 6 then
			G.setColor(200, 100, 100, 150)
			draw_concav_poly(edit.poly)
			G.setColor(255, 255, 255, 150)
			G.polygon("line", edit.poly)
		end
		G.setColor(255, 255, 255, 150)
		G.setPointSize(5)
		G.points(edit.poly)

		-- selected vertices
		local s = {}
		for _, i in ipairs(edit.selected_vertices) do
			s[#s + 1] = edit.poly[i]
			s[#s + 1] = edit.poly[i + 1]
		end
		G.setColor(255, 255, 0)
		G.setPointSize(7)
		G.points(s)

		-- selection box
		if edit.sx then
			G.setColor(200, 200, 200)
			G.rectangle("line", edit.sx, edit.sy, edit.mx - edit.sx, edit.my - edit.sy)
		end
	end


--	if bg.enabled then
--		G.setColor(255, 255, 255, 70)
--		G.draw(bg.img, bg.x, bg.y, 0, bg.scale)
--	end

	do_gui()
end
