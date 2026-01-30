local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'
local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local ESPObjects = {}
local AimbotTarget = nil
local AimbotActive = false
local AimbotKeyActive = false
local LastShotTime = 0
local HBESize = 30
local OriginalWalkSpeed = 16

-- ScreenGui para el ESP
local ScreenGui = Instance.new('ScreenGui', game:GetService('CoreGui'))
ScreenGui.Name = 'ESPGui'
ScreenGui.ResetOnSpawn = false

-- Función para obtener el equipo de un jugador usando atributo
local function GetPlayerTeam(player)
    if player and player.Character then
        return player:GetAttribute("Team") or nil
    end
    return nil
end

-- Función para verificar si el jugador es del mismo equipo
local function IsTeammate(player)
    if not player or not player.Character then return false end
    
    local localPlayerTeam = GetPlayerTeam(LocalPlayer)
    local targetPlayerTeam = GetPlayerTeam(player)
    
    -- Si ambos tienen equipo y son iguales, son teammates
    if localPlayerTeam and targetPlayerTeam and localPlayerTeam == targetPlayerTeam then
        return true
    end
    
    return false
end

-- Función para verificar si hay pared entre jugador y objetivo
local function HasWallBetween(targetPart)
    if not targetPart then return true end
    
    local camera = workspace.CurrentCamera
    local ray = Ray.new(camera.CFrame.Position, (targetPart.Position - camera.CFrame.Position).Unit * 1000)
    local hitPart = workspace:FindPartOnRayWithIgnoreList(ray, {LocalPlayer.Character})
    
    if hitPart == targetPart or (AimbotTarget and AimbotTarget.Character and AimbotTarget.Character:IsAncestorOf(hitPart)) then
        return false
    end
    
    return true
end

-- Función para obtener el jugador más cercano (Mouse Aimbot)
local function GetClosestPlayerMouse()
    local closestPlayer = nil
    local shortestDistance = math.huge
    
    local mouse = UserInputService:GetMouseLocation()
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and not IsTeammate(player) then
            local humanoidRootPart = player.Character:FindFirstChild("HumanoidRootPart")
            local humanoid = player.Character:FindFirstChild("Humanoid")
            
            if humanoidRootPart and humanoid and humanoid.Health > 0 then
                local vector, onScreen = workspace.CurrentCamera:WorldToViewportPoint(humanoidRootPart.Position)
                
                if onScreen then
                    local distance = (Vector2.new(mouse.X, mouse.Y) - Vector2.new(vector.X, vector.Y)).Magnitude
                    local maxFOV = Options.AimbotFOV and Options.AimbotFOV.Value or 150
                    
                    if distance < maxFOV and distance < shortestDistance then
                        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                            local distanceFromPlayer = (LocalPlayer.Character.HumanoidRootPart.Position - humanoidRootPart.Position).Magnitude
                            local maxDistance = Options.AimbotMaxDistance and Options.AimbotMaxDistance.Value or 500
                            
                            if distanceFromPlayer <= maxDistance then
                                closestPlayer = player
                                shortestDistance = distance
                            end
                        end
                    end
                end
            end
        end
    end
    
    return closestPlayer
end

-- Función para obtener el jugador más cercano (Camlock - desde el centro de la pantalla)
local function GetClosestPlayerCamlock()
    local closestPlayer = nil
    local shortestDistance = math.huge
    
    local screenCenter = Vector2.new(workspace.CurrentCamera.ViewportSize.X / 2, workspace.CurrentCamera.ViewportSize.Y / 2)
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and not IsTeammate(player) then
            local humanoidRootPart = player.Character:FindFirstChild("HumanoidRootPart")
            local humanoid = player.Character:FindFirstChild("Humanoid")
            
            if humanoidRootPart and humanoid and humanoid.Health > 0 then
                local vector, onScreen = workspace.CurrentCamera:WorldToViewportPoint(humanoidRootPart.Position)
                
                if onScreen then
                    local distance = (screenCenter - Vector2.new(vector.X, vector.Y)).Magnitude
                    local maxFOV = Options.AimbotFOV and Options.AimbotFOV.Value or 150
                    
                    if distance < maxFOV and distance < shortestDistance then
                        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                            local distanceFromPlayer = (LocalPlayer.Character.HumanoidRootPart.Position - humanoidRootPart.Position).Magnitude
                            local maxDistance = Options.AimbotMaxDistance and Options.AimbotMaxDistance.Value or 500
                            
                            if distanceFromPlayer <= maxDistance then
                                closestPlayer = player
                                shortestDistance = distance
                            end
                        end
                    end
                end
            end
        end
    end
    
    return closestPlayer
end

-- Función para AutoKill
local function UpdateAutoKill()
    if not Toggles.EnableAutoKill or not Toggles.EnableAutoKill.Value then return end
    if not LocalPlayer.Character then return end
    
    local autoKillRange = Options.AutoKillRange and Options.AutoKillRange.Value or 50
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and not IsTeammate(player) then
            local humanoidRootPart = player.Character:FindFirstChild("HumanoidRootPart")
            local humanoid = player.Character:FindFirstChild("Humanoid")
            
            if humanoidRootPart and humanoid and humanoid.Health > 0 then
                local distance = (LocalPlayer.Character.HumanoidRootPart.Position - humanoidRootPart.Position).Magnitude
                
                if distance <= autoKillRange then
                    local KnifeKill = game:GetService("ReplicatedStorage"):FindFirstChild("KnifeKill")
                    if KnifeKill then
                        KnifeKill:FireServer(player)
                    end
                end
            end
        end
    end
end

-- Función de Triggerbot
local function Triggerbot()
    if not Toggles.EnableTriggerbot or not Toggles.EnableTriggerbot.Value then return end
    if not AimbotActive or not AimbotTarget then return end
    
    local targetPart = AimbotTarget.Character and AimbotTarget.Character:FindFirstChild(Options.AimbotHitbox and Options.AimbotHitbox.Value or "Head")
    if not targetPart then return end
    
    if Toggles.TriggerbotWallCheck and Toggles.TriggerbotWallCheck.Value then
        if HasWallBetween(targetPart) then
            return
        end
    end
    
    local currentTime = tick()
    local delay = (Options.TriggerbotDelay and Options.TriggerbotDelay.Value or 100) / 1000
    
    if currentTime - LastShotTime >= delay then
        mouse1press()
        task.wait(0.05)
        mouse1release()
        LastShotTime = currentTime
    end
end

-- Función para Speed Hack
local function UpdateSpeedHack()
    if not LocalPlayer.Character then return end
    
    local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    
    if Toggles.EnableSpeedHack and Toggles.EnableSpeedHack.Value then
        local speed = Options.SpeedHackSpeed and Options.SpeedHackSpeed.Value or 16
        humanoid.WalkSpeed = speed
    else
        humanoid.WalkSpeed = OriginalWalkSpeed
    end
end

-- Función para Noclip
local function UpdateNoclip()
    if not LocalPlayer.Character then return end
    
    if Toggles.EnableNoclip and Toggles.EnableNoclip.Value then
        local humanoidRootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if humanoidRootPart then
            humanoidRootPart.CanCollide = false
        end
        
        for _, part in pairs(LocalPlayer.Character:GetChildren()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    else
        local humanoidRootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if humanoidRootPart then
            humanoidRootPart.CanCollide = true
        end
        
        for _, part in pairs(LocalPlayer.Character:GetChildren()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
    end
end

-- Función para restaurar Hitbox Expander
local function RestoreHitboxExpander()
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local HRP = player.Character:FindFirstChild("HumanoidRootPart")
            if HRP then
                HRP.Size = Vector3.new(2, 2, 1)
                HRP.Transparency = 1
                local outline = HRP:FindFirstChild("SelectionBox")
                if outline then
                    outline:Destroy()
                end
            end
        end
    end
end

-- Función para actualizar Hitbox Expander
local function UpdateHitboxExpander()
    if not Toggles.EnableHBE or not Toggles.EnableHBE.Value then 
        RestoreHitboxExpander()
        return 
    end
    
    local size = Options.HBESize and Options.HBESize.Value or 30
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and not IsTeammate(player) then
            local HRP = player.Character:FindFirstChild("HumanoidRootPart")
            local humanoid = player.Character:FindFirstChild("Humanoid")
            
            if HRP and humanoid and humanoid.Health > 0 then
                HRP.Size = Vector3.new(size, size, size)
                HRP.Transparency = 0.5
                HRP.CanCollide = false
                local hbeColor = Options.HBEColor and Options.HBEColor.Value or Color3.fromRGB(255, 0, 0)
                HRP.Color = hbeColor
                
                if not HRP:FindFirstChild("SelectionBox") then
                    local outline = Instance.new("SelectionBox")
                    outline.Name = "SelectionBox"
                    outline.Parent = HRP
                    outline.Adornee = HRP
                    outline.LineThickness = 0.05
                    outline.Color3 = Color3.fromRGB(0, 0, 0)
                end
            elseif HRP and (not humanoid or humanoid.Health <= 0) then
                HRP.Size = Vector3.new(2, 2, 1)
                HRP.Transparency = 1
                local outline = HRP:FindFirstChild("SelectionBox")
                if outline then
                    outline:Destroy()
                end
            end
        elseif player ~= LocalPlayer and player.Character and IsTeammate(player) then
            -- Restaurar hitbox de teammates
            local HRP = player.Character:FindFirstChild("HumanoidRootPart")
            if HRP then
                HRP.Size = Vector3.new(2, 2, 1)
                HRP.Transparency = 1
                local outline = HRP:FindFirstChild("SelectionBox")
                if outline then
                    outline:Destroy()
                end
            end
        end
    end
end

local function CreateESP(player)
    if player == LocalPlayer then return end
    
    local esp = {
        Box = nil,
        BoxOutline = nil,
        BoxInline = nil,
        Name = nil,
        HealthBar = nil,
        HealthBarOutline = nil,
        Tracer = nil,
        TracerOutline = nil,
        Player = player
    }
    
    -- Box principal
    local box = Drawing.new("Square")
    box.Visible = false
    box.Color = Color3.fromRGB(255, 255, 255)
    box.Thickness = 0.5
    box.Transparency = 1
    box.Filled = false
    esp.Box = box
    
    -- Box Outline
    local boxOutline = Drawing.new("Square")
    boxOutline.Visible = false
    boxOutline.Color = Color3.fromRGB(0, 0, 0)
    boxOutline.Thickness = 0.5
    boxOutline.Transparency = 1
    boxOutline.Filled = false
    esp.BoxOutline = boxOutline
    
    -- Box Inline
    local boxInline = Drawing.new("Square")
    boxInline.Visible = false
    boxInline.Color = Color3.fromRGB(0, 0, 0)
    boxInline.Thickness = 0.5
    boxInline.Transparency = 1
    boxInline.Filled = false
    esp.BoxInline = boxInline
    
    -- Nombre
    local name = Instance.new('TextLabel', ScreenGui)
    name.Visible = false
    name.BackgroundTransparency = 1
    name.Text = player.Name
    name.TextColor3 = Color3.fromRGB(255, 255, 255)
    name.TextSize = 13
    name.Font = Enum.Font.Code
    name.TextStrokeTransparency = 0
    name.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    name.ZIndex = 9e9
    name.AnchorPoint = Vector2.new(0.5, 0.5)
    esp.Name = name
    
    -- Health Bar
    local healthBar = Drawing.new("Square")
    healthBar.Visible = false
    healthBar.Color = Color3.fromRGB(0, 255, 0)
    healthBar.Thickness = 1
    healthBar.Transparency = 1
    healthBar.Filled = true
    esp.HealthBar = healthBar
    
    -- Health Bar Outline
    local healthBarOutline = Drawing.new("Square")
    healthBarOutline.Visible = false
    healthBarOutline.Color = Color3.fromRGB(0, 0, 0)
    healthBarOutline.Thickness = 1
    healthBarOutline.Transparency = 1
    healthBarOutline.Filled = false
    esp.HealthBarOutline = healthBarOutline
    
    -- Tracer
    local tracer = Drawing.new("Line")
    tracer.Visible = false
    tracer.Color = Color3.fromRGB(255, 255, 255)
    tracer.Thickness = 1
    tracer.Transparency = 1
    esp.Tracer = tracer
    
    -- Tracer Outline
    local tracerOutline = Drawing.new("Line")
    tracerOutline.Visible = false
    tracerOutline.Color = Color3.fromRGB(0, 0, 0)
    tracerOutline.Thickness = 3
    tracerOutline.Transparency = 1
    esp.TracerOutline = tracerOutline
    
    ESPObjects[player] = esp
end

local function UpdateESP()
    for player, esp in pairs(ESPObjects) do
        if not player or not player.Parent then
            esp.Box:Remove()
            esp.BoxOutline:Remove()
            esp.BoxInline:Remove()
            esp.Name:Destroy()
            esp.HealthBar:Remove()
            esp.HealthBarOutline:Remove()
            esp.Tracer:Remove()
            esp.TracerOutline:Remove()
            ESPObjects[player] = nil
            continue
        end
        
        if IsTeammate(player) then
            esp.Box.Visible = false
            esp.BoxOutline.Visible = false
            esp.BoxInline.Visible = false
            esp.Name.Visible = false
            esp.HealthBar.Visible = false
            esp.HealthBarOutline.Visible = false
            esp.Tracer.Visible = false
            esp.TracerOutline.Visible = false
            continue
        end
        
        local character = player.Character
        local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
        local humanoid = character and character:FindFirstChild("Humanoid")
        
        if humanoidRootPart and humanoid and humanoid.Health > 0 and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local dist = (LocalPlayer.Character.HumanoidRootPart.Position - humanoidRootPart.Position).Magnitude
            local maxRenderDistance = Options.MaxRenderDistance and Options.MaxRenderDistance.Value or 300
            
            if dist > maxRenderDistance then
                esp.Box.Visible = false
                esp.BoxOutline.Visible = false
                esp.BoxInline.Visible = false
                esp.Name.Visible = false
                esp.HealthBar.Visible = false
                esp.HealthBarOutline.Visible = false
                esp.Tracer.Visible = false
                esp.TracerOutline.Visible = false
                continue
            end
            
            local vector, onScreen = workspace.CurrentCamera:WorldToViewportPoint(humanoidRootPart.Position)
            
            if onScreen and Toggles.EnableESP and Toggles.EnableESP.Value then
                local charHeight = character:GetExtentsSize().Y / 2
                local top = workspace.CurrentCamera:WorldToViewportPoint(humanoidRootPart.Position + Vector3.new(0, charHeight, 0))
                local bottom = workspace.CurrentCamera:WorldToViewportPoint(humanoidRootPart.Position - Vector3.new(0, charHeight, 0))
                
                local screenSize = (bottom.Y - top.Y)
                if screenSize <= 0 then
                    esp.Box.Visible = false
                    esp.BoxOutline.Visible = false
                    esp.BoxInline.Visible = false
                    esp.Name.Visible = false
                    esp.HealthBar.Visible = false
                    esp.HealthBarOutline.Visible = false
                    esp.Tracer.Visible = false
                    esp.TracerOutline.Visible = false
                    continue
                end
                
                local position = Vector2.new(top.X - (screenSize * 0.65 / 2), top.Y)
                local size = Vector2.new(screenSize * 0.65, screenSize)
                
                -- Box ESP
                if Toggles.BoxESP and Toggles.BoxESP.Value then
                    local boxColor = Options.BoxColor and Options.BoxColor.Value or Color3.fromRGB(255, 255, 255)
                    
                    -- Outline
                    esp.BoxOutline.Size = size + Vector2.new(2, 2)
                    esp.BoxOutline.Position = position - Vector2.new(1, 1)
                    esp.BoxOutline.Visible = true
                    
                    -- Box principal
                    esp.Box.Size = size
                    esp.Box.Position = position
                    esp.Box.Color = boxColor
                    esp.Box.Transparency = Options.BoxTransparency and Options.BoxTransparency.Value or 1
                    esp.Box.Visible = true
                    
                    -- Inline
                    esp.BoxInline.Size = size - Vector2.new(2, 2)
                    esp.BoxInline.Position = position + Vector2.new(1, 1)
                    esp.BoxInline.Visible = true
                else
                    esp.Box.Visible = false
                    esp.BoxOutline.Visible = false
                    esp.BoxInline.Visible = false
                end
                
                -- Name ESP
                if Toggles.NameESP and Toggles.NameESP.Value then
                    esp.Name.Position = UDim2.new(0, position.X + (size.X / 2), 0, top.Y - 20)
                    esp.Name.TextColor3 = Options.NameColor and Options.NameColor.Value or Color3.fromRGB(255, 255, 255)
                    esp.Name.Text = player.Name
                    esp.Name.Visible = true
                else
                    esp.Name.Visible = false
                end
                
                -- Health Bar
                if Toggles.HealthESP and Toggles.HealthESP.Value then
                    local healthPercent = humanoid.Health / humanoid.MaxHealth
                    local barHeight = screenSize * healthPercent
                    
                    -- Health Bar Outline
                    esp.HealthBarOutline.Size = Vector2.new(4, screenSize + 2)
                    esp.HealthBarOutline.Position = Vector2.new(position.X - 6, position.Y - 1)
                    esp.HealthBarOutline.Visible = true
                    
                    -- Health Bar
                    esp.HealthBar.Size = Vector2.new(2, barHeight)
                    esp.HealthBar.Position = Vector2.new(position.X - 5, position.Y + (screenSize - barHeight))
                    esp.HealthBar.Color = Color3.fromRGB(0, 255, 0):Lerp(Color3.fromRGB(255, 0, 0), 1 - healthPercent)
                    esp.HealthBar.Visible = true
                else
                    esp.HealthBar.Visible = false
                    esp.HealthBarOutline.Visible = false
                end
                
                -- Tracers
                if Toggles.TracerESP and Toggles.TracerESP.Value then
                    local fromPos = Vector2.new(workspace.CurrentCamera.ViewportSize.X / 2, workspace.CurrentCamera.ViewportSize.Y)
                    if Options.TracerOrigin and Options.TracerOrigin.Value == "Top" then
                        fromPos = Vector2.new(workspace.CurrentCamera.ViewportSize.X / 2, 0)
                    elseif Options.TracerOrigin and Options.TracerOrigin.Value == "Middle" then
                        fromPos = Vector2.new(workspace.CurrentCamera.ViewportSize.X / 2, workspace.CurrentCamera.ViewportSize.Y / 2)
                    end
                    
                    -- Tracer Outline
                    esp.TracerOutline.From = fromPos
                    esp.TracerOutline.To = Vector2.new(vector.X, vector.Y)
                    esp.TracerOutline.Visible = true
                    
                    -- Tracer
                    esp.Tracer.From = fromPos
                    esp.Tracer.To = Vector2.new(vector.X, vector.Y)
                    esp.Tracer.Color = Options.TracerColor and Options.TracerColor.Value or Color3.fromRGB(255, 255, 255)
                    esp.Tracer.Transparency = Options.TracerTransparency and Options.TracerTransparency.Value or 1
                    esp.Tracer.Visible = true
                else
                    esp.Tracer.Visible = false
                    esp.TracerOutline.Visible = false
                end
            else
                esp.Box.Visible = false
                esp.BoxOutline.Visible = false
                esp.BoxInline.Visible = false
                esp.Name.Visible = false
                esp.HealthBar.Visible = false
                esp.HealthBarOutline.Visible = false
                esp.Tracer.Visible = false
                esp.TracerOutline.Visible = false
            end
        else
            esp.Box.Visible = false
            esp.BoxOutline.Visible = false
            esp.BoxInline.Visible = false
            esp.Name.Visible = false
            esp.HealthBar.Visible = false
            esp.HealthBarOutline.Visible = false
            esp.Tracer.Visible = false
            esp.TracerOutline.Visible = false
        end
    end
end

local Window = Library:CreateWindow({
    Title = '                       win.lol - by samx         ',
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2
})

local Tabs = {
    Hvh = Window:AddTab('hvh'),
    Legit = Window:AddTab('legit'),
    Visuals = Window:AddTab('visuals'),
    Character = Window:AddTab('character'),
    Settings = Window:AddTab('settings'),
}

-- ============ TAB HVH - AUTOKILL ============
local AutoKillBox = Tabs.Hvh:AddLeftGroupbox('autokill')

AutoKillBox:AddToggle('EnableAutoKill', {
    Text = 'autokill',
    Default = false,
}):AddKeyPicker('AutoKillKeybind', {
    Default = 'K',
    SyncToggleState = false,
    Mode = 'Toggle',
    Text = 'autokill key',
    NoUI = false,
})

AutoKillBox:AddSlider('AutoKillRange', {
    Text = 'range',
    Default = 50,
    Min = 10,
    Max = 200,
    Rounding = 0,
})

-- ============ TAB LEGIT - AIMBOT ============
local AimbotBox = Tabs.Legit:AddLeftGroupbox('aimbot')

AimbotBox:AddDropdown('AimbotMode', {
    Values = { 'Mouse Aimbot', 'Camlock' },
    Default = 1,
    Multi = false,
    Text = 'aimbot mode',
})

AimbotBox:AddToggle('EnableAimbot', {
    Text = 'enable aimbot',
    Default = false,
}):AddKeyPicker('AimbotKeybind', {
    Default = 'Q',
    SyncToggleState = false,
    Mode = 'Toggle',
    Text = 'aimbot key',
    NoUI = false,
})

AimbotBox:AddToggle('EnableStickyAim', {
    Text = 'sticky aim',
    Default = false,
})

AimbotBox:AddSlider('AimbotSmoothness', {
    Text = 'smoothness',
    Default = 0.5,
    Min = 0.1,
    Max = 1,
    Rounding = 2,
})

AimbotBox:AddSlider('AimbotFOV', {
    Text = 'fov',
    Default = 150,
    Min = 50,
    Max = 400,
    Rounding = 0,
})

AimbotBox:AddSlider('AimbotMaxDistance', {
    Text = 'max distance',
    Default = 500,
    Min = 50,
    Max = 1000,
    Rounding = 0,
})

AimbotBox:AddDropdown('AimbotHitbox', {
    Values = { 'Head', 'UpperTorso', 'HumanoidRootPart', 'LowerTorso' },
    Default = 1,
    Multi = false,
    Text = 'target part',
})

-- ============ TAB LEGIT - HITBOX EXPANDER ============
local HBEBox = Tabs.Legit:AddLeftGroupbox('hbe')

HBEBox:AddToggle('EnableHBE', {
    Text = 'enable hitbox expander',
    Default = false,
}):AddColorPicker('HBEColor', {
    Default = Color3.fromRGB(255, 0, 0),
})

HBEBox:AddSlider('HBESize', {
    Text = 'hitbox size',
    Default = 30,
    Min = 5,
    Max = 100,
    Rounding = 0,
})

-- ============ TAB LEGIT - TRIGGERBOT ============
local TriggerbotBox = Tabs.Legit:AddRightGroupbox('triggerbot')

TriggerbotBox:AddToggle('EnableTriggerbot', {
    Text = 'enable triggerbot',
    Default = false,
})

TriggerbotBox:AddSlider('TriggerbotDelay', {
    Text = 'delay (ms)',
    Default = 265,
    Min = 0,
    Max = 500,
    Rounding = 0,
})

TriggerbotBox:AddToggle('TriggerbotWallCheck', {
    Text = 'wall check',
    Default = true,
})

-- ============ TAB VISUALS - ESP ============
local ESPBox = Tabs.Visuals:AddLeftGroupbox('esp settings')

ESPBox:AddToggle('EnableESP', {
    Text = 'enable esp',
    Default = false,
})

ESPBox:AddSlider('MaxRenderDistance', {
    Text = 'max render distance',
    Default = 300,
    Min = 50,
    Max = 1000,
    Rounding = 0,
})

ESPBox:AddToggle('BoxESP', {
    Text = 'box',
    Default = true,
}):AddColorPicker('BoxColor', {
    Default = Color3.fromRGB(255, 255, 255),
})

ESPBox:AddSlider('BoxTransparency', {
    Text = 'box transparency',
    Default = 1,
    Min = 0,
    Max = 1,
    Rounding = 2,
})

ESPBox:AddToggle('NameESP', {
    Text = 'name',
    Default = true,
}):AddColorPicker('NameColor', {
    Default = Color3.fromRGB(255, 255, 255),
})

ESPBox:AddToggle('HealthESP', {
    Text = 'healthbar',
    Default = true,
})

local TracerBox = Tabs.Visuals:AddRightGroupbox('       tracer settings')

TracerBox:AddToggle('TracerESP', {
    Text = 'enable tracers (color bug)',
    Default = false,
}):AddColorPicker('TracerColor', {
    Default = Color3.fromRGB(255, 255, 255),
})

TracerBox:AddDropdown('TracerOrigin', {
    Values = { 'Bottom', 'Middle', 'Top' },
    Default = 1,
    Multi = false,
    Text = 'tracer origin',
})

TracerBox:AddSlider('TracerTransparency', {
    Text = 'tracer transparency',
    Default = 1,
    Min = 0,
    Max = 1,
    Rounding = 2,
})

-- ============ TAB CHARACTER - SPEED HACK ============
local CharacterBox = Tabs.Character:AddLeftGroupbox('character')

CharacterBox:AddToggle('EnableSpeedHack', {
    Text = 'speed hack',
    Default = false,
}):AddKeyPicker('SpeedHackKeybind', {
    Default = 'G',
    SyncToggleState = false,
    Mode = 'Toggle',
    Text = 'speed hack key',
    NoUI = false,
})

CharacterBox:AddSlider('SpeedHackSpeed', {
    Text = 'speed',
    Default = 16,
    Min = 16,
    Max = 100,
    Rounding = 0,
})

CharacterBox:AddToggle('EnableNoclip', {
    Text = 'noclip',
    Default = false,
}):AddKeyPicker('NoclipKeybind', {
    Default = 'X',
    SyncToggleState = false,
    Mode = 'Toggle',
    Text = 'noclip key',
    NoUI = false,
})

for _, player in pairs(Players:GetPlayers()) do
    CreateESP(player)
end

Players.PlayerAdded:Connect(function(player)
    CreateESP(player)
end)

Players.PlayerRemoving:Connect(function(player)
    if ESPObjects[player] then
        ESPObjects[player].Box:Remove()
        ESPObjects[player].BoxOutline:Remove()
        ESPObjects[player].BoxInline:Remove()
        ESPObjects[player].Name:Destroy()
        ESPObjects[player].HealthBar:Remove()
        ESPObjects[player].HealthBarOutline:Remove()
        ESPObjects[player].Tracer:Remove()
        ESPObjects[player].TracerOutline:Remove()
        ESPObjects[player] = nil
    end
end)

-- Listener para el keypicker
Options.AimbotKeybind:OnClick(function()
    AimbotKeyActive = not AimbotKeyActive
    if not AimbotKeyActive then
        AimbotActive = false
        AimbotTarget = nil
    end
end)

Options.SpeedHackKeybind:OnClick(function()
    Toggles.EnableSpeedHack:SetValue(not Toggles.EnableSpeedHack.Value)
end)

Options.NoclipKeybind:OnClick(function()
    Toggles.EnableNoclip:SetValue(not Toggles.EnableNoclip.Value)
end)

Options.AutoKillKeybind:OnClick(function()
    Toggles.EnableAutoKill:SetValue(not Toggles.EnableAutoKill.Value)
end)

-- Loop principal
RunService.RenderStepped:Connect(function()
    if Toggles.EnableESP and Toggles.EnableESP.Value then
        UpdateESP()
    end
    
    UpdateHitboxExpander()
    UpdateSpeedHack()
    UpdateNoclip()
    UpdateAutoKill()
    
    -- Sistema de Aimbot
    if Toggles.EnableAimbot and Toggles.EnableAimbot.Value and AimbotKeyActive then
        local aimbotMode = Options.AimbotMode and Options.AimbotMode.Value or "Mouse Aimbot"
        
        if AimbotActive and AimbotTarget then
            if AimbotTarget.Character and not IsTeammate(AimbotTarget) then
                local humanoid = AimbotTarget.Character:FindFirstChild("Humanoid")
                if not humanoid or humanoid.Health <= 0 then
                    AimbotActive = false
                    AimbotTarget = nil
                else
                    local targetPart = AimbotTarget.Character:FindFirstChild(Options.AimbotHitbox and Options.AimbotHitbox.Value or "Head")
                    
                    if targetPart then
                        if not Toggles.EnableStickyAim or not Toggles.EnableStickyAim.Value then
                            local newTarget = nil
                            
                            if aimbotMode == "Mouse Aimbot" then
                                newTarget = GetClosestPlayerMouse()
                            else -- Camlock
                                newTarget = GetClosestPlayerCamlock()
                            end
                            
                            if newTarget then
                                AimbotTarget = newTarget
                                targetPart = AimbotTarget.Character:FindFirstChild(Options.AimbotHitbox and Options.AimbotHitbox.Value or "Head")
                            end
                        end
                        
                        if targetPart then
                            if aimbotMode == "Mouse Aimbot" then
                                -- Mouse Aimbot: mover el cursor hacia el objetivo
                                local targetVector = workspace.CurrentCamera:WorldToViewportPoint(targetPart.Position)
                                local smoothness = Options.AimbotSmoothness and Options.AimbotSmoothness.Value or 0.5
                                local currentMouse = UserInputService:GetMouseLocation()
                                
                                local newX = currentMouse.X + (targetVector.X - currentMouse.X) * smoothness
                                local newY = currentMouse.Y + (targetVector.Y - currentMouse.Y) * smoothness
                                
                                mousemoveabs(newX, newY)
                            else
                                -- Camlock: mover la cámara hacia el objetivo
                                local camera = workspace.CurrentCamera
                                local smoothness = Options.AimbotSmoothness and Options.AimbotSmoothness.Value or 0.5
                                
                                local targetCFrame = CFrame.new(camera.CFrame.Position, targetPart.Position)
                                camera.CFrame = camera.CFrame:Lerp(targetCFrame, smoothness)
                            end
                        end
                    end
                    
                    Triggerbot()
                end
            else
                AimbotActive = false
                AimbotTarget = nil
            end
        else
            if aimbotMode == "Mouse Aimbot" then
                AimbotTarget = GetClosestPlayerMouse()
            else -- Camlock
                AimbotTarget = GetClosestPlayerCamlock()
            end
            
            if AimbotTarget then
                AimbotActive = true
            end
        end
    else
        if not AimbotKeyActive then
            AimbotActive = false
            AimbotTarget = nil
        end
    end
end)

Library:SetWatermarkVisibility(true)
Library:SetWatermark('win.lol')

local MenuGroup = Tabs.Settings:AddRightGroupbox('menu')
MenuGroup:AddButton('unload', function() Library:Unload() end)
MenuGroup:AddLabel('menu bind'):AddKeyPicker('MenuKeybind', { Default = 'RightShift', NoUI = true, Text = 'menu keybind' })

Library.ToggleKeybind = Options.MenuKeybind

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ 'MenuKeybind' })

ThemeManager:SetFolder('WinLol')
SaveManager:SetFolder('WinLol/configs')

SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:ApplyToTab(Tabs.Settings)

Library:OnUnload(function()
    for _, esp in pairs(ESPObjects) do
        esp.Box:Remove()
        esp.BoxOutline:Remove()
        esp.BoxInline:Remove()
        esp.Name:Destroy()
        esp.HealthBar:Remove()
        esp.HealthBarOutline:Remove()
        esp.Tracer:Remove()
        esp.TracerOutline:Remove()
    end
    Library.Unloaded = true
end)