-- AXAC X KILLUA EDITION v6.2
-- LocalScript: StarterPlayer > StarterPlayerScripts
-- Delta-gated local utility edition: responsive UI, RGB accent, local visual optimization,
-- FPS/ping display, character diagnostics, and a local-only headless appearance toggle.
-- This script does not modify server state or bypass game protections.

-- Executor gate: intentionally allows only an executor that identifies itself as Delta.
-- If the executor does not expose an identification function, access is denied by default.
local function getExecutorName()
    local candidates = {}
    if type(identifyexecutor) == "function" then
        table.insert(candidates, identifyexecutor)
    end
    if type(getexecutorname) == "function" then
        table.insert(candidates, getexecutorname)
    end
    for _, detector in ipairs(candidates) do
        local ok, result = pcall(detector)
        if ok and type(result) == "string" and result ~= "" then
            if string.find(string.lower(result), "delta", 1, true) then
                return result
            end
        end
    end
    return nil
end

local executorName = getExecutorName()
if not executorName or not string.find(string.lower(executorName), "delta", 1, true) then
    warn("[AXAC X KILLUA] Access denied: Delta executor required.")
    return
end

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Stats = game:GetService("Stats")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
if not player then
    warn("[AXAC X KILLUA] LocalPlayer unavailable.")
    return
end
local playerGui = player:WaitForChild("PlayerGui", 10)
if not playerGui then
    warn("[AXAC X KILLUA] PlayerGui unavailable; UI was not created.")
    return
end
local GUI_NAME = "AxacKilluaV62"

local previous = playerGui:FindFirstChild(GUI_NAME)
if previous then
    previous:Destroy()
end

local Theme = {
    bg = Color3.fromRGB(5, 10, 24),
    panel = Color3.fromRGB(10, 20, 40),
    card = Color3.fromRGB(16, 34, 61),
    blue = Color3.fromRGB(20, 135, 255),
    cyan = Color3.fromRGB(75, 220, 255),
    white = Color3.fromRGB(238, 246, 255),
    muted = Color3.fromRGB(140, 164, 196),
    inactive = Color3.fromRGB(55, 65, 82),
    purple = Color3.fromRGB(170, 105, 255),
}

local state = {
    open = true,
    reducedMotion = false,
    borderEnabled = true,
    cyanAccent = true,
    accent = Color3.fromRGB(75, 220, 255),
    page = "HOME",
    destroyed = false,
    connections = {},
    tweens = {},
    cameraConnection = nil,
    rgbEnabled = true,
    lowGraphics = false,
    headlessEnabled = false,
    showCrosshair = false,
    savedVisuals = {},
    savedHead = {},
    performanceConnections = {},
    pageConnections = {},
    characterConnection = nil,
    savedTerrainDecoration = nil,
    fps = 0,
    fpsFrames = 0,
    fpsElapsed = 0,
    performanceStatusLabel = nil,
}

local function track(connection)
    table.insert(state.connections, connection)
    return connection
end

local function make(className, properties, parent)
    local instance = Instance.new(className)
    for property, value in pairs(properties or {}) do
        instance[property] = value
    end
    instance.Parent = parent
    return instance
end

local function addCorner(instance, radius)
    make("UICorner", { CornerRadius = UDim.new(0, radius or 10) }, instance)
end

local function addStroke(instance, color, transparency)
    return make("UIStroke", {
        Color = color or Theme.blue,
        Thickness = 1,
        Transparency = transparency or 0.25,
    }, instance)
end

local function getAccent()
    return state.cyanAccent and Theme.cyan or Theme.purple
end

local function addLabel(parent, text, size, position, font, color, textSize)
    return make("TextLabel", {
        BackgroundTransparency = 1,
        Position = position,
        Size = size,
        Text = text,
        TextColor3 = color or Theme.white,
        Font = font or Enum.Font.Gotham,
        TextSize = textSize or 12,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
    }, parent)
end

local gui = make("ScreenGui", {
    Name = GUI_NAME,
    ResetOnSpawn = false,
    IgnoreGuiInset = false,
    DisplayOrder = 20,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

local main = make("Frame", {
    Name = "MainWindow",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(760, 500),
    BackgroundColor3 = Theme.bg,
    BorderSizePixel = 0,
    ClipsDescendants = true,
}, gui)
addCorner(main, 16)
local mainStroke = addStroke(main, Theme.blue, 0.15)
mainStroke:SetAttribute("AccentStroke", true)
make("UIGradient", {
    Rotation = 35,
    Color = ColorSequence.new(Theme.panel, Theme.bg),
}, main)

local opener = make("TextButton", {
    Name = "FloatingToggle",
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 12, 0.5, 0),
    Size = UDim2.fromOffset(52, 52),
    BackgroundColor3 = Theme.panel,
    Text = "⚡",
    TextColor3 = Theme.cyan,
    TextSize = 27,
    Font = Enum.Font.GothamBlack,
    AutoButtonColor = false,
    Visible = false,
    ZIndex = 50,
}, gui)
addCorner(opener, 16)
local openerStroke = addStroke(opener, Theme.cyan, 0)
openerStroke:SetAttribute("AccentStroke", true)

local crosshair = make("TextLabel", {
    Name = "Crosshair", AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(24, 24),
    BackgroundTransparency = 1, Text = "+", TextColor3 = Theme.cyan,
    TextSize = 22, Font = Enum.Font.GothamBlack, Visible = false,
    ZIndex = 100,
}, gui)

local function applyAccent()
    state.accent = getAccent()
    mainStroke.Color = state.accent
    opener.TextColor3 = state.accent
    openerStroke.Color = state.accent
    for _, descendant in ipairs(gui:GetDescendants()) do
        if descendant:IsA("TextLabel") and descendant:GetAttribute("AccentText") then
            descendant.TextColor3 = state.accent
        elseif descendant:IsA("UIStroke") and descendant:GetAttribute("AccentStroke") then
            descendant.Color = state.accent
        end
    end
end

local function saveAndSet(bucket, object, property, value)
    if not object or not object.Parent then return end
    bucket[object] = bucket[object] or {}
    if bucket[object][property] == nil then
        local ok, original = pcall(function() return object[property] end)
        if not ok then return end
        bucket[object][property] = original
    end
    pcall(function() object[property] = value end)
end

local function restoreBucket(bucket)
    for object, properties in pairs(bucket) do
        if object then
            for property, value in pairs(properties) do
                pcall(function() object[property] = value end)
            end
        end
        bucket[object] = nil
    end
end

local function optimizeObject(object)
    if not state.lowGraphics or state.destroyed or not object then return end
    if object:IsA("BasePart") then
        saveAndSet(state.savedVisuals, object, "CastShadow", false)
    elseif object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam")
        or object:IsA("Fire") or object:IsA("Smoke") or object:IsA("Sparkles")
        or object:IsA("PostEffect") or object:IsA("PointLight")
        or object:IsA("SpotLight") or object:IsA("SurfaceLight") then
        saveAndSet(state.savedVisuals, object, "Enabled", false)
    end
end

local function disconnectPerformanceConnections()
    for _, connection in ipairs(state.performanceConnections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(state.performanceConnections)
end

local function optimizeExistingWorld()
    -- Process in small batches so large maps do not freeze the client in one frame.
    local roots = { workspace, Lighting }
    for _, root in ipairs(roots) do
        local descendants = root:GetDescendants()
        for index, object in ipairs(descendants) do
            if not state.lowGraphics or state.destroyed then return end
            optimizeObject(object)
            if index % 250 == 0 then task.wait() end
        end
    end
end

local function setLowGraphics(enabled)
    state.lowGraphics = enabled
    disconnectPerformanceConnections()
    if enabled then
        local terrain = workspace:FindFirstChildOfClass("Terrain")
        if terrain and state.savedTerrainDecoration == nil then
            local ok, original = pcall(function() return terrain.Decoration end)
            if ok then
                state.savedTerrainDecoration = original
                pcall(function() terrain.Decoration = false end)
            end
        end
        -- Watch new instances before scanning existing descendants to avoid missing additions.
        table.insert(state.performanceConnections, workspace.DescendantAdded:Connect(function(object)
            if state.lowGraphics then optimizeObject(object) end
        end))
        table.insert(state.performanceConnections, Lighting.DescendantAdded:Connect(function(object)
            if state.lowGraphics then optimizeObject(object) end
        end))
        task.spawn(optimizeExistingWorld)
    else
        restoreBucket(state.savedVisuals)
        local terrain = workspace:FindFirstChildOfClass("Terrain")
        if terrain and state.savedTerrainDecoration ~= nil then
            pcall(function() terrain.Decoration = state.savedTerrainDecoration end)
        end
        state.savedTerrainDecoration = nil
    end
end

local function setHeadless(enabled)
    state.headlessEnabled = enabled
    if enabled then
        local character = player.Character
        if not character then return end
        local head = character:FindFirstChild("Head")
        if not head then return end
        saveAndSet(state.savedHead, head, "LocalTransparencyModifier", 1)
        for _, object in ipairs(character:GetDescendants()) do
            if object:IsA("Decal") and object.Parent == head then
                saveAndSet(state.savedHead, object, "Transparency", 1)
            elseif object:IsA("BasePart") and object.Name == "Handle" then
                local weld = object:FindFirstChildWhichIsA("Weld") or object:FindFirstChildWhichIsA("Motor6D")
                if weld and (weld.Part0 == head or weld.Part1 == head) then
                    saveAndSet(state.savedHead, object, "LocalTransparencyModifier", 1)
                end
            end
        end
    else
        restoreBucket(state.savedHead)
    end
end

local function getPingText()
    local ok, value = pcall(function()
        return Stats.Network.ServerStatsItem["Data Ping"]:GetValueString()
    end)
    return ok and value or "N/A"
end

local header = make("Frame", {
    Name = "Header",
    Size = UDim2.new(1, 0, 0, 60),
    BackgroundColor3 = Theme.panel,
    BorderSizePixel = 0,
    Active = true,
}, main)
local brandLabel = addLabel(header, "AXAC  ×  KILLUA", UDim2.new(1, -110, 0, 27),
    UDim2.fromOffset(16, 6), Enum.Font.GothamBlack, Theme.cyan, 18)
brandLabel:SetAttribute("AccentText", true)
addLabel(header, "LIGHTNING INTERFACE  •  V6.2", UDim2.new(1, -110, 0, 18),
    UDim2.fromOffset(18, 33), Enum.Font.GothamMedium, Theme.muted, 10)

local close = make("TextButton", {
    Name = "CloseButton",
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -12, 0.5, 0),
    Size = UDim2.fromOffset(34, 34),
    BackgroundColor3 = Color3.fromRGB(65, 28, 47),
    Text = "×",
    TextColor3 = Theme.white,
    TextSize = 24,
    Font = Enum.Font.GothamBold,
    AutoButtonColor = false,
}, header)
addCorner(close, 9)

local sidebar = make("Frame", {
    Name = "Sidebar",
    Position = UDim2.fromOffset(10, 70),
    Size = UDim2.new(0, 132, 1, -108),
    BackgroundColor3 = Theme.panel,
    BorderSizePixel = 0,
}, main)
addCorner(sidebar, 12)

local nav = make("Frame", {
    Position = UDim2.fromOffset(7, 9),
    Size = UDim2.new(1, -14, 1, -18),
    BackgroundTransparency = 1,
}, sidebar)
make("UIListLayout", {
    Padding = UDim.new(0, 7),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, nav)

local content = make("ScrollingFrame", {
    Name = "Content",
    Position = UDim2.fromOffset(152, 70),
    Size = UDim2.new(1, -162, 1, -108),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = Theme.blue,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.new(),
}, main)
make("UIPadding", {
    PaddingRight = UDim.new(0, 5),
    PaddingBottom = UDim.new(0, 10),
}, content)
make("UIListLayout", {
    Padding = UDim.new(0, 9),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, content)

addLabel(main, "© 2026 AXAC  •  UI EDITION", UDim2.new(1, -20, 0, 18),
    UDim2.new(0, 12, 1, -23), Enum.Font.GothamMedium, Theme.muted, 9)

local function updateLayout()
    local camera = workspace.CurrentCamera
    if not camera then return end

    local viewport = camera.ViewportSize
    local width = math.max(240, math.min(math.max(240, viewport.X - 16), 760))
    local height = math.max(220, math.min(math.max(220, viewport.Y - 32), 500))
    main.Size = UDim2.fromOffset(width, height)

    local compact = width < 540
    local sidebarWidth = width < 360 and 68 or (compact and 88 or 132)
    local contentLeft = sidebarWidth + 20

    sidebar.Position = UDim2.fromOffset(8, 70)
    sidebar.Size = UDim2.new(0, sidebarWidth, 1, -98)
    content.Position = UDim2.fromOffset(contentLeft, 70)
    content.Size = UDim2.new(1, -(contentLeft + 10), 1, -98)

    for _, item in ipairs(nav:GetChildren()) do
        if item:IsA("TextButton") then
            item.TextSize = width < 360 and 8 or (compact and 9 or 10)
        end
    end
end

local function makeDraggable(object, handle)
    local dragging = false
    local dragStart
    local startPosition
    local activeInput

    track(handle.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        dragging = true
        dragStart = input.Position
        startPosition = object.Position
        activeInput = input.UserInputType
    end))

    track(UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        local mouseMove = activeInput == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseMovement
        local touchMove = activeInput == Enum.UserInputType.Touch
            and input.UserInputType == Enum.UserInputType.Touch
        if not mouseMove and not touchMove then return end

        local delta = input.Position - dragStart
        object.Position = UDim2.new(
            startPosition.X.Scale, startPosition.X.Offset + delta.X,
            startPosition.Y.Scale, startPosition.Y.Offset + delta.Y
        )
    end))

    track(UserInputService.InputEnded:Connect(function(input)
        if (activeInput == Enum.UserInputType.MouseButton1
                and input.UserInputType == Enum.UserInputType.MouseButton1)
            or (activeInput == Enum.UserInputType.Touch
                and input.UserInputType == Enum.UserInputType.Touch) then
            dragging = false
            activeInput = nil
        end
    end))
end

local function setOpen(open)
    state.open = open
    main.Visible = open
    opener.Visible = not open
end

track(close.Activated:Connect(function() setOpen(false) end))
track(opener.Activated:Connect(function() setOpen(true) end))
track(UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.RightShift then
        setOpen(not state.open)
    end
end))

makeDraggable(main, header)
makeDraggable(opener, opener)

local function trackPage(connection)
    table.insert(state.pageConnections, connection)
    return connection
end

local function clearContent()
    for _, connection in ipairs(state.pageConnections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(state.pageConnections)
    state.performanceStatusLabel = nil
    for _, child in ipairs(content:GetChildren()) do
        if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
            child:Destroy()
        end
    end
end

local function section(title, description, height)
    local box = make("Frame", {
        Size = UDim2.new(1, -5, 0, height or 78),
        BackgroundColor3 = Theme.panel,
        BorderSizePixel = 0,
    }, content)
    addCorner(box, 11)
    addStroke(box, Theme.blue, 0.72)
    addLabel(box, title, UDim2.new(1, -22, 0, 24), UDim2.fromOffset(12, 7),
        Enum.Font.GothamBold, getAccent(), 12)
    if description then
        local descriptionLabel = addLabel(box, description, UDim2.new(1, -22, 1, -36),
            UDim2.fromOffset(12, 31), Enum.Font.Gotham, Theme.muted, 11)
        if title == "LIVE STATUS" then
            state.performanceStatusLabel = descriptionLabel
        end
    end
    return box
end

local function actionButton(parent, title, callback)
    local button = make("TextButton", {
        Size = UDim2.new(1, -10, 0, 38),
        BackgroundColor3 = Theme.card,
        Text = title,
        TextColor3 = Theme.white,
        TextSize = 12,
        Font = Enum.Font.GothamSemibold,
        AutoButtonColor = false,
    }, parent)
    addCorner(button, 8)
    addStroke(button, Theme.blue, 0.75)

    trackPage(button.Activated:Connect(callback))
    trackPage(button.MouseEnter:Connect(function()
        if not state.reducedMotion then
            local tween = TweenService:Create(button, TweenInfo.new(0.12), {
                BackgroundColor3 = Color3.fromRGB(24, 53, 85),
            })
            tween:Play()
        end
    end))
    trackPage(button.MouseLeave:Connect(function()
        if not state.reducedMotion then
            local tween = TweenService:Create(button, TweenInfo.new(0.12), {
                BackgroundColor3 = Theme.card,
            })
            tween:Play()
        end
    end))
    return button
end

local pages = { "HOME", "PLAYER", "PERFORMANCE", "FEATURES", "APPEARANCE", "SETTINGS" }
local navButtons = {}

local function render(page)
    state.page = page
    clearContent()

    if page == "HOME" then
        section("⚡ WELCOME TO AXAC", "KILLUA EDITION • Lightweight local interface", 76)
        section("ABOUT AXAC", "AXAC X KILLUA adalah panel utilitas client dengan kontrol visual, diagnostik karakter, dan pengaturan antarmuka. Executor terdeteksi: " .. tostring(executorName), 94)
        section("STATUS • ONLINE", "Menu aktif. Fitur visual hanya berlaku pada client ini; statistik dan state server tidak diubah.", 76)
        section("QUICK CONTROL", "PC: tekan RightShift untuk buka/tutup menu. HP: gunakan tombol ⚡. Geser header untuk memindahkan jendela.", 86)
        section("PERFORMANCE", "Counter FPS diperbarui dua kali per detik. Optimasi visual dapat mengurangi efek, bukan menjamin FPS maksimum.", 80)
        section("BUILD", "AXAC X KILLUA • v6.2 • DELTA-GATED LOCAL UTILITY", 58)
    elseif page == "PLAYER" then
        section("PLAYER DIAGNOSTICS", "Informasi karakter lokal; tidak mengubah statistik server.", 70)
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local pos = root and root.Position
        section("CHARACTER STATUS", "Character: " .. (character and "Loaded" or "Not loaded")
            .. "\nHealth: " .. (humanoid and math.floor(humanoid.Health) .. "/" .. math.floor(humanoid.MaxHealth) or "N/A")
            .. "\nState: " .. (humanoid and tostring(humanoid:GetState()):gsub("Enum.HumanoidStateType.", "") or "N/A"), 100)
        section("POSITION", pos and string.format("X %.1f  |  Y %.1f  |  Z %.1f", pos.X, pos.Y, pos.Z)
            or "Character position unavailable.", 65)
        actionButton(content, "Toggle Local Headless: " .. (state.headlessEnabled and "ON" or "OFF"), function()
            setHeadless(not state.headlessEnabled)
            render("PLAYER")
        end)
        actionButton(content, "Refresh Character Info", function() render("PLAYER") end)
        section("LOCAL-ONLY COSMETIC", "Headless hanya menyembunyikan head secara lokal pada client ini; tidak membuka item Headless resmi atau mengubah avatar server.", 78)
    elseif page == "PERFORMANCE" then
        section("CLIENT PERFORMANCE", "Optimasi visual lokal. Dampak FPS bergantung pada perangkat dan game.", 70)
        actionButton(content, "Toggle Low Graphics: " .. (state.lowGraphics and "ON" or "OFF"), function()
            setLowGraphics(not state.lowGraphics)
            render("PERFORMANCE")
        end)
        actionButton(content, "Toggle Crosshair: " .. (state.showCrosshair and "ON" or "OFF"), function()
            state.showCrosshair = not state.showCrosshair
            crosshair.Visible = state.showCrosshair
            crosshair.TextColor3 = getAccent()
            render("PERFORMANCE")
        end)
        section("LIVE STATUS", "FPS: " .. tostring(state.fps) .. "\nNetwork ping: " .. getPingText()
            .. "\nLow Graphics: " .. (state.lowGraphics and "ON" or "OFF"), 88)
        section("WHAT LOW GRAPHICS CHANGES", "Turns off local particles, beams, trails, lights, post effects and part shadows. Toggle OFF to restore saved values.", 82)
    elseif page == "FEATURES" then
        section("INTERFACE FEATURES", "Responsive UI, diagnostics, local visual controls, and quick settings.", 70)
        section("Responsive layout", "Ukuran jendela dan sidebar menyesuaikan ukuran layar.", 68)
        section("Drag & move", "Geser header di PC atau HP untuk memindahkan jendela.", 68)
        section("Quick toggle", "Tombol ⚡ mengembalikan jendela setelah disembunyikan.", 68)
        section("Clean lifecycle", "Koneksi event dilepas saat GUI dihancurkan; animasi hover tidak menumpuk dalam daftar tween.", 68)
        section("Mobile controls", "Gunakan tombol ⚡ untuk membuka kembali menu. Header dapat digeser dengan sentuhan.", 68)
    elseif page == "APPEARANCE" then
        section("VISUAL SETTINGS", "Ubah efek tampilan langsung dari menu.", 70)
        actionButton(content, "Toggle Lightning Border", function()
            state.borderEnabled = not state.borderEnabled
            mainStroke.Enabled = state.borderEnabled
            render("APPEARANCE")
        end)
        actionButton(content, "Switch Accent: Cyan / Violet", function()
            state.cyanAccent = not state.cyanAccent
            applyAccent()
            render("APPEARANCE")
        end)
        actionButton(content, "Toggle RGB Border: " .. (state.rgbEnabled and "ON" or "OFF"), function()
            state.rgbEnabled = not state.rgbEnabled
            render("APPEARANCE")
        end)
        actionButton(content, "Toggle Reduced Motion", function()
            state.reducedMotion = not state.reducedMotion
            render("APPEARANCE")
        end)
        section("CURRENT SETTINGS", "Lightning Border: " .. (state.borderEnabled and "ON" or "OFF")
            .. "\nCyan Accent: " .. (state.cyanAccent and "ON" or "OFF")
            .. "\nReduced Motion: " .. (state.reducedMotion and "ON" or "OFF")
            .. "\nRGB Border: " .. (state.rgbEnabled and "ON" or "OFF")
            .. "\nAccent: " .. (state.cyanAccent and "CYAN" or "VIOLET"), 122)
    elseif page == "SETTINGS" then
        section("INTERFACE SETTINGS", "Pengaturan jendela dan navigasi. Shortcut PC: RightShift.", 70)
        actionButton(content, "Center Main Window", function()
            main.AnchorPoint = Vector2.new(0.5, 0.5)
            main.Position = UDim2.fromScale(0.5, 0.5)
        end)
        actionButton(content, "Reset Floating Button Position", function()
            opener.AnchorPoint = Vector2.new(0, 0.5)
            opener.Position = UDim2.new(0, 12, 0.5, 0)
        end)
        actionButton(content, "Show Main Window", function()
            setOpen(true)
        end)
        actionButton(content, "Refresh Current Page", function()
            render(state.page)
        end)
    end

    for name, button in pairs(navButtons) do
        button.BackgroundColor3 = name == page and Theme.card or Theme.panel
        button.TextColor3 = name == page and getAccent() or Theme.white
    end
end

for index, page in ipairs(pages) do
    local button = make("TextButton", {
        Name = page .. "Button",
        LayoutOrder = index,
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = page == "HOME" and Theme.card or Theme.panel,
        Text = page,
        TextColor3 = page == "HOME" and getAccent() or Theme.white,
        TextSize = 10,
        Font = Enum.Font.GothamBold,
        AutoButtonColor = false,
    }, nav)
    addCorner(button, 8)
    navButtons[page] = button
    track(button.Activated:Connect(function() render(page) end))
end

local function hookCamera()
    if state.cameraConnection then
        state.cameraConnection:Disconnect()
        state.cameraConnection = nil
    end
    local camera = workspace.CurrentCamera
    if camera then
        state.cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateLayout)
    end
    updateLayout()
end

track(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(hookCamera))

-- Lightweight border pulse; skipped when reduced motion is enabled.
task.spawn(function()
    while gui.Parent and not state.destroyed do
        if state.borderEnabled and not state.reducedMotion then
            local nextColor = state.rgbEnabled
                and Color3.fromHSV((os.clock() * 0.18) % 1, 0.9, 1)
                or state.accent
            local pulse = TweenService:Create(mainStroke, TweenInfo.new(0.25), {
                Color = nextColor,
                Transparency = 0.08,
            })
            pulse:Play()
            pulse.Completed:Wait()
        else
            task.wait(0.5)
        end
    end
end)

track(gui.Destroying:Connect(function()
    state.destroyed = true
    for _, tween in ipairs(state.tweens) do
        pcall(function() tween:Cancel() end)
    end
    for _, connection in ipairs(state.connections) do
        if connection.Connected then
            connection:Disconnect()
        end
    end
    if state.cameraConnection then
        state.cameraConnection:Disconnect()
        state.cameraConnection = nil
    end
    disconnectPerformanceConnections()
    for _, connection in ipairs(state.pageConnections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(state.pageConnections)
    restoreBucket(state.savedVisuals)
    restoreBucket(state.savedHead)
    if state.savedTerrainDecoration ~= nil then
        pcall(function() workspace.Terrain.Decoration = state.savedTerrainDecoration end)
        state.savedTerrainDecoration = nil
    end
    table.clear(state.connections)
    table.clear(state.tweens)
end))

track(RunService.RenderStepped:Connect(function(deltaTime)
    state.fpsFrames += 1
    state.fpsElapsed += deltaTime
    if state.fpsElapsed >= 0.5 then
        state.fps = math.floor(state.fpsFrames / math.max(state.fpsElapsed, 0.001) + 0.5)
        state.fpsFrames = 0
        state.fpsElapsed = 0
        local label = state.performanceStatusLabel
        if label and label.Parent then
            label.Text = "FPS: " .. tostring(state.fps) .. "\nNetwork ping: " .. getPingText()
                .. "\nLow Graphics: " .. (state.lowGraphics and "ON" or "OFF")
        end
    end
end))

track(player.CharacterAdded:Connect(function()
    task.wait(0.5)
    if state.destroyed or not gui.Parent then return end
    if state.headlessEnabled then setHeadless(true) end
    if state.lowGraphics then task.spawn(optimizeExistingWorld) end
end))

hookCamera()
render("HOME")
applyAccent()
print("[AXAC X KILLUA EDITION v6.2] Loaded for " .. tostring(executorName) .. ".")
