-- FTF ESP (F6 to toggle)

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local espObjects = {}
local enabled = true
local keyHeld = false
local lastMapCount = 0
local maxDist = 5000

local function isBeast(player)
    if not player or not player.Character then
        return false
    end

    for _, obj in pairs(player.Character:GetChildren()) do
        if (obj.Name == "Hammer" or string.find(obj.Name, "Hammer")) and not string.find(obj.Name, "Packed") then
            return true
        end
    end

    if player:FindFirstChild("Backpack") then
        for _, tool in pairs(player.Backpack:GetChildren()) do
            if tool.Name == "Hammer" or string.find(tool.Name, "Hammer") then
                return true
            end
        end
    end

    return false
end

local function createESP(obj, name, color, objType, player, part)
    local id = tostring(obj.Address)
    if espObjects[id] then
        return
    end

    local label = Drawing.new("Text")
    label.Text = name
    label.Color = color
    label.Size = 14
    label.Center = true
    label.Outline = true
    label.Font = Drawing.Fonts.Monospace
    label.Visible = false

    espObjects[id] = {
        label = label,
        name = name,
        object = obj,
        objType = objType,
        player = player,
        part = part,
        color = color,
        isActive = true
    }
end

local function scanPlayers()
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= Players.LocalPlayer and player.Character then
            local hrp = player.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local id = tostring(hrp.Address)
                if not espObjects[id] then
                    local beast = isBeast(player)
                    local color = beast and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(50, 255, 100)
                    local name = (beast and "[BEAST] " or "") .. player.Name
                    createESP(hrp, name, color, "player", player, hrp)
                end
            end
        end
    end
end

local function scanComputers()
    local function scan(parent, depth)
        if depth > 5 then
            return
        end

        for _, obj in pairs(parent:GetChildren()) do
            local name = obj.Name:lower()
            if (string.find(name, "computertable") or string.find(name, "computerdesk")) and obj:IsA("Model") and not string.find(name, "trigger") then
                local id = tostring(obj.Address)
                if not espObjects[id] then
                    local part = obj:FindFirstChildWhichIsA("BasePart", true)
                    if part then
                        local hasTrigger = false
                        for _, child in pairs(obj:GetDescendants()) do
                            if child:IsA("BasePart") and string.find(child.Name:lower(), "trigger") then
                                hasTrigger = true
                                break
                            end
                        end
                        if hasTrigger then
                            createESP(obj, "Computer", Color3.fromRGB(0, 200, 255), "computer", nil, part)
                        end
                    end
                end
            end

            if obj:IsA("Folder") or obj:IsA("Model") then
                scan(obj, depth + 1)
            end
        end
    end

    scan(Workspace, 0)
end

local function updateESP()
    local char = Players.LocalPlayer.Character
    if not char then
        return
    end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return
    end
    local playerPos = hrp.Position

    for id, data in pairs(espObjects) do
        if not data.object or not data.object.Parent or not enabled then
            data.label.Visible = false
        else
            local pos = nil

            if data.objType == "player" then
                local char = data.object.Parent
                if char then
                    local head = char:FindFirstChild("Head")
                    if head then
                        pos = head.Position + Vector3.new(0, 1, 0)

                        if data.player then
                            local beast = isBeast(data.player)
                            data.label.Color = beast and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(50, 255, 100)
                            data.name = (beast and "[BEAST] " or "") .. data.player.Name
                        end
                    end
                end
            elseif data.objType == "computer" then
                if data.isActive and data.part then
                    pos = data.part.Position + Vector3.new(0, 2, 0)
                end
            end

            if pos then
                local dx = playerPos.X - pos.X
                local dy = playerPos.Y - pos.Y
                local dz = playerPos.Z - pos.Z
                local dist = math.sqrt(dx*dx + dy*dy + dz*dz)

                if dist < maxDist then
                    local screenPos, onScreen = WorldToScreen(pos)
                    if onScreen and screenPos then
                        data.label.Text = data.name .. " [" .. math.floor(dist) .. "m]"
                        data.label.Position = Vector2.new(screenPos.X, screenPos.Y)
                        data.label.Visible = true
                    else
                        data.label.Visible = false
                    end
                else
                    data.label.Visible = false
                end
            else
                data.label.Visible = false
            end
        end
    end
end

local function checkComputers()
    for id, data in pairs(espObjects) do
        if data.objType == "computer" and data.object and data.object.Parent then
            local hasTrigger = false
            for _, child in pairs(data.object:GetDescendants()) do
                if string.find(child.Name:lower(), "trigger") then
                    hasTrigger = true
                    break
                end
            end
            data.isActive = hasTrigger
        end
    end
end

local function cleanup()
    for id, data in pairs(espObjects) do
        if not data.object or not data.object.Parent or (data.objType == "computer" and not data.isActive) then
            data.label:Remove()
            espObjects[id] = nil
        end
    end
end

local function checkMap()
    local count = 0
    for _, obj in pairs(Workspace:GetChildren()) do
        if (obj:IsA("Folder") or obj:IsA("Model")) and string.find(obj.Name, "by") then
            count = count + 1
        end
    end

    if count ~= lastMapCount and lastMapCount > 0 then
        for id, data in pairs(espObjects) do
            if data.objType == "computer" then
                data.label:Remove()
                espObjects[id] = nil
            end
        end
        scanComputers()
        notify("FTF ESP", "New map detected", 2)
    end
    lastMapCount = count
end

repeat wait() until Players.LocalPlayer
notify("FTF ESP", "Loaded! F6 to toggle", 3)

scanPlayers()
scanComputers()

local frame = 0
while true do
    frame = frame + 1

    if iskeypressed(0x75) then
        if not keyHeld then
            keyHeld = true
            enabled = not enabled
            notify("FTF ESP", enabled and "ON" or "OFF", 2)
        end
    else
        keyHeld = false
    end

    updateESP()

    if frame % 30 == 0 then
        checkComputers()
    end
    if frame % 60 == 0 then
        scanPlayers()
        cleanup()
    end
    if frame % 120 == 0 then
        checkMap()
    end

    wait()
end
