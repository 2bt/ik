require("model")


function Bone:delete_kid(kid)
	for i, k in ipairs(self.kids) do
		if k == kid then
			table.remove(self.kids, i)
			break
		end
	end
end


local keyframe_buffer = {}

function Model:add_bone(b)
	table.insert(self.bones, b)
end
function Model:delete_bone(b)
	keyframe_buffer = {}
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
function Model:change_bone_layer(b, d)
	if d ~= 1 and d ~= -1 then return end
	keyframe_buffer = {}
	for i, p in ipairs(self.bones) do
		if p == b then
			if self.bones[i + d] then
				self.bones[i + d], self.bones[i] = self.bones[i], self.bones[i + d]
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
		anims = self.anims,
	}
	for _, b in ipairs(self.bones) do
		local d = {
			x         = b.x,
			y         = b.y,
			ang       = b.ang,
			parent    = order[b.parent],
			shade     = b.shade,
		}
		if #b.poly > 0 then d.poly = b.poly end
		if #b.keyframes > 0 then d.keyframes = b.keyframes end
		table.insert(data.bones, d)
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
