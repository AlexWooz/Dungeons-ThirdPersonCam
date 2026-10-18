-- TPCDiscovery: dev-only UE4SS mod for the Dungeons third-person camera project.
-- Not shipped. Dumps what the Blueprint mod needs to know about input and the camera.
--   F7 = dump input mappings (look for the right-stick roll axis names)
--   F8 = dump pawn, controller, view target and every camera / spring arm in the world
--        (not F9: the game binds F9 to "DeleteCharacter")
-- Output goes to the UE4SS console and UE4SS.log next to Dungeons-Win64-Shipping.exe.

local function log(fmt, ...)
    print(string.format("[TPCDiscovery] " .. fmt .. "\n", ...))
end

local function name(obj)
    if obj ~= nil and obj:IsValid() then return obj:GetFullName() end
    return "<none>"
end

local function classChain(obj)
    local parts = {}
    local cls = obj:GetClass()
    while cls ~= nil and cls:IsValid() do
        table.insert(parts, cls:GetFName():ToString())
        cls = cls:GetSuperStruct()
    end
    return table.concat(parts, " -> ")
end

local function dumpMappings(label, owner)
    if owner == nil or not owner:IsValid() then
        log("%s: not found", label)
        return
    end
    log("---- %s axis mappings ----", label)
    pcall(function()
        owner.AxisMappings:ForEach(function(_, elem)
            local m = elem:get()
            log("  axis   %-28s %-20s scale %.2f", m.AxisName:ToString(), m.Key.KeyName:ToString(), m.Scale)
        end)
    end)
    log("---- %s action mappings ----", label)
    pcall(function()
        owner.ActionMappings:ForEach(function(_, elem)
            local m = elem:get()
            log("  action %-28s %s", m.ActionName:ToString(), m.Key.KeyName:ToString())
        end)
    end)
end

local function rot(comp)
    local ok, r = pcall(function() return comp:K2_GetComponentRotation() end)
    if ok and r then return string.format("P %.1f Y %.1f R %.1f", r.Pitch, r.Yaw, r.Roll) end
    return "?"
end

RegisterKeyBind(Key.F7, function()
    dumpMappings("InputSettings (DefaultInput.ini)", StaticFindObject("/Script/Engine.Default__InputSettings"))
    local pc = FindFirstOf("PlayerController")
    if pc and pc:IsValid() then
        dumpMappings("PlayerInput (runtime)", pc.PlayerInput)
    end
end)

RegisterKeyBind(Key.F8, function()
    local pc = FindFirstOf("PlayerController")
    if not pc or not pc:IsValid() then
        log("no PlayerController yet; load into camp or a mission")
        return
    end
    log("PlayerController: %s", name(pc))
    log("  class chain: %s", classChain(pc))
    log("CameraManager: %s", name(pc.PlayerCameraManager))

    local ok, vt = pcall(function() return pc.PlayerCameraManager.ViewTarget.Target end)
    log("ViewTarget: %s", ok and name(vt) or "<unreadable>")

    local pawn = pc.Pawn
    if pawn and pawn:IsValid() then
        log("Pawn: %s", name(pawn))
        log("  class chain: %s", classChain(pawn))
        local okMove, move = pcall(function() return pawn.CharacterMovement end)
        log("  CharacterMovement: %s", okMove and name(move) or "<none>")
    end

    for _, cls in ipairs({ "CameraComponent", "SpringArmComponent", "CameraActor" }) do
        local all = FindAllOf(cls) or {}
        log("---- %s (%d) ----", cls, #all)
        for _, c in ipairs(all) do
            local owner = "<n/a>"
            pcall(function() owner = name(c:GetOwner()) end)
            log("  %s  owner=%s  rot=%s", name(c), owner, rot(c))
        end
    end
end)

log("loaded: F7 = input mappings, F8 = camera/pawn dump")
