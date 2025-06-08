local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera

local LocalPlayer = Players.LocalPlayer

local ESP = {
    Enabled = true,
    ShowBoxes = true,
    ShowNames = true,
    ShowTracers = true,
    ShowHealth = true,
    Color = nil,
    HealthColorMode = "match",
    HealthColorFunction = nil,
}

local ESPObjects = {}

local function newDrawing(type, props)
    local obj = Drawing.new(type)
    for prop, val in pairs(props) do
        obj[prop] = val
    end
    return obj
end

local function createESPElements()
    return {
        Box = newDrawing("Square", {Visible = false, Thickness = 2, Filled = false, Color = Color3.new(1, 1, 1)}),
        Name = newDrawing("Text", {Visible = false, Center = true, Outline = true, Size = 16, Font = 2, Color = Color3.new(1, 1, 1)}),
        Tracer = newDrawing("Line", {Visible = false, Thickness = 1, Color = Color3.new(1, 1, 1)}),
        HealthBar = newDrawing("Line", {Visible = false, Thickness = 4}),
    }
end

local function getRainbowColor(t)
    local freq = 2
    return Color3.new(
        math.sin(freq * t) * 0.5 + 0.5,
        math.sin(freq * t + 2) * 0.5 + 0.5,
        math.sin(freq * t + 4) * 0.5 + 0.5
    )
end

local function getBoxScreenPoints(cframe, size)
    local half = size / 2
    local points = {}
    local visible = true
    for x = -1, 1, 2 do
        for y = -1, 1, 2 do
            for z = -1, 1, 2 do
                local corner = cframe * Vector3.new(half.X * x, half.Y * y, half.Z * z)
                local screenPos, onScreen = Camera:WorldToViewportPoint(corner)
                if not onScreen then visible = false end
                table.insert(points, Vector2.new(screenPos.X, screenPos.Y))
            end
        end
    end
    return points, visible
end

local function hideAll(data)
    data.Box.Visible = false
    data.Name.Visible = false
    data.Tracer.Visible = false
    data.HealthBar.Visible = false
end

function ESP:SetColor(color3)
    self.Color = color3
end

function ESP:SetShowBoxes(val)
    self.ShowBoxes = val
end

function ESP:SetShowNames(val)
    self.ShowNames = val
end

function ESP:SetShowTracers(val)
    self.ShowTracers = val
end

function ESP:SetShowHealth(val)
    self.ShowHealth = val
end

function ESP:SetHealthColorMode(mode)
    if mode == "match" or mode == "custom" then
        self.HealthColorMode = mode
    end
end

function ESP:SetHealthColorFunction(func)
    if typeof(func) == "function" then
        self.HealthColorFunction = func
    end
end

function ESP:Enable()
    self.Enabled = true
end

function ESP:Disable()
    self.Enabled = false
    for _, data in pairs(ESPObjects) do
        hideAll(data)
    end
end

RunService.RenderStepped:Connect(function()
    if not ESP.Enabled then
        for _, data in pairs(ESPObjects) do
            hideAll(data)
        end
        return
    end

    local now = tick()
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local character = player.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if character and humanoid and humanoid.Health > 0 then
                local success, cframe, size = pcall(character.GetBoundingBox, character)
                if success and cframe and size then
                    local points, visible = getBoxScreenPoints(cframe, size)
                    if not visible then
                        if ESPObjects[player] then hideAll(ESPObjects[player]) end
                        continue
                    end

                    local data = ESPObjects[player] or createESPElements()
                    ESPObjects[player] = data

                    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
                    for _, pt in ipairs(points) do
                        minX, minY = math.min(minX, pt.X), math.min(minY, pt.Y)
                        maxX, maxY = math.max(maxX, pt.X), math.max(maxY, pt.Y)
                    end

                    local boxWidth, boxHeight = maxX - minX, maxY - minY
                    local slimWidth = boxWidth * 0.7
                    local slimX = minX + (boxWidth - slimWidth) / 2
                    local healthRatio = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)

                    local baseColor = ESP.Color or getRainbowColor(now)

                    if ESP.ShowBoxes then
                        data.Box.Visible = true
                        data.Box.Position = Vector2.new(slimX, minY)
                        data.Box.Size = Vector2.new(slimWidth, boxHeight)
                        data.Box.Color = baseColor
                    else
                        data.Box.Visible = false
                    end

                    if ESP.ShowNames then
                        data.Name.Visible = true
                        data.Name.Text = player.Name
                        data.Name.Position = Vector2.new(slimX + slimWidth / 2, minY - 20)
                        data.Name.Color = baseColor
                    else
                        data.Name.Visible = false
                    end

                    if ESP.ShowTracers then
                        data.Tracer.Visible = true
                        data.Tracer.From = screenCenter
                        data.Tracer.To = Vector2.new(slimX + slimWidth / 2, maxY)
                        data.Tracer.Color = baseColor
                    else
                        data.Tracer.Visible = false
                    end

                    if ESP.ShowHealth then
                        local barHeight = boxHeight * healthRatio
                        data.HealthBar.Visible = true
                        data.HealthBar.From = Vector2.new(slimX - 6, maxY)
                        data.HealthBar.To = Vector2.new(slimX - 6, maxY - barHeight)

                        if ESP.HealthColorMode == "match" then
                            data.HealthBar.Color = baseColor
                        elseif ESP.HealthColorMode == "custom" and ESP.HealthColorFunction then
                            data.HealthBar.Color = ESP.HealthColorFunction(healthRatio)
                        else
                            data.HealthBar.Color = Color3.new(1, 0, 0)
                        end
                    else
                        data.HealthBar.Visible = false
                    end
                end
            else
                if ESPObjects[player] then
                    hideAll(ESPObjects[player])
                end
            end
        end
    end
end)

Players.PlayerRemoving:Connect(function(player)
    if ESPObjects[player] then
        for _, obj in pairs(ESPObjects[player]) do
            obj:Remove()
        end
        ESPObjects[player] = nil
    end
end)

_G.ESP = ESP
