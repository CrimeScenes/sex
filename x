
getgenv().Target = {
    Keybind = "C",  
    UntargetKeybind = "B"  
}

getgenv().Silent = {
    Startup = {
        Enabled = true,  -- Enables or disables the silent aim feature.
        Prediction = 0.1261,  -- Amount of prediction for aiming based on target movement.
        Type = "boxfov",  -- Can be 'boxfov' or 'circle'.
        Keybind = "P",  -- Keybind to activate or deactivate the silent aim feature.
        Resolver = true,  -- Activates the resolver for better targeting against unpredictable movements.
        WallCheck = true,  -- Checks if a wall is between the player and the target.
    },
    AimSettings = {  -- Renamed from Normal to AimSettings
        FovSettings = {
            FovVisible = false,  -- Indicates if the FOV should be visible.
            FovRadius = 10,  -- Radius of the FOV circle.
            FovThickness = 2,  -- Thickness of the FOV circle outline.
            FovTransparency = 0.7,  -- Transparency of the FOV circle.
            FovColor = Color3.fromRGB(255, 255, 255),  -- Color of the FOV circle.
            Filled = false,  -- Indicates if the FOV shape should be filled.
            FillTransparency = 0.9,  -- Transparency for the filled area of the FOV circle.
        }
    }
}

-- Define the HitChances table
getgenv().HitChances = {
    Active = true,
    WeaponStats = {
        Rev = 100, 
        DB = 100, 
        Shot = 100,
        TacShot = 100, 
        SMG = 100, 
        Sil = 100,
        AR = 100, 
        Other = 100
    }   
}

-- Define the CamLock table
getgenv().CamLock = {
    Normal = {
        Enabled = true,
        Description = "Enables camera locking to maintain focus on a target.",
        Prediction = 0.134,  -- Amount of prediction applied for aiming based on target movement.
        Radius = 150,  -- Radius within which the target can be locked.
        HitPart = "UpperTorso",  -- The part of the target the camera locks onto.
        AutoPred = false,  -- Automatically adjusts prediction based on the target's movement speed.
        ClosestPart = true,  -- Locks onto the closest visible part of the target.
        SmoothnessEnabled = true,  -- Enables smooth transitions when locking onto the target.
        Smoothness = 0.01,  -- The degree of smoothness applied to the lock transition.
        mode = "toggle",  -- (hold - toggle) Defines whether the camera lock is toggled or held.
    },
    Shake = {
        Enabled = false,
        DirectionX = 3,  
        DirectionY = 6,
    },
    AutoUnLock = {
        Reloading = false,
        Typing = false,  
    }
}

getgenv().TriggerBot = {  -- Corrected here
    Keybinds = { Shoot = Enum.KeyCode.J },
    Settings = {
        Mode = "hold",  -- 'hold' or 'toggle'
        Notifications = true,
        Parts = { "Head", "UpperTorso", "LowerTorso" },
        BoxFOVSize = { Height = 1.1, Width = 0.9 },
        Preds = {
            PredictionMultiplier = 2.0,  -- velocity prediction
            Safety = { IgnoreKnife = true },
        },
        Cooldown = 0.01,
    } 
} 

-- Define the Adjustment table
getgenv().Adjustment = {
    Checks = {
        Resolver = true,  -- Engages the resolver for improved targeting against erratic movements.
        Anti_Aim_Viewer = true,  -- Displays a monitoring interface for anti-aim strategies.
        Wall_Check = true,  -- Prevents shots from penetrating walls.
        Disable_Ground_Shots = true,  -- Disallows shooting at enemies while grounded.
        Crew_Check = false,  -- Enables identification systems for distinguishing allies from foes.
        Knocked_Check = true,  -- Allows targeting of downed opponents.
        AntiCurve = true,  -- Engages mechanisms to counteract curve effects on erratic targets.
        NoGroundShots = true,  -- Prohibits shooting at grounded targets.
    }
}



  

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = game:GetService("Workspace").CurrentCamera
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local lastClickTime = 0
local isToggled = false

local AllBodyParts = {
    "Head", "UpperTorso", "LowerTorso", "HumanoidRootPart", "LeftHand", "RightHand", 
    "LeftLowerArm", "RightLowerArm", "LeftUpperArm", "RightUpperArm", "LeftFoot", 
    "LeftLowerLeg", "LeftUpperLeg", "RightLowerLeg", "RightUpperLeg", "RightFoot"
}

function Forlorn.mouse1click(x, y)
    VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, false)
    VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, false)
end

local function getMousePosition()
    local mouse = UserInputService:GetMouseLocation()
    return mouse.X, mouse.Y
end

local function isWithinBoxFOV(position)
    local screenPos = Camera:WorldToViewportPoint(position)
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local fovHeight = getgenv().triggerbot.Settings.BoxFOVSize.Height * 100
    local fovWidth = getgenv().triggerbot.Settings.BoxFOVSize.Width * 100

    return (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude <= math.sqrt((fovHeight / 2)^2 + (fovWidth / 2)^2)
end

local function getPredictedPosition(character)
    local primaryPart = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Head")
    if primaryPart then
        local velocity = primaryPart.Velocity
        local predictionMultiplier = getgenv().triggerbot.Settings.Preds.PredictionMultiplier
        local timeToPredict = getgenv().triggerbot.Settings.Preds.TimeToPredict or 0.1

        -- Improved prediction calculation
        local predictedPosition = primaryPart.Position + (velocity * timeToPredict * predictionMultiplier)

        -- Adjustment for airborne/moving targets
        if character.Humanoid:GetState() == Enum.HumanoidStateType.Freefall then
            predictedPosition = predictedPosition + Vector3.new(0, -1, 0) -- Predict for downward movement in the air
        end
        
        return predictedPosition
    end
    return nil
end

local function findClosestPart(character)
    local closestPart, closestDistance = nil, math.huge
    for _, partName in ipairs(AllBodyParts) do
        local part = character:FindFirstChild(partName)
        if part then
            local distance = (part.Position - LocalPlayer.Character.PrimaryPart.Position).Magnitude
            if distance < closestDistance then
                closestDistance, closestPart = distance, part
            end
        end
    end
    return closestPart
end

local function adjustAimForTarget(targetPosition)
    local screenPosition, onScreen = Camera:WorldToViewportPoint(targetPosition)
    if onScreen then
        local centerX = Camera.ViewportSize.X / 2
        local centerY = Camera.ViewportSize.Y / 2

        local offsetX = screenPosition.X - centerX
        local offsetY = screenPosition.Y - centerY

        -- Adjust sensitivity for smoother aiming
        VirtualInputManager:SendMouseMoveEvent(centerX + offsetX / 2, centerY + offsetY / 2, game) -- Adjust the divisor for sensitivity
    end
end

local function isIgnoringKnife()
    local currentTool = LocalPlayer.Character:FindFirstChildOfClass("Tool")
    if currentTool then
        local toolName = currentTool.Name:lower() -- Convert tool name to lowercase for case-insensitive check
        return toolName == "knife" or toolName == "katana" or toolName == "[knife]" or toolName == "[katana]"
    end
    return false
end

local function TriggerBotAction()
    -- Check if CamLock is active and the target is valid
    if not IsTargeting or not TargetPlayer or not TargetPlayer.Character then
        return -- Exit if CamLock is not engaged
    end

    -- Check for knife/katana
    if getgenv().triggerbot.Settings.Preds.Safety.IgnoreKnife and isIgnoringKnife() then
        return -- Exit if IgnoreKnife is enabled and a knife/katana is equipped
    end

    local closestPart = findClosestPart(TargetPlayer.Character)
    if closestPart then
        local predictedPosition = getPredictedPosition(TargetPlayer.Character)
        if predictedPosition and isWithinBoxFOV(predictedPosition) then
            adjustAimForTarget(closestPart.Position)

            local tool = LocalPlayer.Character:FindFirstChildOfClass("Tool")
            if tool and tool:IsA("Tool") then
                local shootFunction = tool:FindFirstChild("Fire")
                if shootFunction and shootFunction:IsA("RemoteEvent") then
                    shootFunction:FireServer(TargetPlayer.Character)
                else
                    local mouseX, mouseY = getMousePosition()
                    Forlorn.mouse1click(mouseX, mouseY)
                end
            end
        end
    end
end

local function handleShootingMode()
    if getgenv().triggerbot.Settings.Mode == "toggle" then
        isToggled = not isToggled
    else
        RunService:BindToRenderStep("TriggerBotHold", Enum.RenderPriority.Input.Value, TriggerBotAction)
    end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == getgenv().triggerbot.Keybinds.Shoot then
        handleShootingMode()
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if input.KeyCode == getgenv().triggerbot.Keybinds.Shoot then
        if getgenv().triggerbot.Settings.Mode == "hold" then
            RunService:UnbindFromRenderStep("TriggerBotHold")
        end
    end
end)

RunService.RenderStepped:Connect(function()
    if getgenv().triggerbot.Settings.Mode == "hold" and UserInputService:IsKeyDown(getgenv().triggerbot.Keybinds.Shoot) then
        TriggerBotAction()
    end
end)





  
  local Players = game:GetService("Players")
  local LocalPlayer = Players.LocalPlayer
  local Mouse = LocalPlayer:GetMouse()
  local RunService = game:GetService("RunService")
  local Camera = game.Workspace.CurrentCamera
  
  local Circle = Drawing.new("Circle")
  Circle.Color = Color3.new(1, 1, 1)
  Circle.Thickness = 1
  Circle.Filled = false
  
  
  
  local function UpdateFOV()
      if not Circle then return end
  
      Circle.Visible = CamLock.Normal.Radius_Visibility
      Circle.Radius = CamLock.Normal.Radius
      Circle.Position = Vector2.new(Mouse.X, Mouse.Y + game:GetService("GuiService"):GetGuiInset().Y)
  end
  
  RunService.RenderStepped:Connect(UpdateFOV)
  
  local function ClosestPlrFromMouse()
      local Target, Closest = nil, math.huge
  
      for _, player in pairs(Players:GetPlayers()) do
          if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
              local Position, OnScreen = Camera:WorldToScreenPoint(player.Character.HumanoidRootPart.Position)
              local Distance = (Vector2.new(Position.X, Position.Y) - Vector2.new(Mouse.X, Mouse.Y)).Magnitude
  
              if Circle.Radius > Distance and Distance < Closest and OnScreen then
                  Closest = Distance
                  Target = player
              end
          end
      end
      return Target
  end
  
  -- Function to get closest body part of a character
  local function GetClosestBodyPart(character)
      local ClosestDistance = math.huge
      local BodyPart = nil
  
      if character and character:IsDescendantOf(game.Workspace) then
          for _, part in ipairs(character:GetChildren()) do
              if part:IsA("BasePart") then
                  local Position, OnScreen = Camera:WorldToScreenPoint(part.Position)
                  if OnScreen then
                      local Distance = (Vector2.new(Position.X, Position.Y) - Vector2.new(Mouse.X, Mouse.Y)).Magnitude
                      if Circle.Radius > Distance and Distance < ClosestDistance then
                          ClosestDistance = Distance
                          BodyPart = part
                      end
                  end
              end
          end
      end
      return BodyPart
  end
  
  Mouse.KeyDown:Connect(function(Key)
    if Key:lower() == getgenv().Target.Keybind:lower() then
        if CamLock.Normal.Enabled then
            -- If currently targeting, switch to the nearest player only if already targeting
            if IsTargeting then
                TargetPlayer = ClosestPlrFromMouse()  -- Change target to the closest player
            else
                -- If not targeting, enable targeting and set the initial target
                IsTargeting = true
                TargetPlayer = ClosestPlrFromMouse()  -- Set the initial target
            end
        end
    elseif Key:lower() == getgenv().Target.UntargetKeybind:lower() then
        -- Untarget logic
        IsTargeting = false
        TargetPlayer = nil  -- Clear the target
    end
end)




  
  
  -- CamLock update camera position based on the targeted player
  -- CamLock update camera position based on the targeted player
  RunService.RenderStepped:Connect(function()
    if IsTargeting and TargetPlayer and TargetPlayer.Character then
        if TargetPlayer.Character.Humanoid.Health <= 0 then
            TargetPlayer = nil
            IsTargeting = false  -- Stop targeting
            return
        end

        local BodyPart
        if CamLock.Normal.ClosestPart then
            BodyPart = GetClosestBodyPart(TargetPlayer.Character)
        else
            BodyPart = TargetPlayer.Character:FindFirstChild(CamLock.Normal.HitPart)
        end

        if BodyPart then
            local predictedPosition
            if CamLock.Normal.Resolver then
                local humanoid = TargetPlayer.Character:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    local moveDirection = humanoid.MoveDirection
                    predictedPosition = BodyPart.Position + (moveDirection * CamLock.Normal.Prediction)
                end
            else
                local targetVelocity = TargetPlayer.Character.HumanoidRootPart.Velocity
                predictedPosition = BodyPart.Position + (targetVelocity * CamLock.Normal.Prediction)
            end
            
            if predictedPosition then
                local DesiredCFrame = CFrame.new(Camera.CFrame.Position, predictedPosition)

                if CamLock.Normal.SmoothnessEnabled then
                    Camera.CFrame = Camera.CFrame:Lerp(DesiredCFrame, CamLock.Normal.Smoothness)
                else
                    Camera.CFrame = DesiredCFrame
                end
            end
        end
    end
end)

  
  
  
  local G                   = game
  local Run_Service         = G:GetService("RunService")
  local Players             = G:GetService("Players")
  local UserInputService    = G:GetService("UserInputService")
  local Local_Player        = Players.LocalPlayer
  local Mouse               = Local_Player:GetMouse()
  local Current_Camera      = G:GetService("Workspace").CurrentCamera
  local Replicated_Storage  = G:GetService("ReplicatedStorage")
  local StarterGui          = G:GetService("StarterGui")
  local Workspace           = G:GetService("Workspace")
  
  -- // Variables // --
  local Target = nil
  local V2 = Vector2.new
  local Fov = Drawing.new("Circle")
  local holdingMouseButton = false
  local lastToolUse = 0
  local FovParts = {}
  
  -- // Game Load Check // --
  if not game:IsLoaded() then
      game.Loaded:Wait()
  end
  
  -- // Game Settings // --
  local Games = {
      [2788229376] = {Name = "Da Hood", Argument = "UpdateMousePosI2", Remote = "MainEvent", BodyEffects = "K.O",},
      [16033173781] = {Name = "Da Hood Macro", Argument = "UpdateMousePosI2", Remote = "MainEvent", BodyEffects = "K.O",},
      [7213786345] = {Name = "Da Hood VC", Argument = "UpdateMousePosI", Remote = "MainEvent", BodyEffects = "K.O",},
      [9825515356] = {Name = "Hood Customs", Argument = "GetPing", Remote = "MainEvent"},
      [5602055394] = {Name = "Hood Modded", Argument = "MousePos", Remote = "Bullets"},
      [17403265390] = {Name = "Da Downhill [PS/Xbox]", Argument = "MOUSE", Remote = "MAINEVENT"},
      [132023669786646] = {Name = "Da Bank", Argument = "MOUSE", Remote = "MAINEVENT"},
      [84366677940861] = {Name = "Da Uphill", Argument = "MOUSE", Remote = "MAINEVENT"},
      [14487637618] = {Name = "Da Hood Bot Aim Trainer", Argument = "MOUSE", Remote = "MAINEVENT"},
      [11143225577] = {Name = "1v1 Hood Aim Trainer", Argument = "UpdateMousePos", Remote = "MainEvent"},
      [14413712255] = {Name = "Hood Aim", Argument = "MOUSE", Remote = "MAINEVENT"},
      [14472848239] = {Name = "Moon Hood", Argument = "MoonUpdateMousePos", Remote = "MainEvent"},
      [15186202290] = {Name = "Da Strike", Argument = "MOUSE", Remote = "MAINEVENT"},
      [17319408836] = {Name = "OG Da Hood", Argument = "UpdateMousePos", Remote = "MainEvent", BodyEffects = "K.O",},
      [17780567699] = {Name = "Meko Hood", Argument = "UpdateMousePos", Remote = "MainEvent", BodyEffects = "K.O",},
      [127504606438871] = {Name = "Da Craft", Argument = "UpdateMousePos", Remote = "MainEvent", BodyEffects = "K.O",},
      [139379854239480] = {Name = "Dee Hood", Argument = "UpdateMousePos", Remote = "MainEvent", BodyEffects = "K.O",},
      [85317083713029] = {Name = "Da kitty", Argument = "UpdateMousePos", Remote = "MainEvent", BodyEffects = "K.O",},
  }
  
  local gameId = game.PlaceId
  local gameSettings = Games[gameId]
  
  if not gameSettings then
      Players.LocalPlayer:Kick("Unsupported game")
      return
  end
  
  local RemoteEvent = gameSettings.Remote
  local Argument = gameSettings.Argument
  local BodyEffects = gameSettings.BodyEffects or "K.O"
  
  -- // Update Detection // --
  local ReplicatedStorage   = game:GetService("ReplicatedStorage")
  local MainEvent           = ReplicatedStorage:FindFirstChild(RemoteEvent)
  
  if not MainEvent then
      Players.LocalPlayer:Kick("Are you sure this is the correct game?")
      return
  end
  
  local function isArgumentValid(argumentName)
      return argumentName == Argument
  end
  
  local argumentToCheck = Argument
  
  if isArgumentValid(argumentToCheck) then
      MainEvent:FireServer(argumentToCheck) 
  else
      Players.LocalPlayer:Kick("stupid monkey")
  end
  
  -- // Clear FOV Parts // --
  local function clearFovParts()
      for _, part in pairs(FovParts) do
          part:Remove()
      end
      FovParts = {}
  end
  
  -- // Update FOV Function // --
  local function updateFov()
    local settings = getgenv().Silent.AimSettings.FovSettings  -- Updated to access the new FovSettings location
    clearFovParts()
  
      -- Only show FOV if targeting is enabled
      if IsTargeting then
          if settings.FovShape == "Square" then
              local halfSize = settings.FovRadius / 2
              local corners = {
                  V2(Mouse.X - halfSize, Mouse.Y - halfSize),
                  V2(Mouse.X + halfSize, Mouse.Y - halfSize),
                  V2(Mouse.X + halfSize, Mouse.Y + halfSize),
                  V2(Mouse.X - halfSize, Mouse.Y + halfSize)
              }
              for i = 1, 4 do
                  local line = Drawing.new("Line")
                  line.Visible = settings.FovVisible
                  line.From = corners[i]
                  line.To = corners[i % 4 + 1]
                  line.Color = settings.FovColor
                  line.Thickness = settings.FovThickness
                  line.Transparency = settings.FovTransparency
                  table.insert(FovParts, line)
              end
          elseif settings.FovShape == "Triangle" then
              local points = {
                  V2(Mouse.X, Mouse.Y - settings.FovRadius),
                  V2(Mouse.X + settings.FovRadius * math.sin(math.rad(60)), Mouse.Y + settings.FovRadius * math.cos(math.rad(60))),
                  V2(Mouse.X - settings.FovRadius * math.sin(math.rad(60)), Mouse.Y + settings.FovRadius * math.cos(math.rad(60)))
              }
              for i = 1, 3 do
                  local line = Drawing.new("Line")
                  line.Visible = settings.FovVisible
                  line.From = points[i]
                  line.To = points[i % 3 + 1]
                  line.Color = settings.FovColor
                  line.Thickness = settings.FovThickness
                  line.Transparency = settings.FovTransparency
                  table.insert(FovParts, line)
              end
          else  -- Default to Circle
              Fov.Visible = settings.FovVisible
              Fov.Radius = settings.FovRadius
              Fov.Position = V2(Mouse.X, Mouse.Y + (G:GetService("GuiService"):GetGuiInset().Y))
              Fov.Color = settings.FovColor
              Fov.Thickness = settings.FovThickness
              Fov.Transparency = settings.FovTransparency
              Fov.Filled = settings.Filled
              if settings.Filled then
                  Fov.Transparency = settings.FillTransparency
              end
          end
      else
          Fov.Visible = false  -- Hide FOV when not targeting
      end
  end
  
  -- // Notification Function // --
  local function sendNotification(title, text, icon)
      StarterGui:SetCore("SendNotification", {
          Title = title,
          Text = text,
          Icon = icon,
          Duration = 5
      })
  end
  
  -- // Knock Check // --
  local function Death(Plr)
      if Plr.Character and Plr.Character:FindFirstChild("BodyEffects") then
          local bodyEffects = Plr.Character.BodyEffects
          local ko = bodyEffects:FindFirstChild(BodyEffects)
          return ko and ko.Value
      end
      return false
  end
  
  -- // Grab Check // --
  local function Grabbed(Plr)
      return Plr.Character and Plr.Character:FindFirstChild("GRABBING_CONSTRAINT") ~= nil
  end
  
 -- // Check if Part in Fov and Visible // --
local function isPartInFovAndVisible(part)
    -- Ensure CamLock is active and there is a target
    if not getgenv().CamLock.Normal.Enabled or not IsTargeting or not TargetPlayer then
        return false
    end

    local screenPoint, onScreen = Current_Camera:WorldToScreenPoint(part.Position)
    local distance = (V2(screenPoint.X, screenPoint.Y) - V2(Mouse.X, Mouse.Y)).Magnitude
    return onScreen and distance <= getgenv().Silent.AimSettings.FovSettings.FovRadius  -- Updated to access new FOV settings location
end


  
  
  -- // Check if Part Visible // --
local function isPartVisible(part)
    if not getgenv().Silent.Startup.WallCheck then  -- Updated to access the new location of WallCheck
        return true
    end
    local origin = Current_Camera.CFrame.Position
    local direction = (part.Position - origin).Unit * (part.Position - origin).Magnitude
    local ray = Ray.new(origin, direction)
    local hit = Workspace:FindPartOnRayWithIgnoreList(ray, {Local_Player.Character, part.Parent})
    return hit == part or not hit
end

  
  -- // Get Closest Hit Point on Part // --
  local function GetClosestHitPoint(character)
      local closestPart = nil
      local closestPoint = nil
      local shortestDistance = math.huge
  
      for _, part in pairs(character:GetChildren()) do
          if part:IsA("BasePart") and isPartInFovAndVisible(part) and isPartVisible(part) then
              local screenPoint, onScreen = Current_Camera:WorldToScreenPoint(part.Position)
              local distance = (V2(screenPoint.X, screenPoint.Y) - V2(Mouse.X, Mouse.Y)).Magnitude
  
              if distance < shortestDistance then
                  closestPart = part
                  closestPoint = part.Position
                  shortestDistance = distance
              end
          end
      end
  
      return closestPart, closestPoint
  end
  
  -- // Get Velocity Function // --
local OldPredictionY = getgenv().Silent.Startup.Prediction  -- Updated to access the new location of Prediction
local function GetVelocity(player, part)
    if player and player.Character then
        local velocity = player.Character[part].Velocity
        if velocity.Y < -30 and getgenv().Silent.Startup.Resolver then  -- Updated to access the new location of Resolver
            getgenv().Silent.Startup.Prediction = 0
            return velocity
        elseif velocity.Magnitude > 50 and getgenv().Silent.Startup.Resolver then  -- Updated to access the new location of Resolver
            return player.Character:FindFirstChild("Humanoid").MoveDirection * 16
        else
            getgenv().Silent.Startup.Prediction = OldPredictionY
            return velocity
        end
    end
    return Vector3.new(0, 0, 0)
end

  
  -- // Get Closest Player // --
  local function GetClosestPlr()
      local closestTarget = nil
      local maxDistance = math.huge
  
      for _, player in pairs(Players:GetPlayers()) do
          if player.Character and player ~= Local_Player and not Death(player) then  -- KO check using Death function
              local closestPart, closestPoint = GetClosestHitPoint(player.Character)
              if closestPart and closestPoint then
                  local screenPoint = Current_Camera:WorldToScreenPoint(closestPoint)
                  local distance = (V2(screenPoint.X, screenPoint.Y) - V2(Mouse.X, Mouse.Y)).Magnitude
                  if distance < maxDistance then
                      maxDistance = distance
                      closestTarget = player
                  end
              end
          end
      end
  
      -- Automatically deselect target if they are dead or knocked
      if closestTarget and Death(closestTarget) then
          return nil
      end
  
      return closestTarget
  end
  
  
 -- // Toggle Feature // --
local function toggleFeature()
    getgenv().Silent.Startup.Enabled = not getgenv().Silent.Startup.Enabled
    local status = getgenv().Silent.Startup.Enabled and "Silent Aim Enabled" or "Silent Aim Disabled"
    sendNotification("Silent Aim Notifications", status, "rbxassetid://17561420493")
    if not getgenv().Silent.Startup.Enabled then
        Fov.Visible = false
        clearFovParts()
    end
end

  
  -- // Convert Keybind to KeyCode // --
  local function getKeyCodeFromString(key)
      return Enum.KeyCode[key]
  end
  
  -- // Keybind Listener // --
  UserInputService.InputBegan:Connect(function(input, isProcessed)
      if not isProcessed and input.UserInputType == Enum.UserInputType.MouseButton1 then
          holdingMouseButton = true
          local closestPlayer = GetClosestPlayer()
  
          if closestPlayer then
              Target = closestPlayer
              local mousePosition = Vector3.new(Mouse.X, Mouse.Y, 0)
  
              local remoteEvent = Replicated_Storage:FindFirstChild(RemoteEvent) -- Find the RemoteEvent
              if remoteEvent then
                  -- Ensure Argument is defined before using it
                  if Argument then
                      local success, err = pcall(function()
                          remoteEvent:FireServer(Argument, mousePosition)
                      end)
                      if not success then
                          print("Error firing RemoteEvent: ", err) -- Log error without showing in console
                      end
                  else
                      print("Argument is nil!") -- Log warning without showing in console
                  end
              else
                  print("RemoteEvent not found!") -- Log warning without showing in console
              end
          end
      end
  end)
  
  
  
  
  UserInputService.InputEnded:Connect(function(input, isProcessed)
    if input.KeyCode == Enum.KeyCode[getgenv().Target.Keybind:upper()] and CamLock.Normal.mode == "hold" then
        -- Keep IsTargeting true
        -- Do not stop targeting
    end

    if input.KeyCode == Enum.KeyCode[getgenv().Target.UntargetKeybind:upper()] then
        IsTargeting = false  -- Stop targeting
        TargetPlayer = nil  -- Clear the target
    end
end)

  
  
  -- Main Loop
  Run_Service.RenderStepped:Connect(function()
    if getgenv().Silent.Startup.Enabled and IsTargeting then  -- Only work when Silent Aim is engaged
        updateFov()  -- Call updateFov to refresh visibility
        Target = GetClosestPlr()  -- Get the closest player instead of using a static Target variable
        
        if Target and Target.Character then
            if Death(Target) then
                -- If the target is dead, un-target
                Target = nil
                IsTargeting = false  -- Stop targeting without notification
                return
            end

            -- Check if the target is knocked out
            if Target.Character.Humanoid.Health <= 0 then
                -- If the target is knocked out, unlock the camera
                Target = nil
                IsTargeting = false  -- Stop targeting
                Fov.Visible = false  -- Ensure FOV is hidden
                return
            end
            
            local closestPart, closestPoint = GetClosestHitPoint(Target.Character)
            if closestPart and closestPoint then
                local velocity = GetVelocity(Target, closestPart.Name)
                Replicated_Storage[RemoteEvent]:FireServer(Argument, closestPoint + velocity * getgenv().Silent.Startup.Prediction)
            end
        end
    else
        Fov.Visible = false  -- Ensure FOV is hidden if not targeting
    end
end)


  
  
  
  
  -- // Delayed Loop // --
task.spawn(function()
    while task.wait(0.1) do
        if getgenv().Silent.Startup.Enabled then  -- Check if Silent Aim is enabled
            Target = GetClosestPlr()
            Fov.Visible = IsTargeting and getgenv().Silent.Startup.FovSettings.FovVisible  -- Update visibility based on targeting
        end
    end
end)

  
  
  
  
  
  -- // Hook Tool Activation // --
local function HookTool(tool)
    if tool:IsA("Tool") then
        tool.Activated:Connect(function()
            if Target and Target.Character and tick() - lastToolUse > 0.1 then  -- Debounce for 0.1 seconds
                lastToolUse = tick()
                local closestPart, closestPoint = GetClosestHitPoint(Target.Character)
                if closestPart and closestPoint then
                    local velocity = GetVelocity(Target, closestPart.Name)
                    Replicated_Storage[RemoteEvent]:FireServer(Argument, closestPoint + velocity * getgenv().Silent.Startup.Prediction)  -- Updated access
                end
            end
        end)
    end
end

  
  local function onCharacterAdded(character)
      character.ChildAdded:Connect(HookTool)
      for _, tool in pairs(character:GetChildren()) do
          HookTool(tool)
      end
  end
  
  Local_Player.CharacterAdded:Connect(onCharacterAdded)
  if Local_Player.Character then
      onCharacterAdded(Local_Player.Character)
  end
  
  if getgenv().Adjustment.Checks.NoGroundShots == true then
    local function CheckNoGroundShots(Plr)
        if getgenv().Adjustment.Checks.NoGroundShots and Plr.Character:FindFirstChild("Humanoid") and Plr.Character.Humanoid:GetState() == Enum.HumanoidStateType.Freefall then
            pcall(function()
                local TargetVelv5 = Plr.Character:FindFirstChild(getgenv().Silent.Startup.Enabled and getgenv().Silent.Startup.Enabled)  -- Updated access
                if TargetVelv5 then
                    TargetVelv5.Velocity = Vector3.new(TargetVelv5.Velocity.X, (TargetVelv5.Velocity.Y * 0.2), TargetVelv5.Velocity.Z)
                    TargetVelv5.AssemblyLinearVelocity = Vector3.new(TargetVelv5.Velocity.X, (TargetVelv5.Velocity.Y * 0.2), TargetVelv5.Velocity.Z)
                end
            end)
        end
    end
end
