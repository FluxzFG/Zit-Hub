local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

-- Biến lưu trữ tốc độ hiện tại để không bị mất khi chết/hồi sinh
local currentWalkSpeed = 16

-- =========================================
-- 1. TẠO GIAO DIỆN CHÍNH (CÓ THỂ KÉO THẢ)
-- =========================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SmartShaderGui"
screenGui.ResetOnSpawn = false
-- Raise this GUI above other ordinary ScreenGuis (does not override Roblox CoreGui/ESC menu).
screenGui.DisplayOrder = 999
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- =========================================
-- PC-ONLY: PHÍM TẮT THẢ CHUỘT (LeftAlt)
-- Khi khóa lại, trả quyền điều khiển chuột cho game để RMB xoay camera hoạt động.
-- =========================================
local pcMouseToggleEnabled = UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled
local pcMouseUnlocked = false
local pcMouseRightHeld = false
local pcMouseKeyConnection
local pcMouseInputEndedConnection
local pcMouseKeepFreeConnection

if pcMouseToggleEnabled then
    pcMouseKeyConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        -- Cho game tự xử lý chuột phải để camera có thể vào chế độ kéo/xoay.
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            pcMouseRightHeld = true
            return
        end

        if gameProcessed or UserInputService:GetFocusedTextBox() then
            return
        end

        if input.KeyCode == Enum.KeyCode.LeftAlt then
            pcMouseUnlocked = not pcMouseUnlocked
            UserInputService.MouseIconEnabled = true

            if pcMouseUnlocked then
                -- Chỉ thả chuột khi cần tương tác với GUI.
                UserInputService.MouseBehavior = Enum.MouseBehavior.Default
            end
            -- Khi tắt chế độ thả chuột, KHÔNG ép LockCenter:
            -- để game tự quản lý chuột và thao tác giữ chuột phải.
        end
    end)

    pcMouseInputEndedConnection = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            pcMouseRightHeld = false
        end
    end)

    -- Giữ chuột tự do khi cần bấm GUI, nhưng nhường quyền cho game khi giữ RMB.
    pcMouseKeepFreeConnection = RunService.RenderStepped:Connect(function()
        if pcMouseUnlocked and not pcMouseRightHeld then
            UserInputService.MouseIconEnabled = true
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        end
    end)
end

screenGui.Destroying:Connect(function()
    if pcMouseKeyConnection then
        pcMouseKeyConnection:Disconnect()
    end
    if pcMouseInputEndedConnection then
        pcMouseInputEndedConnection:Disconnect()
    end
    if pcMouseKeepFreeConnection then
        pcMouseKeepFreeConnection:Disconnect()
    end
    pcMouseUnlocked = false
    -- Trả quyền điều khiển chuột cho game, không ép một trạng thái khóa cụ thể.
    UserInputService.MouseIconEnabled = true
end)

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 320, 0, 300)
frame.Position = UDim2.new(0.5, -160, 0.5, -150)
frame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
frame.BorderSizePixel = 0
frame.ClipsDescendants = true
frame.Parent = screenGui

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 12)
uiCorner.Parent = frame


-- =========================================
-- 2. THANH TIÊU ĐỀ & NÚT ĐIỀU KHIỂN ( - / X )
-- =========================================
local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 45)
topBar.BackgroundTransparency = 1
topBar.Parent = frame

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -70, 1, 0)
titleLabel.Position = UDim2.new(0, 15, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = 16
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Text = "✨ Zit Hub"
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = topBar

-- Nút Thu Nhỏ / Phóng to (-)
local minButton = Instance.new("TextButton")
minButton.Size = UDim2.new(0, 30, 0, 30)
minButton.Position = UDim2.new(1, -65, 0, 7.5)
minButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
minButton.TextColor3 = Color3.fromRGB(255, 255, 255)
minButton.TextSize = 14
minButton.Font = Enum.Font.GothamBold
minButton.Text = "-"
minButton.Parent = topBar

local minCorner = Instance.new("UICorner")
minCorner.CornerRadius = UDim.new(0, 6)
minCorner.Parent = minButton

-- Nút Đóng (X)
local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 30, 0, 30)
closeButton.Position = UDim2.new(1, -30, 0, 7.5)
closeButton.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.TextSize = 14
closeButton.Font = Enum.Font.GothamBold
closeButton.Text = "X"
closeButton.Parent = topBar

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeButton


-- =========================================
-- 3. TẠO THANH CUỘN (SCROLLING FRAME)
-- =========================================
local scrollingFrame = Instance.new("ScrollingFrame")
scrollingFrame.Size = UDim2.new(1, -10, 1, -55)
scrollingFrame.Position = UDim2.new(0, 5, 0, 48)
scrollingFrame.BackgroundTransparency = 1
scrollingFrame.BorderSizePixel = 0
scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollingFrame.ScrollBarThickness = 6
scrollingFrame.Parent = frame

local uiListLayout = Instance.new("UIListLayout")
uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout.Padding = UDim.new(0, 8)
uiListLayout.Parent = scrollingFrame

-- Hướng dẫn phím tắt hiển thị ngay trong GUI (chỉ dành cho PC)
local mouseKeybindHint = Instance.new("TextLabel")
mouseKeybindHint.Name = "MouseKeybindHint"
mouseKeybindHint.Size = UDim2.new(1, -10, 0, 26)
mouseKeybindHint.BackgroundTransparency = 1
mouseKeybindHint.Text = "⌨ LeftAlt: Unlock / Lock Mouse (PC)"
mouseKeybindHint.TextColor3 = Color3.fromRGB(220, 220, 220)
mouseKeybindHint.TextSize = 12
mouseKeybindHint.Font = Enum.Font.GothamMedium
mouseKeybindHint.TextXAlignment = Enum.TextXAlignment.Left
mouseKeybindHint.LayoutOrder = -1
mouseKeybindHint.Parent = scrollingFrame

uiListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, uiListLayout.AbsoluteContentSize.Y + 10)
end)


-- =========================================
-- 4. TÍNH NĂNG THU NHỎ & KÉO THẢ BẢNG
-- =========================================
local isMinimized = false

minButton.MouseButton1Click:Connect(function()
	isMinimized = not isMinimized
	if isMinimized then
		frame:TweenSize(UDim2.new(0, 320, 0, 45), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2, true)
		minButton.Text = "[]"
	else
		frame:TweenSize(UDim2.new(0, 320, 0, 300), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2, true)
		minButton.Text = "-"
	end
end)

closeButton.MouseButton1Click:Connect(function()
	screenGui:Destroy()
end)

local dragging, dragStart, startPos

frame.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = frame.Position
		
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
			end
		end)
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - dragStart
		frame.Position = UDim2.new(
			startPos.X.Scale, 
			startPos.X.Offset + delta.X, 
			startPos.Y.Scale, 
			startPos.Y.Offset + delta.Y
		)
	end
end)


-- =========================================
-- 5. HÀM XÓA HIỆU ỨNG & CÁC SHADER
-- =========================================
local function clearEffects()
	for _, v in pairs(Lighting:GetChildren()) do
		if v:IsA("Sky")
		or v:IsA("Atmosphere")
		or v:IsA("BloomEffect")
		or v:IsA("ColorCorrectionEffect")
		or v:IsA("SunRaysEffect")
		or v:IsA("DepthOfFieldEffect")
		or v:IsA("BlurEffect") then
			v:Destroy()
		end
	end
end

local function applyShader1()
	clearEffects()
	Lighting.ClockTime = 6.825
	Lighting.Brightness = 1.2
	Lighting.ExposureCompensation = 0.2
	Lighting.Ambient = Color3.fromRGB(75, 47, 29)
	Lighting.OutdoorAmbient = Color3.fromRGB(70, 70, 70)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 166, 0)
	Lighting.ColorShift_Bottom = Color3.fromRGB(0, 0, 0)
	Lighting.EnvironmentDiffuseScale = 0.1
	Lighting.EnvironmentSpecularScale = 0.5
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.4
	Lighting.FogStart = 0
	Lighting.FogEnd = 1000
	Lighting.FogColor = Color3.fromRGB(192, 192, 192)

	local sky = Instance.new("Sky")
	sky.SkyboxBk = "rbxassetid://600830446"
	sky.SkyboxDn = "rbxassetid://600831635"
	sky.SkyboxFt = "rbxassetid://600832720"
	sky.SkyboxLf = "rbxassetid://600886090"
	sky.SkyboxRt = "rbxassetid://600833862"
	sky.SkyboxUp = "rbxassetid://600835177"
	sky.SunAngularSize = 11
	sky.MoonAngularSize = 11
	sky.StarCount = 3000
	sky.Parent = Lighting

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.419
	atmosphere.Offset = 0
	atmosphere.Color = Color3.fromRGB(75, 47, 29)
	atmosphere.Decay = Color3.fromRGB(0, 0, 0)
	atmosphere.Glare = 1
	atmosphere.Haze = 0
	atmosphere.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 1
	bloom.Size = 56
	bloom.Threshold = 0.8
	bloom.Parent = Lighting

	local color = Instance.new("ColorCorrectionEffect")
	color.Brightness = 0
	color.Contrast = 0
	color.Saturation = 0.5
	color.TintColor = Color3.fromRGB(255, 255, 255)
	color.Parent = Lighting

	local sunrays = Instance.new("SunRaysEffect")
	sunrays.Intensity = 0.103
	sunrays.Spread = 0.014
	sunrays.Parent = Lighting

	local dof = Instance.new("DepthOfFieldEffect")
	dof.FocusDistance = 0
	dof.InFocusRadius = 25
	dof.NearIntensity = 0.15
	dof.FarIntensity = 0
	dof.Parent = Lighting

	local blur = Instance.new("BlurEffect")
	blur.Size = 2
	blur.Parent = Lighting
end

local function applyShader2()
	clearEffects()
	Lighting.ClockTime = 7.815
	Lighting.Brightness = 3
	Lighting.ExposureCompensation = 0
	Lighting.Ambient = Color3.fromRGB(71, 62, 39)
	Lighting.OutdoorAmbient = Color3.fromRGB(122, 106, 75)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 192, 146)
	Lighting.ColorShift_Bottom = Color3.fromRGB(0, 0, 0)
	Lighting.EnvironmentDiffuseScale = 0.259
	Lighting.EnvironmentSpecularScale = 1
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.15

	local sky = Instance.new("Sky")
	sky.SkyboxBk = "rbxassetid://252760981"
	sky.SkyboxDn = "rbxassetid://252763035"
	sky.SkyboxFt = "rbxassetid://252761439"
	sky.SkyboxLf = "rbxassetid://252760980"
	sky.SkyboxRt = "rbxassetid://252760986"
	sky.SkyboxUp = "rbxassetid://252762652"
	sky.SunAngularSize = 10
	sky.MoonAngularSize = 11
	sky.StarCount = 3000
	sky.Parent = Lighting

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.376
	atmosphere.Offset = 0
	atmosphere.Color = Color3.fromRGB(0, 0, 0)
	atmosphere.Decay = Color3.fromRGB(0, 0, 0)
	atmosphere.Glare = 0
	atmosphere.Haze = 0
	atmosphere.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0
	bloom.Size = 0
	bloom.Threshold = 0
	bloom.Parent = Lighting

	local color = Instance.new("ColorCorrectionEffect")
	color.Brightness = 0
	color.Contrast = 0
	color.Saturation = 0
	color.TintColor = Color3.fromRGB(250, 250, 250)
	color.Parent = Lighting

	local sunrays = Instance.new("SunRaysEffect")
	sunrays.Intensity = 0.04
	sunrays.Spread = 1
	sunrays.Parent = Lighting

	local dof = Instance.new("DepthOfFieldEffect")
	dof.FocusDistance = 21.16
	dof.InFocusRadius = 17.31
	dof.NearIntensity = 0.21
	dof.FarIntensity = 0.232
	dof.Parent = Lighting
end

local function applyShader3()
	clearEffects()
	Lighting.ClockTime = 14
	Lighting.Brightness = 2
	Lighting.ExposureCompensation = 0
	Lighting.Ambient = Color3.fromRGB(128, 128, 128)
	Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
	Lighting.ColorShift_Top = Color3.fromRGB(0, 0, 0)
	Lighting.ColorShift_Bottom = Color3.fromRGB(0, 0, 0)
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.2
	Lighting.FogEnd = 100000
end


-- =========================================
-- 6. HÀM TẠO WIDGET (NÚT, SLIDER, C-FRAME)
-- =========================================
local function createButton(name, color, callback)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, -10, 0, 38)
	btn.BackgroundColor3 = color
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.TextSize = 14
	btn.Font = Enum.Font.GothamSemibold
	btn.Text = name
	btn.Parent = scrollingFrame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = btn

	btn.MouseButton1Click:Connect(callback)
end

local function createSlider(name, minVal, maxVal, defaultVal, callback)
	local container = Instance.new("Frame")
	container.Size = UDim2.new(1, -10, 0, 50)
	container.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
	container.Parent = scrollingFrame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = container

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -10, 0, 22)
	label.Position = UDim2.new(0, 10, 0, 4)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextSize = 13
	label.Font = Enum.Font.GothamSemibold
	label.Text = name .. ": " .. defaultVal
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = container

	local sliderBar = Instance.new("Frame")
	sliderBar.Size = UDim2.new(1, -20, 0, 6)
	sliderBar.Position = UDim2.new(0, 10, 0, 32)
	sliderBar.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
	sliderBar.BorderSizePixel = 0
	sliderBar.Parent = container

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(1, 0)
	barCorner.Parent = sliderBar

	local handle = Instance.new("TextButton")
	handle.Size = UDim2.new(0, 16, 0, 16)
	local percent = (defaultVal - minVal) / (maxVal - minVal)
	handle.Position = UDim2.new(percent, -8, 0.5, -8)
	handle.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
	handle.Text = ""
	handle.Parent = sliderBar

	local handleCorner = Instance.new("UICorner")
	handleCorner.CornerRadius = UDim.new(1, 0)
	handleCorner.Parent = handle

	local sliding = false

	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			sliding = true
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			sliding = false
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local absPos = sliderBar.AbsolutePosition.X
			local absSize = sliderBar.AbsoluteSize.X
			local mouseX = input.Position.X
			local p = math.clamp((mouseX - absPos) / absSize, 0, 1)
			
			handle.Position = UDim2.new(p, -8, 0.5, -8)
			local val = math.floor(minVal + p * (maxVal - minVal))
			label.Text = name .. ": " .. val
			callback(val)
		end
	end)
end

local function createCFrameSpeedControl()
    local CONFIG_FILE = "SpeedCFrame_Config.json"
    local config = {
        Active = false,
        Speed = 1
    }

    -- Load config only when the current environment supports file APIs.
    pcall(function()
        if isfile and readfile and isfile(CONFIG_FILE) then
            local saved = HttpService:JSONDecode(readfile(CONFIG_FILE))
            if type(saved) == "table" then
                config.Active = saved.Active == true
                config.Speed = math.clamp(tonumber(saved.Speed) or 1, 0, 100)
            end
        end
    end)

    local function saveConfig()
        pcall(function()
            if writefile then
                writefile(CONFIG_FILE, HttpService:JSONEncode(config))
            end
        end)
    end

    local container = Instance.new("Frame")
    container.Name = "CFrameSpeedControl"
    container.Size = UDim2.new(1, -10, 0, 100)
    container.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    container.BorderSizePixel = 0
    container.Parent = scrollingFrame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = container

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 0, 25)
    title.Position = UDim2.new(0, 10, 0, 4)
    title.BackgroundTransparency = 1
    title.Text = "🚀 CFrame Speed"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 14
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = container

    local inputBox = Instance.new("TextBox")
    inputBox.Size = UDim2.new(0.55, -5, 0, 32)
    inputBox.Position = UDim2.new(0, 10, 0, 42)
    inputBox.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    inputBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    inputBox.PlaceholderText = "Speed (0–100)"
    inputBox.Text = tostring(config.Speed)
    inputBox.TextSize = 14
    inputBox.Font = Enum.Font.Gotham
    inputBox.ClearTextOnFocus = false
    inputBox.Parent = container

    local inputCorner = Instance.new("UICorner")
    inputCorner.CornerRadius = UDim.new(0, 6)
    inputCorner.Parent = inputBox

    local toggleButton = Instance.new("TextButton")
    toggleButton.Size = UDim2.new(0.45, -15, 0, 32)
    toggleButton.Position = UDim2.new(0.55, 5, 0, 42)
    toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleButton.TextSize = 13
    toggleButton.Font = Enum.Font.GothamBold
    toggleButton.Parent = container

    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(0, 6)
    toggleCorner.Parent = toggleButton

    local function updateVisual()
        toggleButton.Text = config.Active and "Speed: ON" or "Speed: OFF"
        local targetColor = config.Active
            and Color3.fromRGB(50, 170, 70)
            or Color3.fromRGB(180, 50, 50)

        TweenService:Create(
            toggleButton,
            TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {BackgroundColor3 = targetColor}
        ):Play()
    end

    inputBox.FocusLost:Connect(function()
        local value = tonumber(inputBox.Text)
        if value and value >= 0 and value <= 100 then
            config.Speed = value
            inputBox.Text = tostring(value)
            saveConfig()
        else
            inputBox.Text = tostring(config.Speed)
        end
    end)

    toggleButton.MouseButton1Click:Connect(function()
        config.Active = not config.Active
        updateVisual()
        saveConfig()
    end)

    -- Reacquire the current character every frame so respawns are handled.
    local movementConnection
    movementConnection = RunService.Heartbeat:Connect(function()
        if not config.Active or config.Speed <= 0 then
            return
        end

        local character = localPlayer.Character
        if not character then
            return
        end

        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local rootPart = character:FindFirstChild("HumanoidRootPart")

        if humanoid and rootPart and humanoid.Health > 0 then
            local direction = humanoid.MoveDirection
            if direction.Magnitude > 0 then
                rootPart.CFrame = rootPart.CFrame + direction * config.Speed
            end
        end
    end)

    container.Destroying:Connect(function()
        if movementConnection then
            movementConnection:Disconnect()
            movementConnection = nil
        end
    end)

    updateVisual()
end



-- =========================================
-- 6B. REALISTIC CAMERA EFFECTS
-- Hiệu ứng chỉ tác động camera cục bộ, không thay đổi vị trí nhân vật.
-- =========================================
local cameraShakeEnabled = true
local walkingShakeEnabled = true
local runningShakeEnabled = true
local impactShakeEnabled = true
local idleSwayEnabled = true
local cameraShakeIntensity = 0.5 -- 0.0 tới 1.0
local cameraTime = 0
local impactStrength = 0
-- Theo chuyển động đầu: lấy góc đầu tương đối với thân, làm mượt để tránh giật.
local headFollowEnabled = false -- OFF mặc định để không ép góc nhìn người chơi
local smoothedHeadPitch, smoothedHeadYaw, smoothedHeadRoll = 0, 0, 0
local previousHumanoidStateConnection
local cameraStateConnection

local function bindCameraState(character)
    if previousHumanoidStateConnection then
        previousHumanoidStateConnection:Disconnect()
        previousHumanoidStateConnection = nil
    end
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        previousHumanoidStateConnection = humanoid.StateChanged:Connect(function(_, newState)
            if impactShakeEnabled and newState == Enum.HumanoidStateType.Landed then
                impactStrength = math.max(impactStrength, 1)
            end
        end)
    end
end

if localPlayer.Character then bindCameraState(localPlayer.Character) end
local characterAddedCameraConnection = localPlayer.CharacterAdded:Connect(function(character)
    task.wait(0.2)
    bindCameraState(character)
end)

RunService:BindToRenderStep("ZitHubRealisticCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
    if not cameraShakeEnabled then return end
    local camera = workspace.CurrentCamera
    local character = localPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not camera or not humanoid then return end

    cameraTime += math.min(dt, 0.05)
    local moving = humanoid.MoveDirection.Magnitude > 0.05
    local speed = humanoid.MoveDirection.Magnitude * humanoid.WalkSpeed
    local running = moving and speed > 18
    local x, y, roll = 0, 0, 0
    local headPitch, headYaw, headRoll = 0, 0, 0

    -- Realistic bundle thường animate đầu/cổ; chỉ lấy góc đầu so với thân,
    -- không gắn camera vào Head nên vẫn giữ góc nhìn Roblox bình thường.
    local root = character:FindFirstChild("HumanoidRootPart")
    local head = character:FindFirstChild("Head")
    if headFollowEnabled and root and head then
        local relativeHead = root.CFrame:ToObjectSpace(head.CFrame)
        -- Đọc đủ 3 trục từ hướng đầu so với thân; CFrame của Head đã phản ánh
        -- chuyển động cổ/đầu mà animation đang áp dụng.
        local pitch, yaw, headRelativeRoll = relativeHead:ToOrientation()
        headPitch = math.clamp(pitch, math.rad(-18), math.rad(18))
        headYaw = math.clamp(yaw, math.rad(-18), math.rad(18))
        headRoll = math.clamp(headRelativeRoll, math.rad(-8), math.rad(8))
    end
    local smoothAlpha = 1 - math.exp(-math.min(dt, 0.05) * 7)
    smoothedHeadPitch += (headPitch - smoothedHeadPitch) * smoothAlpha
    smoothedHeadYaw += (headYaw - smoothedHeadYaw) * smoothAlpha
    smoothedHeadRoll += (headRoll - smoothedHeadRoll) * smoothAlpha

    if moving and ((running and runningShakeEnabled) or (not running and walkingShakeEnabled)) then
        local rate = running and 13 or 8
        local amount = (running and 0.045 or 0.022) * cameraShakeIntensity
        y += math.abs(math.sin(cameraTime * rate)) * amount
        x += math.sin(cameraTime * rate * 0.5) * amount * 0.55
        roll += math.sin(cameraTime * rate * 0.5) * amount * 0.35
    elseif not moving and idleSwayEnabled then
        -- Idle sway tăng rõ hơn: chuyển động chậm, lệch pha để giống camera cầm tay.
        -- Vẫn nhân với Camera Intensity để người chơi tự giảm/tăng được.
        local amount = 0.070 * cameraShakeIntensity -- tăng gấp đôi so với bản Stronger
        x += math.sin(cameraTime * 1.05) * amount
        y += math.sin(cameraTime * 1.45 + 0.6) * amount * 0.75
        roll += math.sin(cameraTime * 0.9 + 0.3) * amount * 0.22
    end

    if impactShakeEnabled and impactStrength > 0.001 then
        local decay = math.min(dt * 5, 1)
        y -= 0.09 * impactStrength * cameraShakeIntensity
        x += math.sin(cameraTime * 35) * 0.035 * impactStrength * cameraShakeIntensity
        roll += math.sin(cameraTime * 28) * 0.025 * impactStrength * cameraShakeIntensity
        impactStrength *= (1 - decay)
    end

    -- Camera shake only: tidak ikut yaw/pitch/roll của đầu để tránh tự xoay.
    -- Người chơi luôn giữ toàn quyền điều khiển hướng nhìn bằng chuột.
    -- Chỉ thêm chuyển động tịnh tiến rất nhẹ và roll quanh trục nhìn.
    camera.CFrame = camera.CFrame
        * CFrame.new(x, y, 0)
        * CFrame.Angles(0, 0, roll)
end)

screenGui.Destroying:Connect(function()
    pcall(function() RunService:UnbindFromRenderStep("ZitHubRealisticCamera") end)
    if previousHumanoidStateConnection then previousHumanoidStateConnection:Disconnect() end
    if characterAddedCameraConnection then characterAddedCameraConnection:Disconnect() end
end)

-- =========================================
-- 7. THÊM CÁC TÍNH NĂNG VÀO MENU
-- =========================================

createButton("🌅 Bật Shader: Alonely", Color3.fromRGB(210, 105, 30), applyShader1)
createButton("☀️ Bật Shader: Cottage", Color3.fromRGB(50, 150, 100), applyShader2)
createButton("🔄 Xóa Hiệu Ứng (Mặc Định)", Color3.fromRGB(90, 90, 90), applyShader3)

-- Realistic Camera Shake controls
createButton("🎥 Camera Shake: ON", Color3.fromRGB(45, 145, 95), function()
    cameraShakeEnabled = not cameraShakeEnabled
    -- Cập nhật nhãn nút sau khi bật/tắt
    for _, item in ipairs(scrollingFrame:GetChildren()) do
        if item:IsA("TextButton") and (item.Text == "🎥 Camera Shake: ON" or item.Text == "🎥 Camera Shake: OFF") then
            item.Text = cameraShakeEnabled and "🎥 Camera Shake: ON" or "🎥 Camera Shake: OFF"
            item.BackgroundColor3 = cameraShakeEnabled and Color3.fromRGB(45, 145, 95) or Color3.fromRGB(70, 95, 150)
        end
    end
end)
local function createToggleButton(label, initialState, callback)
    local state = initialState
    local btn
    local function refresh()
        btn.Text = label .. (state and ": ON" or ": OFF")
        btn.BackgroundColor3 = state and Color3.fromRGB(45, 145, 95) or Color3.fromRGB(70, 95, 150)
    end
    btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -10, 0, 38)
    btn.BackgroundColor3 = Color3.fromRGB(45, 145, 95)
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 14
    btn.Font = Enum.Font.GothamSemibold
    btn.Parent = scrollingFrame
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = btn
    refresh()
    btn.Activated:Connect(function()
        state = not state
        callback(state)
        refresh()
    end)
end

createToggleButton("🚶 Walking Shake", walkingShakeEnabled, function(state)
    walkingShakeEnabled = state
end)
createToggleButton("🏃 Running Shake", runningShakeEnabled, function(state)
    runningShakeEnabled = state
end)
createToggleButton("💥 Impact Shake", impactShakeEnabled, function(state)
    impactShakeEnabled = state
    if not state then impactStrength = 0 end
end)
createToggleButton("🌬️ Idle Sway", idleSwayEnabled, function(state)
    idleSwayEnabled = state
end)
createToggleButton("🧠 Head Follow", headFollowEnabled, function(state)
    headFollowEnabled = state
    if not state then
        smoothedHeadPitch, smoothedHeadYaw, smoothedHeadRoll = 0, 0, 0
    end
end)
createSlider("🎚️ Camera Intensity (%)", 0, 100, 50, function(value)
    cameraShakeIntensity = value / 100
end)

-- Tốc độ WalkSpeed (Đã gắn thêm cơ chế lưu và tự áp dụng khi nhân vật hồi sinh)
createSlider("⚡ Tốc Độ (WalkSpeed)", 1, 100, 1, function(speed)
	currentWalkSpeed = speed
	local character = localPlayer.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = speed
		end
	end
end)

-- Lắng nghe sự kiện nhân vật hồi sinh để tự động khôi phục WalkSpeed
localPlayer.CharacterAdded:Connect(function(character)
	task.wait(0.3) -- Chờ chút cho nhân vật load hoàn tất
	local humanoid = character:WaitForChild("Humanoid", 5)
	if humanoid then
		humanoid.WalkSpeed = currentWalkSpeed
	end
end)

-- Ô nhập liệu & Nút bật tắt CFrame Speed
createCFrameSpeedControl()
