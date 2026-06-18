local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Options = Library.Options
local Toggles = Library.Toggles
local ImageManager = Library.ImageManager

ImageManager.AddAsset("chillhub_icon", 0, "https://cdn.discordapp.com/attachments/1439230029572739132/1511552905591652444/IMG_20260419_122232-removebg-preview.png?ex=6a34a557&is=6a3353d7&hm=46be9ecf877fe8194a33d46905fe55ba8de3237d52f6a8b67229c2a82135f138")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local VirtualUser = game:GetService("VirtualUser")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local plr = Players.LocalPlayer
local cam = Workspace.CurrentCamera

local netBase = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("leifstout_networker@0.3.1"):WaitForChild("networker"):WaitForChild("_remotes")
local SlimeGunRemote = netBase:WaitForChild("SlimeGunService"):WaitForChild("RemoteFunction")
local ZonesRemote = netBase:WaitForChild("ZonesService"):WaitForChild("RemoteFunction")
local InventoryRemote = netBase:WaitForChild("InventoryService"):WaitForChild("RemoteFunction")
local RollRemote = netBase:WaitForChild("RollService"):WaitForChild("RemoteFunction")
local RebirthRemote = netBase:WaitForChild("RebirthService"):WaitForChild("RemoteFunction")
local UpgradeRemote = netBase:WaitForChild("UpgradeService"):WaitForChild("RemoteFunction")
local IndexRemote = netBase:WaitForChild("IndexService"):WaitForChild("RemoteFunction")
local BoostRemote = netBase:WaitForChild("BoostService"):WaitForChild("RemoteFunction")

local function getFlag(n)
	local t = Toggles[n]
	if t then return t.Value end
	return false
end

local State = {
	humanizer = false,
	espEnabled = false,
	espColor = Color3.fromRGB(255, 60, 60),
	espMode = {},
	lastJump = 0,
	currentZoneNum = -1,
	zoneSpawnPos = nil,
	lastZoneScan = 0,
	isTravelingToZone = false,
	zoneCooldownEnd = 0,
	hasArrived = false,
	activeTask = "idle",
	lastEnemyMove = 0,
	lastLootTime = 0,
	lastM1Time = 0,
	m1Down = false,
	eDown = false,
	feedSlimes = {},
	feedFood = {}
}

local function fireSlimeGun(m)
	if not m or not m.Parent then return end
	pcall(function() SlimeGunRemote:InvokeServer("tryFireSlimeGun", m) end)
end

local function purchaseNextZone()
	pcall(function() ZonesRemote:InvokeServer("requestPurchaseZone") end)
end

local function equipBest()
	pcall(function() InventoryRemote:InvokeServer("requestEquipBest") end)
end

local function doRoll()
	pcall(function() RollRemote:InvokeServer("requestRoll") end)
end

local function doRebirth()
	pcall(function() RebirthRemote:InvokeServer("requestRebirth") end)
end

local function doUpgrade(upgradeName)
	pcall(function() UpgradeRemote:InvokeServer("requestUnlock", upgradeName) end)
end

local function claimIndexReward(rewardType)
	pcall(function() IndexRemote:InvokeServer("requestClaimReward", rewardType) end)
end

local function useBoost(boostType)
	pcall(function() BoostRemote:InvokeServer("requestUseBoost", boostType) end)
end

local function teleportToZone(zoneNum)
	pcall(function() ZonesRemote:InvokeServer("requestTeleportZone", zoneNum) end)
end

local function setM1(d)
	if State.m1Down == d then return end
	State.m1Down = d
	pcall(function() VirtualInputManager:SendMouseButtonEvent(0, 0, 0, d, game, 0) end)
end

local function setE(d)
	if State.eDown == d then return end
	State.eDown = d
	pcall(function() VirtualInputManager:SendKeyEvent(d, Enum.KeyCode.E, false, game) end)
end

local function releaseAll()
	setM1(false)
	setE(false)
end

local function getChar()
	return plr.Character
end

local function getHum()
	local c = getChar()
	return c and c:FindFirstChildOfClass("Humanoid")
end

local function getHRP()
	local c = getChar()
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function getPos(o)
	if not o then return nil end
	if o:IsA("Model") then
		local p = o:GetPivot()
		return p and p.Position
	end
	if o:IsA("BasePart") then return o.Position end
	return nil
end

local function distToPos(p)
	local h = getHRP()
	if not h or not p then return 9e9 end
	return (h.Position - p).Magnitude
end

local function rng(a, b)
	return a + math.random() * (b - a)
end

local function getGameplayFolder()
	for _, o in ipairs(Workspace:GetChildren()) do
		if type(o.Name) == "string" and string.find(o.Name, "Gameplay") then
			return o
		end
	end
	return nil
end

local function getSlimesFolder()
	local gp = getGameplayFolder()
	if gp then return gp:FindFirstChild("Slimes") end
	return nil
end

local function cleanSlimeId(rawId)
	if type(rawId) ~= "string" then return tostring(rawId) end
	return rawId:gsub("#%d+$", "")
end

local function parseRarity(text)
	if type(text) ~= "string" then return nil end
	local numStr = text:match("/%s*([%d%.]+)")
	if not numStr then return nil end
	local last2 = string.sub(numStr, -2)
	local last1 = string.sub(numStr, -1)
	if last2 == "qd" then
		local n = tonumber(string.sub(numStr, 1, -3))
		return n and n * 1e15 or nil
	elseif last2 == "qn" then
		local n = tonumber(string.sub(numStr, 1, -3))
		return n and n * 1e18 or nil
	elseif last1 == "k" then
		local n = tonumber(string.sub(numStr, 1, -2))
		return n and n * 1e3 or nil
	elseif last1 == "m" then
		local n = tonumber(string.sub(numStr, 1, -2))
		return n and n * 1e6 or nil
	elseif last1 == "b" then
		local n = tonumber(string.sub(numStr, 1, -2))
		return n and n * 1e9 or nil
	elseif last1 == "t" then
		local n = tonumber(string.sub(numStr, 1, -2))
		return n and n * 1e12 or nil
	end
	return tonumber(numStr)
end

local CachedSlimes = {}
local CachedSlimeMap = {}

local function scanSlimes()
	local folder = getSlimesFolder()
	if not folder then
		CachedSlimes = {}
		CachedSlimeMap = {}
		return {}
	end
	local slimes = {}
	local currentIds = {}
	for _, slime in ipairs(folder:GetChildren()) do
		if slime:IsA("Model") then
			local billboard = slime:FindFirstChild("SlimeInfoBillboard")
			if billboard then
				local content = billboard:FindFirstChild("Content")
				if content then
					local oddsFolder = content:FindFirstChild("Odds")
					local nameLabel = content:FindFirstChild("Name")
					if oddsFolder and nameLabel then
						local oddsLabel = oddsFolder:FindFirstChild("TextLabel")
						if oddsLabel then
							local oddsText = tostring(oddsLabel.Text)
							local nameText = tostring(nameLabel.Text)
							if nameText ~= "" and oddsText ~= "" then
								local lowerOdds = string.lower(oddsText)
								local rarity = parseRarity(lowerOdds)
								if rarity then
									local cleanId = cleanSlimeId(slime.Name)
									local display = nameText .. " (" .. oddsText .. ")"
									table.insert(slimes, {
										display = display,
										name = nameText,
										rarity = rarity,
										rawText = oddsText,
										slimeId = cleanId,
										object = slime
									})
									currentIds[cleanId] = true
								end
							end
						end
					end
				end
			end
		end
	end
	table.sort(slimes, function(a, b) return a.rarity > b.rarity end)
	CachedSlimes = slimes
	CachedSlimeMap = currentIds
	return slimes
end

local VALID_FOODS = {"Cheese", "Egg", "Fries", "Taco", "Hotdog", "Burger", "Pizza", "Chicken", "Drumstick"}

local function getFoodList()
	return VALID_FOODS
end

local function getHighestOwnedZone()
	local zones = Workspace:FindFirstChild("Zones")
	if not zones then return nil, nil end
	local bestNum, bestZone = -1, nil
	for _, z in ipairs(zones:GetChildren()) do
		local num = tonumber(z.Name)
		if num and num > bestNum then
			local gate = z:FindFirstChild("Gate")
			if gate then
				local back = gate:FindFirstChild("Back")
				if back and back:IsA("BasePart") and back.CanTouch == false then
					bestNum = num
					bestZone = z
				end
			end
		end
	end
	if bestZone then
		local poi = bestZone:FindFirstChild("POI")
		if poi then
			local sp = poi:FindFirstChild("PlayerSpawn")
			if sp then return bestNum, getPos(sp) end
		end
	end
	return nil, nil
end

local function getZoneSpawn(num)
	local zones = Workspace:FindFirstChild("Zones")
	if not zones then return nil end
	local z = zones:FindFirstChild(tostring(num))
	if not z then return nil end
	local poi = z:FindFirstChild("POI")
	if not poi then return nil end
	local sp = poi:FindFirstChild("PlayerSpawn")
	if not sp then return nil end
	return getPos(sp)
end

local function parseHealthText(t)
	if type(t) ~= "string" then return nil, nil end
	t = t:gsub("%s+", "")
	local curStr, maxStr = t:match("^([%d%.]+[KMB]?)/([%d%.]+[KMB]?)$")
	if not curStr then return nil, nil end
	local function toNum(s)
		local suf = s:sub(-1):upper()
		local mult = 1
		if suf == "K" then
			mult = 1e3
			s = s:sub(1, -2)
		elseif suf == "M" then
			mult = 1e6
			s = s:sub(1, -2)
		elseif suf == "B" then
			mult = 1e9
			s = s:sub(1, -2)
		end
		local n = tonumber(s)
		return n and n * mult or nil
	end
	return toNum(curStr), toNum(maxStr)
end

local function getEnemyHealth(e)
	local bb = e:FindFirstChild("HealthBarBillboardGui")
	if not bb then return nil, nil end
	local hp = bb:FindFirstChild("Hp")
	if not hp then return nil, nil end
	return parseHealthText(hp.Text)
end

local function getUpgradeTiles()
	local playerGui = plr:FindFirstChild("PlayerGui")
	if not playerGui then return nil end
	local root = playerGui:FindFirstChild("Root")
	if not root then return nil end
	local upgradeScreen = root:FindFirstChild("UpgradeScreen")
	if not upgradeScreen then return nil end
	local upgradeContent = upgradeScreen:FindFirstChild("UpgradeContent")
	if not upgradeContent then return nil end
	local frame = upgradeContent:FindFirstChild("Frame")
	if not frame then return nil end
	return frame:GetChildren()
end

local RayFolder = Instance.new("Folder")
RayFolder.Name = "ChillHubRays"
RayFolder.Parent = Workspace

local PathRay = Instance.new("Part")
PathRay.Name = "PathRay"
PathRay.Size = Vector3.new(0.12, 0.12, 1)
PathRay.Anchored = true
PathRay.CanCollide = false
PathRay.CanQuery = false
PathRay.CanTouch = false
PathRay.CastShadow = false
PathRay.Material = Enum.Material.Neon
PathRay.Color = Color3.fromRGB(0, 255, 200)
PathRay.Transparency = 0.15
PathRay.Parent = RayFolder

local ForwardRay = Instance.new("Part")
ForwardRay.Name = "ForwardRay"
ForwardRay.Size = Vector3.new(0.1, 0.1, 1)
ForwardRay.Anchored = true
ForwardRay.CanCollide = false
ForwardRay.CanQuery = false
ForwardRay.CanTouch = false
ForwardRay.CastShadow = false
ForwardRay.Material = Enum.Material.Neon
ForwardRay.Color = Color3.fromRGB(100, 200, 255)
ForwardRay.Transparency = 0.2
ForwardRay.Parent = RayFolder

local function updateRayPart(part, from, to, color)
	if not from or not to then
		part.Size = Vector3.new(0.01, 0.01, 0.01)
		return
	end
	local dist = (to - from).Magnitude
	if dist < 0.01 then
		part.Size = Vector3.new(0.01, 0.01, 0.01)
		return
	end
	part.Size = Vector3.new(part.Size.X, part.Size.Y, dist)
	part.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -dist / 2)
	if color then part.Color = color end
end

local function hidePathRay()
	PathRay.Size = Vector3.new(0.01, 0.01, 0.01)
end

local function getIgnoreList(target)
	local list = {getChar(), RayFolder}
	if target and target:IsA("Model") then
		for _, d in ipairs(target:GetDescendants()) do
			if d:IsA("BasePart") then
				table.insert(list, d)
			end
		end
	elseif target and target:IsA("BasePart") then
		table.insert(list, target)
	end
	return list
end

local function checkObstacle(from, to, ignoreList)
	local dir = to - from
	local dist = dir.Magnitude
	if dist < 0.1 then return "clear" end
	local unit = dir.Unit
	local checkDist = math.min(dist, 24)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Blacklist
	params.FilterDescendantsInstances = ignoreList or {}
	local waistResult = Workspace:Raycast(from + Vector3.new(0, 2.5, 0), unit * checkDist, params)
	if waistResult then
		local jumpResult = Workspace:Raycast(from + Vector3.new(0, 5.5, 0), unit * checkDist, params)
		if not jumpResult then
			return "jumpable", waistResult.Position
		else
			return "blocked", waistResult.Position
		end
	end
	return "clear"
end

local function tryJump()
	if tick() - State.lastJump > 0.22 then
		local hum = getHum()
		if hum then hum.Jump = true end
		State.lastJump = tick()
	end
end

local ESPObjects = {}

local function createESP(m, name)
	local box = Drawing.new("Square")
	box.Visible = false
	box.Filled = false
	box.Thickness = 1.5
	box.Color = State.espColor
	box.Transparency = 1

	local tracer = Drawing.new("Line")
	tracer.Visible = false
	tracer.Thickness = 1.2
	tracer.Color = State.espColor
	tracer.Transparency = 1

	local healthBg = Drawing.new("Square")
	healthBg.Visible = false
	healthBg.Filled = true
	healthBg.Thickness = 0
	healthBg.Color = Color3.fromRGB(30, 30, 30)
	healthBg.Transparency = 0.85

	local healthBar = Drawing.new("Square")
	healthBar.Visible = false
	healthBar.Filled = true
	healthBar.Thickness = 0
	healthBar.Transparency = 1

	local nameText = Drawing.new("Text")
	nameText.Visible = false
	nameText.Size = 14
	nameText.Center = true
	nameText.Outline = true
	nameText.Color = State.espColor
	nameText.Text = "Enemy"

	ESPObjects[m] = {box = box, tracer = tracer, healthBg = healthBg, healthBar = healthBar, nameText = nameText}
end

local function removeESP(m)
	local d = ESPObjects[m]
	if d then
		pcall(function() d.box:Remove() end)
		pcall(function() d.tracer:Remove() end)
		pcall(function() d.healthBg:Remove() end)
		pcall(function() d.healthBar:Remove() end)
		pcall(function() d.nameText:Remove() end)
		ESPObjects[m] = nil
	end
end

local function clearAllESP()
	for m, _ in pairs(ESPObjects) do removeESP(m) end
end

local function hasMode(name)
	for _, v in ipairs(State.espMode or {}) do
		if v == name then return true end
	end
	return false
end

local function updateESP()
	if not State.espEnabled then
		for _, d in pairs(ESPObjects) do
			pcall(function()
				d.box.Visible = false
				d.tracer.Visible = false
				d.healthBg.Visible = false
				d.healthBar.Visible = false
				d.nameText.Visible = false
			end)
		end
		return
	end
	local eFolder
	for _, o in ipairs(Workspace:GetChildren()) do
		if string.find(o.Name, "Gameplay") then
			eFolder = o:FindFirstChild("Enemies")
			break
		end
	end
	if not eFolder then clearAllESP() return end
	local enemies = eFolder:GetChildren()
	local current = {}
	for _, e in ipairs(enemies) do
		if e:IsA("Model") then
			current[e] = true
			if not ESPObjects[e] then
				local name = e.Name
				pcall(function() name = e:GetAttribute("Name") or e.Name end)
				createESP(e, name)
			end
		end
	end
	for m, _ in pairs(ESPObjects) do
		if not current[m] then removeESP(m) end
	end
	local showBox = hasMode("Box")
	local showTracer = hasMode("Tracer")
	local showHealth = hasMode("Health")
	for _, enemy in ipairs(enemies) do
		if not enemy:IsA("Model") then continue end
		local d = ESPObjects[enemy]
		if not d then continue end
		local okBB, cf, size = pcall(enemy.GetBoundingBox, enemy)
		if not okBB or not cf then continue end
		local corners = {
			cf * CFrame.new(size.X / 2, size.Y / 2, size.Z / 2),
			cf * CFrame.new(-size.X / 2, size.Y / 2, size.Z / 2),
			cf * CFrame.new(size.X / 2, -size.Y / 2, size.Z / 2),
			cf * CFrame.new(-size.X / 2, -size.Y / 2, size.Z / 2),
			cf * CFrame.new(size.X / 2, size.Y / 2, -size.Z / 2),
			cf * CFrame.new(-size.X / 2, size.Y / 2, -size.Z / 2),
			cf * CFrame.new(size.X / 2, -size.Y / 2, -size.Z / 2),
			cf * CFrame.new(-size.X / 2, -size.Y / 2, -size.Z / 2)
		}
		local minX, minY = 9e9, 9e9
		local maxX, maxY = -9e9, -9e9
		local onScreen = false
		for _, c in ipairs(corners) do
			local pos, vis = cam:WorldToViewportPoint(c.Position)
			if vis then onScreen = true end
			minX = math.min(minX, pos.X)
			minY = math.min(minY, pos.Y)
			maxX = math.max(maxX, pos.X)
			maxY = math.max(maxY, pos.Y)
		end
		if onScreen then
			local w = maxX - minX
			local h = maxY - minY
			pcall(function()
				if showBox then
					d.box.Visible = true
					d.box.Size = Vector2.new(w, h)
					d.box.Position = Vector2.new(minX, minY)
					d.box.Color = State.espColor
				else
					d.box.Visible = false
				end
				if showTracer then
					d.tracer.Visible = true
					d.tracer.From = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y)
					d.tracer.To = Vector2.new(minX + w / 2, maxY)
					d.tracer.Color = State.espColor
				else
					d.tracer.Visible = false
				end
			end)
			pcall(function()
				if showHealth then
					local cur, max = getEnemyHealth(enemy)
					if cur and max and max > 0 then
						local pct = math.clamp(cur / max, 0, 1)
						local barW = w * 0.25
						local barH = h
						local gap = 3
						local barX = minX - gap - barW
						local barY = minY
						d.healthBg.Visible = true
						d.healthBg.Size = Vector2.new(barW, barH)
						d.healthBg.Position = Vector2.new(barX, barY)
						d.healthBar.Visible = true
						d.healthBar.Size = Vector2.new(barW, barH * pct)
						d.healthBar.Position = Vector2.new(barX, barY + barH * (1 - pct))
						d.healthBar.Color = Color3.fromRGB(255 * (1 - pct), 255 * pct, 0)
					else
						d.healthBg.Visible = false
						d.healthBar.Visible = false
					end
				else
					d.healthBg.Visible = false
					d.healthBar.Visible = false
				end
			end)
			pcall(function()
				d.nameText.Visible = true
				d.nameText.Position = Vector2.new(minX + w / 2, minY - 18)
				d.nameText.Color = State.espColor
			end)
		else
			pcall(function()
				d.box.Visible = false
				d.tracer.Visible = false
				d.healthBg.Visible = false
				d.healthBar.Visible = false
				d.nameText.Visible = false
			end)
		end
	end
end

local function getEnemyFolder()
	for _, o in ipairs(Workspace:GetChildren()) do
		if string.find(o.Name, "Gameplay") then
			return o:FindFirstChild("Enemies")
		end
	end
	return nil
end

local function getNearestEnemy()
	local f = getEnemyFolder()
	if not f then return nil end
	local list = f:GetChildren()
	if #list == 0 then return nil end
	local hrp = getHRP()
	if not hrp then return nil end
	local best, bestD = nil, 9e9
	for _, e in ipairs(list) do
		if e:IsA("Model") and e.Parent then
			local p = getPos(e)
			if p then
				local d = (hrp.Position - p).Magnitude
				if d < bestD then
					bestD = d
					best = e
				end
			end
		end
	end
	return best
end

local function getNearestLoot()
	local f = Workspace:FindFirstChild("Loot")
	if not f then return nil end
	local list = f:GetChildren()
	if #list == 0 then return nil end
	local hrp = getHRP()
	if not hrp then return nil end
	local best, bestD = nil, 9e9
	for _, l in ipairs(list) do
		if l.Parent then
			local p = getPos(l)
			if p then
				local d = (hrp.Position - p).Magnitude
				if d < bestD then
					bestD = d
					best = l
				end
			end
		end
	end
	return best
end

local function getSafePosition(from, to)
	local ignore = getIgnoreList(nil)
	local st, hitPos = checkObstacle(from, to, ignore)
	if st == "clear" then return to end
	if st == "jumpable" then
		tryJump()
		return to
	end
	if st == "blocked" and hitPos then
		local offset = (to - from):Cross(Vector3.new(0, 1, 0)).Unit
		if offset.Magnitude < 0.01 then offset = Vector3.new(1, 0, 0) end
		local sideStep = hitPos + offset * 8
		local st2 = checkObstacle(from, sideStep, ignore)
		if st2 == "clear" then return sideStep end
		local otherSide = hitPos - offset * 8
		local st3 = checkObstacle(from, otherSide, ignore)
		if st3 == "clear" then return otherSide end
	end
	return to
end

local function tweenToZone(targetPos)
	local hrp = getHRP()
	local hum = getHum()
	if not hrp or not hum then return false end
	local dist = (hrp.Position - targetPos).Magnitude
	if dist <= 6 then return true end
	local wa = hrp.Anchored
	local wc = hrp.CanCollide
	pcall(function()
		hrp.Anchored = true
		hrp.CanCollide = false
	end)
	local speed = 60
	local duration = math.clamp(dist / speed, 0.6, 14)
	local safePos = getSafePosition(hrp.Position, targetPos)
	local tween = TweenService:Create(hrp, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = CFrame.new(safePos + Vector3.new(0, 4, 0))})
	tween:Play()
	local completed = false
	local conn
	conn = tween.Completed:Connect(function()
		completed = true
		if conn then conn:Disconnect() end
	end)
	local start = tick()
	while not completed do
		if tick() - start > duration + 4 then
			pcall(function() tween:Cancel() end)
			break
		end
		hrp = getHRP()
		if not hrp then
			pcall(function() tween:Cancel() end)
			break
		end
		tryJump()
		task.wait(0.06)
	end
	pcall(function()
		tween:Cancel()
		if conn then conn:Disconnect() end
		hrp = getHRP()
		if hrp and hrp.Parent then
			hrp.Anchored = wa
			hrp.CanCollide = wc
		end
	end)
	return distToPos(targetPos) <= 8
end

local function tweenToEnemy(ePos)
	local hrp = getHRP()
	local hum = getHum()
	if not hrp or not hum then return end
	local dist = (hrp.Position - ePos).Magnitude
	if dist <= 2.5 then return end
	local wa = hrp.Anchored
	local wc = hrp.CanCollide
	pcall(function()
		hrp.Anchored = true
		hrp.CanCollide = false
	end)
	local safePos = getSafePosition(hrp.Position, ePos)
	local speed = 55
	local duration = math.clamp(dist / speed, 0.3, 8)
	local tween = TweenService:Create(hrp, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = CFrame.new(safePos + Vector3.new(0, 2, 0))})
	tween:Play()
	local completed = false
	local conn
	conn = tween.Completed:Connect(function()
		completed = true
		if conn then conn:Disconnect() end
	end)
	local start = tick()
	while not completed do
		if tick() - start > duration + 3 then
			pcall(function() tween:Cancel() end)
			break
		end
		hrp = getHRP()
		if not hrp then
			pcall(function() tween:Cancel() end)
			break
		end
		task.wait(0.06)
	end
	pcall(function()
		tween:Cancel()
		if conn then conn:Disconnect() end
		hrp = getHRP()
		if hrp and hrp.Parent then
			hrp.Anchored = wa
			hrp.CanCollide = wc
		end
	end)
end

local function humanMoveToEnemy(enemy)
	local hrp = getHRP()
	local hum = getHum()
	if not hrp or not hum then return end
	local ePos = getPos(enemy)
	if not ePos then return end
	if tick() - State.lastEnemyMove > 2.2 then
		State.lastEnemyMove = tick()
		local myPos = hrp.Position
		local dir = (myPos - ePos)
		if dir.Magnitude < 0.01 then dir = Vector3.new(1, 0, 0) end
		local target = ePos + dir.Unit * 3.5
		local safePos = getSafePosition(myPos, target)
		hum:MoveTo(safePos + Vector3.new(rng(-0.4, 0.4), 0, rng(-0.4, 0.4)))
	end
end

local function moveToLoot(loot)
	local hrp = getHRP()
	local hum = getHum()
	if not hrp or not hum then return false end
	local lootPos = getPos(loot)
	if not lootPos then return false end
	local dist = (hrp.Position - lootPos).Magnitude
	if dist <= 3.5 then return true end
	local safePos = getSafePosition(hrp.Position, lootPos)
	hum:MoveTo(safePos)
	local ignore = getIgnoreList(nil)
	local status, hitPos = checkObstacle(hrp.Position, lootPos, ignore)
	if status == "jumpable" then
		tryJump()
		updateRayPart(PathRay, hrp.Position, hitPos or lootPos, Color3.fromRGB(255, 255, 0))
	elseif status == "blocked" then
		updateRayPart(PathRay, hrp.Position, hitPos or lootPos, Color3.fromRGB(255, 50, 50))
	else
		updateRayPart(PathRay, hrp.Position, lootPos, Color3.fromRGB(0, 255, 200))
	end
	return dist <= 4
end

local function collectDropsProximity()
	local hrp = getHRP()
	if not hrp then return end
	local lootFolder = Workspace:FindFirstChild("Loot")
	if not lootFolder then return end
	for _, drop in ipairs(lootFolder:GetChildren()) do
		if drop and drop.Parent then
			local root = drop:FindFirstChild("Root")
			if root then
				pcall(function()
					root.CFrame = hrp.CFrame
					if root:FindFirstChild("Attachment") then
						local prox = root.Attachment:FindFirstChild("ProximityPrompt")
						if prox then
							fireproximityprompt(prox)
						end
					end
				end)
			end
		end
	end
end

local Loading = Library:CreateLoading({
	Title = "Chill Hub",
	Icon = ImageManager.GetAsset("chillhub_icon"),
	TotalSteps = 4,
	ShowSidebar = true,
})

Loading:SetMessage("Loading...")
Loading:SetDescription("Initializing Chill Hub...")
task.wait(0.5)

Loading:SetCurrentStep(1)
Loading:SetDescription("Loading game services...")
task.wait(0.5)

Loading:SetCurrentStep(2)
Loading:ShowSidebarPage(true)
Loading.Sidebar:AddLabel("User: " .. (plr.DisplayName or plr.Name))
Loading.Sidebar:AddLabel("Game: Slime RNG")
Loading.Sidebar:AddLabel("Version: 2.0.0")
task.wait(0.5)

Loading:SetCurrentStep(3)
Loading:SetDescription("Building UI...")
task.wait(0.5)

Loading:SetCurrentStep(4)
Loading:Continue()

Library:SetFont(Enum.Font.Code)

local Window = Library:CreateWindow({
	Title = "Chill Hub",
	Footer = "Slime RNG",
	Icon = ImageManager.GetAsset("chillhub_icon"),
	NotifySide = "Right",
	ShowCustomCursor = false,
	Resizable = true,
	EnableSidebarResize = true,
	MinSidebarWidth = 200,
	SidebarCompactWidth = 56,
	CornerRadius = 20,
})

local Tabs = {
	Main = Window:AddTab("Main", "sword"),
	Rolling = Window:AddTab("Rolling", "dice-3"),
	Upgrades = Window:AddTab("Upgrades", "arrow-up"),
	Visuals = Window:AddTab("Visuals", "eye"),
	["UI Settings"] = Window:AddTab("UI Settings", "settings"),
}

local AutoFarmGroup = Tabs.Main:AddLeftGroupbox("Auto Farm")

AutoFarmGroup:AddToggle("Humanizer", {
	Text = "Humanizer",
	Default = false,
	Callback = function(Value) State.humanizer = Value end,
})

AutoFarmGroup:AddToggle("Autofarm", {
	Text = "Autofarm",
	Default = false,
})

AutoFarmGroup:AddToggle("AutoCollect", {
	Text = "Auto Collect",
	Default = false,
})

AutoFarmGroup:AddToggle("AutoCollectDrops", {
	Text = "Auto Collect Drops (Proximity)",
	Default = false,
})

AutoFarmGroup:AddToggle("AutoNextArea", {
	Text = "Auto Next Area",
	Default = false,
})

AutoFarmGroup:AddDivider()

AutoFarmGroup:AddSlider("WalkSpeed", {
	Text = "WalkSpeed",
	Default = 16,
	Min = 16,
	Max = 150,
	Rounding = 0,
	Callback = function(Value)
		local hum = getHum()
		if hum then hum.WalkSpeed = Value end
	end,
})

AutoFarmGroup:AddSlider("JumpPower", {
	Text = "JumpPower",
	Default = 50,
	Min = 50,
	Max = 300,
	Rounding = 0,
	Callback = function(Value)
		local hum = getHum()
		if hum then hum.JumpPower = Value end
	end,
})

local InventoryGroup = Tabs.Main:AddLeftGroupbox("Inventory")

InventoryGroup:AddToggle("EquipBest", {
	Text = "Equip Best",
	Default = false,
})

InventoryGroup:AddToggle("AutoFeed", {
	Text = "Auto Feed",
	Default = false,
})

local initialSlimeOptions = {}
local initialFoods = getFoodList()

pcall(function()
	local slimes = scanSlimes()
	for _, data in ipairs(slimes) do
		table.insert(initialSlimeOptions, data.display)
	end
end)

InventoryGroup:AddDropdown("FeedSlimes", {
	Values = initialSlimeOptions,
	Default = 1,
	Multi = true,
	Text = "Slimes",
	Searchable = true,
	Callback = function(Value)
		State.feedSlimes = {}
		if type(Options.FeedSlimes.Value) == "table" then
			for display, selected in pairs(Options.FeedSlimes.Value) do
				if selected then table.insert(State.feedSlimes, display) end
			end
		end
	end,
})

InventoryGroup:AddDropdown("FeedFood", {
	Values = initialFoods,
	Default = 1,
	Multi = true,
	Text = "Food",
	Callback = function(Value)
		State.feedFood = {}
		if type(Options.FeedFood.Value) == "table" then
			for food, selected in pairs(Options.FeedFood.Value) do
				if selected then table.insert(State.feedFood, food) end
			end
		end
	end,
})

local BlasterGroup = Tabs.Main:AddRightGroupbox("Blaster")

BlasterGroup:AddToggle("AutoBlaster", {
	Text = "Auto Blaster",
	Default = false,
})

BlasterGroup:AddLabel("Blaster Toggle Key"):AddKeyPicker("BlasterToggleKey", {
	Default = "B",
	Mode = "Toggle",
	Text = "Blaster Toggle Key",
	Callback = function(Value)
		if Toggles.AutoBlaster then
			Toggles.AutoBlaster:SetValue(not Toggles.AutoBlaster.Value)
		end
	end,
})

local UtilsGroup = Tabs.Main:AddRightGroupbox("Utilities")

UtilsGroup:AddToggle("AntiAFK", {
	Text = "Anti-AFK",
	Default = true,
	Callback = function(Value)
		if not Value then return end
	end,
})

UtilsGroup:AddButton({
	Text = "Teleport to Best Zone",
	Func = function()
		local highestOwned, _ = getHighestOwnedZone()
		if highestOwned then
			teleportToZone(highestOwned)
		end
	end,
	DoubleClick = false,
	Tooltip = "Teleport to the highest unlocked zone",
})

UtilsGroup:AddButton({
	Text = "Server Hop",
	Func = function()
		pcall(function()
			local result = HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
			local servers = result and result.data
			if servers then
				for _, server in ipairs(servers) do
					if server.playing < server.maxPlayers and server.id ~= game.JobId then
						TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, plr)
						break
					end
				end
			end
		end)
	end,
	DoubleClick = false,
	Tooltip = "Hop to a different server",
})

local RollingGroup = Tabs.Rolling:AddLeftGroupbox("Rolling")

RollingGroup:AddToggle("AutoRoll", {
	Text = "Auto Roll",
	Default = false,
})

RollingGroup:AddToggle("HideRollGUI", {
	Text = "Hide Roll GUI",
	Default = false,
})

RollingGroup:AddDivider()

RollingGroup:AddToggle("AutoRebirth", {
	Text = "Auto Rebirth",
	Default = false,
})

local BoostsGroup = Tabs.Rolling:AddRightGroupbox("Boosts & Index")

BoostsGroup:AddToggle("AutoUseBoosts", {
	Text = "Auto Use Boosts",
	Default = false,
})

BoostsGroup:AddDropdown("BoostType", {
	Values = {"luck", "ultraLuck", "currency", "rollSpeed"},
	Default = 1,
	Multi = true,
	Text = "Boost Selection",
	Callback = function(Value) end,
})

BoostsGroup:AddDivider()

BoostsGroup:AddToggle("AutoClaimIndex", {
	Text = "Auto Claim Index",
	Default = false,
})

local UpgradeGroup = Tabs.Upgrades:AddLeftGroupbox("Upgrades")

UpgradeGroup:AddToggle("AutoUpgrade", {
	Text = "Auto Upgrade",
	Default = false,
})

UpgradeGroup:AddSlider("AutoUpgradeInterval", {
	Text = "Upgrade Interval (sec)",
	Default = 30,
	Min = 5,
	Max = 120,
	Rounding = 0,
})

UpgradeGroup:AddDivider()

UpgradeGroup:AddLabel("Auto Upgrade reads the upgrade menu and unlocks available upgrades automatically.", true)

local ZoneGroup = Tabs.Upgrades:AddRightGroupbox("Zone & Teleport")

ZoneGroup:AddToggle("AutoBuyZone", {
	Text = "Auto Buy Zone",
	Default = false,
})

ZoneGroup:AddToggle("AutoTeleportBestZone", {
	Text = "Auto Teleport Best Zone",
	Default = false,
})

ZoneGroup:AddSlider("AutoTeleportInterval", {
	Text = "Teleport Interval (sec)",
	Default = 30,
	Min = 5,
	Max = 120,
	Rounding = 0,
})

local VisualsGroup = Tabs.Visuals:AddLeftGroupbox("Enemy ESP")

VisualsGroup:AddToggle("ESP", {
	Text = "ESP",
	Default = false,
	Callback = function(Value)
		State.espEnabled = Value
		if not Value then clearAllESP() end
	end,
}):AddColorPicker("ESPColor", {
	Default = Color3.fromRGB(255, 60, 60),
	Title = "ESP Color",
	Transparency = 0,
	Callback = function(Value) State.espColor = Value end,
})

VisualsGroup:AddDropdown("ESPMode", {
	Values = {"Box", "Health", "Tracer"},
	Default = 1,
	Multi = true,
	Text = "ESP Mode",
	Callback = function(Value)
		local cleaned = {}
		if type(Options.ESPMode.Value) == "table" then
			for mode, selected in pairs(Options.ESPMode.Value) do
				if selected then table.insert(cleaned, mode) end
			end
		end
		State.espMode = cleaned
	end,
})

local VisualsInfoGroup = Tabs.Visuals:AddRightGroupbox("Path Visualization")

VisualsInfoGroup:AddLabel("Path rays show your movement trajectory.")
VisualsInfoGroup:AddLabel("Green = Clear path")
VisualsInfoGroup:AddLabel("Yellow = Jumpable obstacle")
VisualsInfoGroup:AddLabel("Red = Blocked path")
VisualsInfoGroup:AddLabel("Blue = Forward scan")

local gameName = "Unknown"
pcall(function() gameName = MarketplaceService:GetProductInfo(game.PlaceId).Name end)
local serverId = tostring(game.JobId)
local playerDisplayName = plr.DisplayName or plr.Name
local playerArea = "Unknown"

local function getPlayerArea()
	local zones = Workspace:FindFirstChild("Zones")
	if not zones then return "Unknown" end
	local hrp = getHRP()
	if not hrp then return "Unknown" end
	local myPos = hrp.Position
	local bestNum = -1
	for _, z in ipairs(zones:GetChildren()) do
		local num = tonumber(z.Name)
		if num and num > bestNum then
			local poi = z:FindFirstChild("POI")
			if poi then
				local sp = poi:FindFirstChild("PlayerSpawn")
				if sp then
					local p = getPos(sp)
					if p and (myPos - p).Magnitude < 80 then bestNum = num end
				end
			end
		end
	end
	if bestNum == -1 then return "Unknown" end
	return "Zone " .. tostring(bestNum)
end

task.spawn(function()
	while true do
		pcall(function() playerArea = getPlayerArea() end)
		task.wait(2)
	end
end)

local MenuGroup = Tabs["UI Settings"]:AddLeftGroupbox("Menu")

MenuGroup:AddToggle("KeybindMenuOpen", {
	Default = Library.KeybindFrame.Visible,
	Text = "Open Keybind Menu",
	Callback = function(value)
		Library.KeybindFrame.Visible = value
	end,
})

MenuGroup:AddToggle("ShowCustomCursor", {
	Text = "Custom Cursor",
	Default = false,
	Callback = function(Value)
		Library.ShowCustomCursor = Value
	end,
})

MenuGroup:AddDropdown("NotificationSide", {
	Values = {"Left", "Right"},
	Default = "Right",
	Text = "Notification Side",
	Callback = function(Value)
		Library:SetNotifySide(Value)
	end,
})

MenuGroup:AddDropdown("DPIDropdown", {
	Values = {"50%", "75%", "100%", "125%", "150%", "175%", "200%"},
	Default = "100%",
	Text = "DPI Scale",
	Callback = function(Value)
		Value = Value:gsub("%%", "")
		local DPI = tonumber(Value)
		Library:SetDPIScale(DPI)
	end,
})

MenuGroup:AddSlider("UICornerSlider", {
	Text = "Corner Radius",
	Default = 20,
	Min = 0,
	Max = 20,
	Rounding = 0,
	Callback = function(value)
		Window:SetCornerRadius(value)
	end,
})

MenuGroup:AddDivider()

MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", {
	Default = "RightShift",
	NoUI = true,
	Text = "Menu keybind",
})

MenuGroup:AddButton({
	Text = "Unload",
	Func = function()
		Library:Unload()
	end,
	DoubleClick = false,
	Tooltip = "Unload the entire UI and stop all features",
})

Library.ToggleKeybind = Options.MenuKeybind

local InfoGroup = Tabs["UI Settings"]:AddLeftGroupbox("Information")

InfoGroup:AddLabel("Game: " .. gameName)
InfoGroup:AddLabel("Server ID: " .. serverId)
InfoGroup:AddLabel("User: " .. playerDisplayName)

local AreaLabel = InfoGroup:AddLabel("Best Area: " .. playerArea)

task.spawn(function()
	while true do
		pcall(function()
			AreaLabel:SetText("Best Area: " .. playerArea)
		end)
		task.wait(2)
	end
end)

local DraggableLabel = Library:AddDraggableLabel("Chill Hub | Slime RNG")

local FrameTimer = tick()
local FrameCounter = 0
local FPS = 60

Library:GiveSignal(RunService.RenderStepped:Connect(function()
	FrameCounter = FrameCounter + 1
	if (tick() - FrameTimer) >= 1 then
		FPS = FrameCounter
		FrameTimer = tick()
		FrameCounter = 0
	end
	pcall(function()
		DraggableLabel:SetText(("Chill Hub | %s fps | %s ms"):format(
			math.floor(FPS),
			math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue())
		))
	end)
end))

plr.Idled:Connect(function()
	if getFlag("AntiAFK") then
		pcall(function()
			VirtualUser:CaptureController()
			VirtualUser:ClickButton2(Vector2.new())
		end)
	end
end)

task.spawn(function()
	while true do
		local ok = pcall(function()
			task.wait(0.06)
			State.humanizer = getFlag("Humanizer")
			local hum = getHum()
			if not hum then
				hidePathRay()
				releaseAll()
				State.activeTask = "idle"
				return
			end

			if tick() - State.lastZoneScan > 3 then
				State.lastZoneScan = tick()
				local highestOwned, _ = getHighestOwnedZone()
				if highestOwned and highestOwned + 1 > State.currentZoneNum then
					local nextNum = highestOwned + 1
					local nextSpawn = getZoneSpawn(nextNum)
					if nextSpawn then
						State.currentZoneNum = nextNum
						State.zoneSpawnPos = nextSpawn
						State.isTravelingToZone = true
						State.hasArrived = false
						State.zoneCooldownEnd = 0
					end
				end
			end

			if State.isTravelingToZone and State.zoneSpawnPos then
				local dist = distToPos(State.zoneSpawnPos)
				if dist <= 6 and not State.hasArrived then
					State.hasArrived = true
					State.isTravelingToZone = false
					State.zoneCooldownEnd = tick() + 5
					hidePathRay()
				end
			end

			local onCooldown = tick() < State.zoneCooldownEnd

			local nearestLoot = nil
			local nearestEnemy = nil

			if getFlag("AutoCollect") and not onCooldown then nearestLoot = getNearestLoot() end
			if getFlag("Autofarm") and not onCooldown then nearestEnemy = getNearestEnemy() end

			local desiredTask = "idle"
			if State.isTravelingToZone and State.zoneSpawnPos then
				desiredTask = "zone"
			elseif getFlag("AutoCollect") and nearestLoot and not onCooldown then
				desiredTask = "loot"
			elseif getFlag("Autofarm") and nearestEnemy and not onCooldown then
				desiredTask = "combat"
			end

			if desiredTask ~= State.activeTask then
				releaseAll()
				hidePathRay()
				State.activeTask = desiredTask
				State.lastEnemyMove = 0
				State.lastLootTime = 0
				State.lastM1Time = 0
			end

			if State.activeTask == "zone" then
				local dist = distToPos(State.zoneSpawnPos)
				if dist > 6 then tweenToZone(State.zoneSpawnPos) end

			elseif State.activeTask == "loot" then
				if not nearestLoot or not nearestLoot.Parent then
					State.activeTask = "idle"
					setE(false)
					hidePathRay()
					return
				end
				local arrived = moveToLoot(nearestLoot)
				if arrived then
					if tick() - State.lastLootTime > 1 then
						State.lastLootTime = tick()
						setE(true)
						task.wait(0.08)
						setE(false)
					end
				end

			elseif State.activeTask == "combat" then
				if not nearestEnemy or not nearestEnemy.Parent then
					State.activeTask = "idle"
					setM1(false)
					hidePathRay()
					return
				end
				local ePos = getPos(nearestEnemy)
				local hrp = getHRP()
				if ePos and hrp then
					local dist = (hrp.Position - ePos).Magnitude
					if dist > (State.humanizer and 4 or 2.5) then
						if State.humanizer then
							humanMoveToEnemy(nearestEnemy)
						else
							tweenToEnemy(ePos)
						end
						local ignore = getIgnoreList(nearestEnemy)
						local st, hit = checkObstacle(hrp.Position, ePos, ignore)
						if st == "jumpable" then
							tryJump()
							updateRayPart(PathRay, hrp.Position, hit or ePos, Color3.fromRGB(255, 255, 0))
						elseif st == "blocked" then
							updateRayPart(PathRay, hrp.Position, hit or ePos, Color3.fromRGB(255, 50, 50))
						else
							updateRayPart(PathRay, hrp.Position, ePos, Color3.fromRGB(0, 255, 100))
						end
					else
						hidePathRay()
						if State.humanizer then humanMoveToEnemy(nearestEnemy) end
						fireSlimeGun(nearestEnemy)
						if getFlag("AutoBlaster") then
							setM1(true)
						else
							setM1(false)
						end
					end
				else
					State.activeTask = "idle"
					setM1(false)
					hidePathRay()
				end

			else
				setM1(false)
				setE(false)
				hidePathRay()
			end
		end)
		if not ok then
			releaseAll()
			hidePathRay()
			State.activeTask = "idle"
		end
	end
end)

task.spawn(function()
	while true do
		local ok = pcall(function()
			task.wait(0.1)
			local hrp = getHRP()
			if hrp then
				local myPos = hrp.Position
				local look = hrp.CFrame.LookVector
				local ignore = getIgnoreList(nil)
				local st, hit = checkObstacle(myPos, myPos + look * 14, ignore)
				if st == "jumpable" then
					tryJump()
					updateRayPart(ForwardRay, myPos, hit or (myPos + look * 14), Color3.fromRGB(255, 220, 0))
				elseif st == "blocked" then
					updateRayPart(ForwardRay, myPos, hit or (myPos + look * 14), Color3.fromRGB(255, 80, 80))
				else
					updateRayPart(ForwardRay, myPos, myPos + look * 14, Color3.fromRGB(120, 200, 255))
				end
			else
				ForwardRay.Size = Vector3.new(0.01, 0.01, 0.01)
			end
		end)
		if not ok then task.wait(0.2) end
	end
end)

task.spawn(function()
	while true do
		local ok = pcall(function()
			if getFlag("AutoNextArea") then purchaseNextZone() end
		end)
		if not ok then task.wait(0.2) end
		task.wait(1.5)
	end
end)

task.spawn(function()
	while true do
		local ok = pcall(function()
			if getFlag("EquipBest") then equipBest() end
		end)
		if not ok then task.wait(0.5) end
		task.wait(3)
	end
end)

task.spawn(function()
	while true do
		local ok = pcall(function()
			if not getFlag("AutoFeed") then return end
			local selectedFoods = State.feedFood or {}
			if #selectedFoods == 0 then return end

			local selectedNames = {}
			for _, display in ipairs(State.feedSlimes or {}) do
				local name = display:match("^(.-) %(")
				if name then selectedNames[name] = true end
			end
			if next(selectedNames) == nil then return end

			local slimes = CachedSlimes
			if #slimes == 0 then return end

			local matchingSlimes = {}
			for _, slimeData in ipairs(slimes) do
				if selectedNames[slimeData.name] then
					table.insert(matchingSlimes, slimeData)
				end
			end
			if #matchingSlimes == 0 then return end

			local slimeData = matchingSlimes[math.random(1, #matchingSlimes)]
			local food = selectedFoods[math.random(1, #selectedFoods)]

			local args = {"requestUseFood", food:lower(), slimeData.slimeId, 1}
			InventoryRemote:InvokeServer(unpack(args))
		end)
		if not ok then task.wait(1) end
		task.wait(1)
	end
end)

task.spawn(function()
	while true do
		pcall(function()
			if getFlag("AutoRoll") then
				doRoll()
			end
		end)
		task.wait(0.5)
	end
end)

task.spawn(function()
	while true do
		pcall(function()
			if getFlag("HideRollGUI") then
				local playerGui = plr:FindFirstChild("PlayerGui")
				if playerGui then
					local root = playerGui:FindFirstChild("Root")
					if root then
						local rollGui = root:FindFirstChild("RollGui")
						if rollGui then
							rollGui.Enabled = false
						end
					end
				end
			else
				local playerGui = plr:FindFirstChild("PlayerGui")
				if playerGui then
					local root = playerGui:FindFirstChild("Root")
					if root then
						local rollGui = root:FindFirstChild("RollGui")
						if rollGui then
							rollGui.Enabled = true
						end
					end
				end
			end
		end)
		task.wait(1)
	end
end)

task.spawn(function()
	while true do
		pcall(function()
			if getFlag("AutoRebirth") then
				doRebirth()
			end
		end)
		task.wait(5)
	end
end)

task.spawn(function()
	while true do
		pcall(function()
			if getFlag("AutoUseBoosts") then
				local boostTypes = {}
				if type(Options.BoostType.Value) == "table" then
					for boost, selected in pairs(Options.BoostType.Value) do
						if selected then table.insert(boostTypes, boost) end
					end
				end
				if #boostTypes > 0 then
					for _, bt in ipairs(boostTypes) do
						useBoost(bt)
					end
				else
					useBoost("luck")
					useBoost("ultraLuck")
					useBoost("currency")
					useBoost("rollSpeed")
				end
			end
		end)
		task.wait(3)
	end
end)

task.spawn(function()
	while true do
		pcall(function()
			if getFlag("AutoClaimIndex") then
				claimIndexReward("basic")
				task.wait(0.1)
				claimIndexReward("big")
				task.wait(0.1)
				claimIndexReward("huge")
				task.wait(0.1)
				claimIndexReward("shiny")
				task.wait(0.1)
				claimIndexReward("inverted")
			end
		end)
		task.wait(30)
	end
end)

task.spawn(function()
	while true do
		pcall(function()
			if getFlag("AutoUpgrade") then
				local tiles = getUpgradeTiles()
				if tiles then
					for _, tile in ipairs(tiles) do
						if tile.Name == "UIAspectRatioConstraint" or tile.Name == "UpgradeHoverInfo" then continue end
						local imageLabel = tile:FindFirstChild("ImageLabel")
						if imageLabel then
							local textLabelFrame = imageLabel:FindFirstChild("TextLabelFrame")
							if textLabelFrame then
								local prefix = textLabelFrame:FindFirstChild("Prefix")
								if prefix then
									if textLabelFrame.TextLabel.TextColor3:ToHex() ~= "ff2d49" and imageLabel.Image == "rbxassetid://127271823919078" then
										local upgrade = tile.Name:match("^(%S+)Tile")
										if upgrade then
											doUpgrade(upgrade)
										end
									end
								end
							end
						end
					end
				end
			end
		end)
		task.wait(Options.AutoUpgradeInterval and Options.AutoUpgradeInterval.Value or 30)
	end
end)

task.spawn(function()
	while true do
		pcall(function()
			if getFlag("AutoBuyZone") then
				purchaseNextZone()
			end
		end)
		task.wait(5)
	end
end)

task.spawn(function()
	while true do
		pcall(function()
			if getFlag("AutoTeleportBestZone") then
				local highestOwned, _ = getHighestOwnedZone()
				if highestOwned then
					teleportToZone(highestOwned)
				end
			end
		end)
		task.wait(Options.AutoTeleportInterval and Options.AutoTeleportInterval.Value or 30)
	end
end)

task.spawn(function()
	while true do
		pcall(function()
			if getFlag("AutoCollectDrops") then
				collectDropsProximity()
			end
		end)
		task.wait(0.3)
	end
end)

local lastSlimeCount = #initialSlimeOptions
task.spawn(function()
	while true do
		local ok = pcall(function()
			local slimes = scanSlimes()
			local slimeOptions = {}
			for _, data in ipairs(slimes) do
				table.insert(slimeOptions, data.display)
			end
			if #slimeOptions ~= lastSlimeCount then
				lastSlimeCount = #slimeOptions
				if Options.FeedSlimes and Options.FeedSlimes.Refresh then
					Options.FeedSlimes:Refresh(slimeOptions, true)
				end
			end
		end)
		if not ok then task.wait(1) end
		task.wait(8)
	end
end)

Library:GiveSignal(RunService.RenderStepped:Connect(function() pcall(updateESP) end))

plr.CharacterAdded:Connect(function()
	State.lastJump = 0
	State.isTravelingToZone = false
	State.hasArrived = false
	State.zoneCooldownEnd = 0
	State.activeTask = "idle"
	State.lastEnemyMove = 0
	State.lastLootTime = 0
	State.lastM1Time = 0
	releaseAll()
	hidePathRay()
end)

Library:OnUnload(function()
	clearAllESP()
	releaseAll()
	hidePathRay()
	if RayFolder then RayFolder:Destroy() end
end)

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({"MenuKeybind"})

ThemeManager:SetFolder("ChillHub")
SaveManager:SetFolder("ChillHub/SlimeRNG")

SaveManager:BuildConfigSection(Tabs["UI Settings"])

ThemeManager:ApplyToTab(Tabs["UI Settings"])

ThemeManager:ApplyTheme("Jester")

SaveManager:LoadAutoloadConfig()

Library:Notify({
	Title = "Chill Hub",
	Description = "Loaded successfully!",
	Time = 4,
	Icon = "check",
})
