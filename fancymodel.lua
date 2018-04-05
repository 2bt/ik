require("model")


local keyframe_buffer = {}

function Model:add_bone(b)
	table.insert(self.bones, b)
	for _, k in ipairs(b.kids) do self:add_bone(k) end
end
function Model:delete_bone(b)
	keyframe_buffer = {}
	for i, k in ipairs(b.parent.kids) do
		if k == b then
			table.remove(b.parent.kids, i)
			break
		end
	end
	for i, p in ipairs(self.bones) do
		if p == b then
			table.remove(self.bones, i)
			for _, k in ipairs(b.kids) do
				self:delete_bone(k)
			end
			break
		end
	end
end
function Model:save(name)
	local order = {}
	for i, b in ipairs(self.bones) do order[b] = i end
	local data = {
		bones = {},
		polys = {},
		anims = self.anims,
	}
	for i, p in ipairs(self.polys) do
		data.polys[i] = {
			data  = p.data,
			color = p.color,
			shade = p.shade,
			bone  = order[p.bone],
		}
	end
	for i, b in ipairs(self.bones) do
		local d = {
			x         = b.x,
			y         = b.y,
			ang       = b.ang,
			parent    = order[b.parent],
		}
		if #b.keyframes > 0 then d.keyframes = b.keyframes end
		data.bones[i] = d
	end
	local file = io.open(name, "w")
	file:write(table.tostring(data) .. "\n")
	file:close()
end

-- keyframe stuff
function Model:insert_keyframe(frame)
	for _, b in ipairs(self.bones) do
		local kf
		for i, k in ipairs(b.keyframes) do
			if k[1] == frame then
				kf = k
				break
			end
			if k[1] > frame then
				kf = { frame }
				table.insert(b.keyframes, i, kf)
				break
			end
		end
		if not kf then
			kf = { frame }
			table.insert(b.keyframes, kf)
		end
		kf[2] = b.x
		kf[3] = b.y
		kf[4] = b.ang
	end
end
function Model:delete_keyframe(frame)
	for _, b in ipairs(self.bones) do
		for i, k in ipairs(b.keyframes) do
			if k[1] == frame then
				table.remove(b.keyframes, i)
				break
			end
		end
	end
end
function Model:copy_keyframe(frame)
	keyframe_buffer = {}
	for _, b in ipairs(self.bones) do
		for _, k in ipairs(b.keyframes) do
			if k[1] == frame then
				table.insert(keyframe_buffer, { k[2], k[3], k[4] })
				break
			end
		end
	end
end
function Model:paste_keyframe(frame)
	for i, b in ipairs(self.bones) do
		local q = keyframe_buffer[i]
		if not q then break end
		local kf
		for j, k in ipairs(b.keyframes) do
			if k[1] == frame then
				kf = k
				break
			end
			if k[1] > frame then
				kf = { frame }
				table.insert(b.keyframes, j, kf)
				break
			end
		end
		if not kf then
			kf = { frame }
			table.insert(b.keyframes, kf)
		end
		kf[2] = q[1]
		kf[3] = q[2]
		kf[4] = q[3]
	end
	self:set_frame(frame)
end
