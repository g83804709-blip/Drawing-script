-- LocalScript
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local mouse = player:GetMouse()

-- ============ KONFIGURASI ============
local CONFIG = {
	ScanRadius = 100,
	PixelSize = 2,
	DrawColor = Color3.fromRGB(0, 0, 0),
	AutoScanTarget = true,
	TargetNameKeywords = {"draw", "canvas", "paint", "board", "art"},
	CalibrationMode = false,
}

-- ============ STATE ============
local State = {
	isActive = false,
	targetPart = nil,
	targetGui = nil,
	targetFrame = nil,
	scanConn = nil,
	drawConn = nil,
	lastPixel = Vector2.new(-1, -1),
	pixelCache = {},
}

-- ============ GUI ============
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AutoDrawGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = player:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 260, 0, 200)
mainFrame.Position = UDim2.new(0.5, -130, 0.5, -100)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)

local stroke = Instance.new("UIStroke", mainFrame)
stroke.Color = Color3.fromRGB(60, 60, 80)
stroke.Thickness = 1

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 32)
title.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
title.BorderSizePixel = 0
title.Text = "⚡ Auto Draw Scanner"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.Parent = mainFrame

local titleCorner = Instance.new("UICorner", title)
titleCorner.CornerRadius = UDim.new(0, 10)

local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0, 220, 0, 45)
toggleBtn.Position = UDim2.new(0.5, -110, 0, 45)
toggleBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
toggleBtn.BorderSizePixel = 0
toggleBtn.Text = "OFF"
toggleBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 18
toggleBtn.Parent = mainFrame

Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 8)

local infoLabel = Instance.new("TextLabel")
infoLabel.Size = UDim2.new(1, -20, 0, 18)
infoLabel.Position = UDim2.new(0, 10, 0, 95)
infoLabel.BackgroundTransparency = 1
infoLabel.Text = "Status: Idle"
infoLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
infoLabel.Font = Enum.Font.Gotham
infoLabel.TextSize = 12
infoLabel.TextXAlignment = Enum.TextXAlignment.Left
infoLabel.Parent = mainFrame

local targetLabel = Instance.new("TextLabel")
targetLabel.Size = UDim2.new(1, -20, 0, 18)
targetLabel.Position = UDim2.new(0, 10, 0, 115)
targetLabel.BackgroundTransparency = 1
targetLabel.Text = "Target: -"
targetLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
targetLabel.Font = Enum.Font.Gotham
targetLabel.TextSize = 12
targetLabel.TextXAlignment = Enum.TextXAlignment.Left
targetLabel.Parent = mainFrame

local pixelLabel = Instance.new("TextLabel")
pixelLabel.Size = UDim2.new(1, -20, 0, 18)
pixelLabel.Position = UDim2.new(0, 10, 0, 135)
pixelLabel.BackgroundTransparency = 1
pixelLabel.Text = "Pixels: 0"
pixelLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
pixelLabel.Font = Enum.Font.Gotham
pixelLabel.TextSize = 12
pixelLabel.TextXAlignment = Enum.TextXAlignment.Left
pixelLabel.Parent = mainFrame

local clearBtn = Instance.new("TextButton")
clearBtn.Size = UDim2.new(0, 100, 0, 28)
clearBtn.Position = UDim2.new(0, 10, 1, -38)
clearBtn.BackgroundColor3 = Color3.fromRGB(80, 40, 40)
clearBtn.BorderSizePixel = 0
clearBtn.Text = "Clear Canvas"
clearBtn.TextColor3 = Color3.fromRGB(255, 200, 200)
clearBtn.Font = Enum.Font.GothamBold
clearBtn.TextSize = 12
clearBtn.Parent = mainFrame

Instance.new("UICorner", clearBtn).CornerRadius = UDim.new(0, 6)

local rescanBtn = Instance.new("TextButton")
rescanBtn.Size = UDim2.new(0, 100, 0, 28)
rescanBtn.Position = UDim2.new(1, -110, 1, -38)
rescanBtn.BackgroundColor3 = Color3.fromRGB(40, 60, 80)
rescanBtn.BorderSizePixel = 0
rescanBtn.Text = "Rescan Target"
rescanBtn.TextColor3 = Color3.fromRGB(200, 220, 255)
rescanBtn.Font = Enum.Font.GothamBold
rescanBtn.TextSize = 12
rescanBtn.Parent = mainFrame

Instance.new("UICorner", rescanBtn).CornerRadius = UDim.new(0, 6)

-- ============ FUNGSI SCAN TARGET ============
local function isTargetName(name)
	local lower = name:lower()
	for _, kw in ipairs(CONFIG.TargetNameKeywords) do
		if lower:find(kw) then return true end
	end
	return false
end

local function findDrawSurface(part)
	if part:FindFirstChildOfClass("SurfaceGui") then
		return part:FindFirstChildOfClass("SurfaceGui")
	end
	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("SurfaceGui") then return child end
		if child:IsA("BillboardGui") then return child end
	end
	return nil
end

local function findDrawFrame(gui)
	local frame = gui:FindFirstChildOfClass("Frame")
	if frame then return frame end
	for _, child in ipairs(gui:GetDescendants()) do
		if child:IsA("Frame") and child.Size.X.Scale > 0.5 then
			return child
		end
	end
	return nil
end

local function scanForTarget()
	local closest = nil
	local shortestDist = CONFIG.ScanRadius
	local camPos = camera.CFrame.Position

	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("BasePart") and isTargetName(obj.Name) then
			local gui = findDrawSurface(obj)
			if gui then
				local dist = (obj.Position - camPos).Magnitude
				if dist < shortestDist then
					shortestDist = dist
					closest = obj
				end
			end
		end
	end

	return closest
end

-- ============ HITUNG UV PRESISI ============
-- Menggunakan metode SurfaceGui face detection untuk akurasi penuh
local function getSurfaceUV(part, surfaceGui, hitPos, hitNormal)
	local localPos = part.CFrame:PointToObjectSpace(hitPos)
	local halfSize = part.Size / 2

	local face = surfaceGui.Face
	local u, v

	if face == Enum.NormalId.Front then
		u = (localPos.X + halfSize.X) / part.Size.X
		v = (halfSize.Y - localPos.Y) / part.Size.Y
	elseif face == Enum.NormalId.Back then
		u = (halfSize.X - localPos.X) / part.Size.X
		v = (halfSize.Y - localPos.Y) / part.Size.Y
	elseif face == Enum.NormalId.Right then
		u = (halfSize.Z - localPos.Z) / part.Size.Z
		v = (halfSize.Y - localPos.Y) / part.Size.Y
	elseif face == Enum.NormalId.Left then
		u = (localPos.Z + halfSize.Z) / part.Size.Z
		v = (halfSize.Y - localPos.Y) / part.Size.Y
	elseif face == Enum.NormalId.Top then
		u = (localPos.X + halfSize.X) / part.Size.X
		v = (localPos.Z + halfSize.Z) / part.Size.Z
	elseif face == Enum.NormalId.Bottom then
		u = (localPos.X + halfSize.X) / part.Size.X
		v = (halfSize.Z - localPos.Z) / part.Size.Z
	else
		u = 0.5
		v = 0.5
	end

	return Vector2.new(
		math.clamp(u, 0, 1),
		math.clamp(v, 0, 1)
	)
end

-- ============ GAMBAR PIXEL ============
local function placePixel(uv)
	local pixelKey = string.format("%.4f_%.4f", uv.X, uv.Y)
	if State.pixelCache[pixelKey] then return false end

	local frame = State.targetFrame
	if not frame then return false end

	-- Cek apakah di posisi ini sudah ada pixel
	local pixel = Instance.new("Frame")
	pixel.Name = "DrawPixel"
	pixel.Size = UDim2.new(0, CONFIG.PixelSize, 0, CONFIG.PixelSize)
	pixel.Position = UDim2.new(uv.X, -CONFIG.PixelSize / 2, uv.Y, -CONFIG.PixelSize / 2)
	pixel.BackgroundColor3 = CONFIG.DrawColor
	pixel.BorderSizePixel = 0
	pixel.ZIndex = 2
	pixel.Parent = frame

	State.pixelCache[pixelKey] = pixel
	return true
end

-- ============ TRY REMOTE EVENT (untuk game yang pakai sistem remote) ============
local function tryRemoteDraw(uv)
	-- Cari RemoteEvent di ReplicatedStorage atau game yang berkaitan dengan drawing
	local remotes = {}
	for _, obj in ipairs(game:GetDescendants()) do
		if obj:IsA("RemoteEvent") and (obj.Name:lower():find("draw") or obj.Name:lower():find("paint") or obj.Name:lower():find("pixel")) then
			table.insert(remotes, obj)
		end
	end

	for _, remote in ipairs(remotes) do
		pcall(function()
			remote:FireServer(uv, CONFIG.DrawColor)
		end)
	end
end

-- ============ SCAN LOOP ============
local function startScanLoop()
	State.scanConn = RunService.Heartbeat:Connect(function()
		if not CONFIG.AutoScanTarget then return end
		if State.targetPart and State.targetPart.Parent then return end

		local found = scanForTarget()
		if found then
			State.targetPart = found
			State.targetGui = findDrawSurface(found)
			State.targetFrame = findDrawFrame(State.targetGui)
			targetLabel.Text = "Target: " .. found.Name
			targetLabel.TextColor3 = Color3.fromRGB(80, 255, 120)
			infoLabel.Text = "Status: Target locked"
		end
	end)
end

-- ============ DRAW LOOP ============
local function startDrawLoop()
	State.drawConn = RunService.RenderStepped:Connect(function()
		if not State.isActive then return end
		if not State.targetPart or not State.targetPart.Parent then
			State.targetPart = nil
			State.targetGui = nil
			State.targetFrame = nil
			infoLabel.Text = "Status: Target lost"
			infoLabel.TextColor3 = Color3.fromRGB(255, 200, 80)
			return
		end

		-- Raycast dari kamera ke mouse
		local mousePos = UserInputService:GetMouseLocation()
		local unitRay = camera:ViewportPointToRay(mousePos.X, mousePos.Y)
		local params = RaycastParams.new()
		params.FilterDescendantsInstances = { player.Character, screenGui }
		params.FilterType = Enum.RaycastFilterType.Exclude

		local result = Workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, params)
		if not result then return end
		if result.Instance ~= State.targetPart then return end

		local surfaceGui = State.targetGui
		if not surfaceGui then return end

		local uv = getSurfaceUV(State.targetPart, surfaceGui, result.Position, result.Normal)

		-- Coba dua metode: UI pixel + remote event
		local placed = placePixel(uv)
		tryRemoteDraw(uv)

		if placed then
			local count = 0
			for _ in pairs(State.pixelCache) do count = count + 1 end
			pixelLabel.Text = "Pixels: " .. count
		end
	end)
end

-- ============ TOGGLE ============
toggleBtn.MouseButton1Click:Connect(function()
	State.isActive = not State.isActive

	if State.isActive then
		toggleBtn.Text = "ON"
		toggleBtn.TextColor3 = Color3.fromRGB(80, 255, 120)
		toggleBtn.BackgroundColor3 = Color3.fromRGB(40, 80, 50)
		infoLabel.Text = "Status: Active"
		infoLabel.TextColor3 = Color3.fromRGB(80, 255, 120)

		if not State.targetPart then
			local found = scanForTarget()
			if found then
				State.targetPart = found
				State.targetGui = findDrawSurface(found)
				State.targetFrame = findDrawFrame(State.targetGui)
				targetLabel.Text = "Target: " .. found.Name
			end
		end

		startScanLoop()
		startDrawLoop()
	else
		toggleBtn.Text = "OFF"
		toggleBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
		toggleBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
		infoLabel.Text = "Status: Idle"
		infoLabel.TextColor3 = Color3.fromRGB(180, 180, 200)

		if State.scanConn then State.scanConn:Disconnect() State.scanConn = nil end
		if State.drawConn then State.drawConn:Disconnect() State.drawConn = nil end
	end
end)

-- ============ CLEAR ============
clearBtn.MouseButton1Click:Connect(function()
	if State.targetFrame then
		for _, child in ipairs(State.targetFrame:GetChildren()) do
			if child.Name == "DrawPixel" then
				child:Destroy()
			end
		end
	end
	State.pixelCache = {}
	pixelLabel.Text = "Pixels: 0"
end)

-- ============ RESCAN ============
rescanBtn.MouseButton1Click:Connect(function()
	State.targetPart = nil
	State.targetGui = nil
	State.targetFrame = nil
	targetLabel.Text = "Target: -"
	targetLabel.TextColor3 = Color3.fromRGB(255, 200, 80)
	infoLabel.Text = "Status: Rescanning..."

	local found = scanForTarget()
	if found then
		State.targetPart = found
		State.targetGui = findDrawSurface(found)
		State.targetFrame = findDrawFrame(State.targetGui)
		targetLabel.Text = "Target: " .. found.Name
		targetLabel.TextColor3 = Color3.fromRGB(80, 255, 120)
		infoLabel.Text = "Status: Target locked"
	end
end)
