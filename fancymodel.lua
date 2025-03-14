require("model")


local keyframe_buffer = {}

function Model:add_bone(b)
    table.insert(self.bones, b)
    b.i = #self.bones
    for _, k in ipairs(b.kids) do self:add_bone(k) end
end
local function transform_to_global_space(points, bone)
    local p = {}
    local si = math.sin(bone.global_a)
    local co = math.cos(bone.global_a)
    for i = 1, #points, 2 do
        local x = points[i    ]
        local y = points[i + 1]
        p[i    ] = bone.global_x + x * co - y * si
        p[i + 1] = bone.global_y + y * co + x * si
    end
    return p
end
function Model:delete_bone(b)
    keyframe_buffer = {}
    for _, p in ipairs(self.polys) do
        if p.bone == b then
            p.bone = nil
            p.data = transform_to_global_space(p.data, b)
        end
    end
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
    for i, b in ipairs(self.bones) do
        b.i = i
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
            x      = b.x,
            y      = b.y,
            a      = b.a,
            parent = order[b.parent],
        }
        if #b.keyframes > 0 then d.keyframes = b.keyframes end
        data.bones[i] = d
    end
    local file = io.open(name, "w")
    file:write(table.tostring(data) .. "\n")
    file:close()
end

-- keyframe stuff
function Bone:insert_keyframe(frame)
    local kf
    for i, k in ipairs(self.keyframes) do
        if k[1] == frame then
            kf = k
            break
        end
        if k[1] > frame then
            kf = { frame }
            table.insert(self.keyframes, i, kf)
            break
        end
    end
    if not kf then
        kf = { frame }
        table.insert(self.keyframes, kf)
    end
    kf[2] = self.x
    kf[3] = self.y
    kf[4] = self.a
end
function Model:insert_keyframe(frame)
    for _, b in ipairs(self.bones) do
        b:insert_keyframe(frame)
    end
end
function Bone:delete_keyframe(frame)
    for i, k in ipairs(self.keyframes) do
        if k[1] == frame then
            table.remove(self.keyframes, i)
            break
        end
    end
end
function Model:delete_keyframe(frame)
    for _, b in ipairs(self.bones) do
        b:delete_keyframe(frame)
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

local keyframe_buffer_x = {}
function Model:copy_keyframe_x(frame, bone)
    keyframe_buffer_x = {}
    local function cp(bone)
        for _, k in ipairs(bone.keyframes) do
            if k[1] == frame then
                table.insert(keyframe_buffer_x, { k[2], k[3], k[4] })
                break
            end
        end
        for _, b in ipairs(bone.kids) do cp(b) end
    end
    cp(bone)
end
function Model:paste_keyframe_x(frame, bone)
    local index = 1
    local function pst(bone)
        local q = keyframe_buffer_x[index]
        if not q then
            print("WARNING: not enough bones copied")
            return
        end
        index = index + 1
        local kf
        for j, k in ipairs(bone.keyframes) do
            if k[1] == frame then
                kf = k
                break
            end
            if k[1] > frame then
                kf = { frame }
                table.insert(bone.keyframes, j, kf)
                break
            end
        end
        if not kf then
            kf = { frame }
            table.insert(bone.keyframes, kf)
        end
        kf[2] = q[1]
        kf[3] = q[2]
        kf[4] = q[3]

        for _, b in ipairs(bone.kids) do pst(b) end
    end
    pst(bone)
    self:set_frame(frame)
end
