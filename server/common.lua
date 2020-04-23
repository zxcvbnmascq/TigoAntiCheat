-- Core
AntiCheat                           = {}
AntiCheat.StartedPlayers            = {}
AntiCheat.ServerEvents              = {}
AntiCheat.ClientCallbacks           = {}
AntiCheat.ClientEvents              = {}
AntiCheat.Bans                      = {}
AntiCheat.FileGenerators            = {}
AntiCheat.GeneratedFiles            = {}
AntiCheat.Caches                    = {}
AntiCheat.Locales                   = {}
AntiCheat.IPWhitelist               = {}
AntiCheat.EncryptedResourceName     = nil
AntiCheat.EncryptedResourceParams   = {}
AntiCheat.AlradyEncryptedParams     = {}

-- Checks
AntiCheat.FileGeneratorsGenerated   = false
AntiCheat.ResourceIsLoaded          = false
AntiCheat.BanlistIsLoaded           = false

-- Functions
-- Trigger callback when TigoAntiCheat is started
AntiCheat.Ready = function(cb)
    if (cb == nil) then
        return
    end

    Citizen.CreateThread(function ()
        while GetResourceState(GetCurrentResourceName()) ~= 'started' do
            Citizen.Wait(0)
        end

        cb()
    end)
end

-- Trigger callback when TigoAntiCheat is loaded
AntiCheat.FullyReady = function(cb)
    if (cb == nil) then
        return
    end

    Citizen.CreateThread(function()
        while not AntiCheat.ResourceIsLoaded do
            Citizen.Wait(0)
        end

        cb()
    end)
end

-- Register new server callbacks
AntiCheat.RegisterServerCallback = function(name, cb)
    name = string.lower(name or 'unknown')

    if (cb ~= nil) then
        AntiCheat.ServerCallbacks[name] = cb
    end
end

-- Register new server events
AntiCheat.RegisterServerEvent = function(name, cb)
    name = string.lower(name or 'unknown')

    if (cb ~= nil) then
        AntiCheat.ServerEvents[name] = cb
    end
end

-- Trigger client callback
AntiCheat.TriggerClientCallback = function(source, name, cb, ...)
    if (source == nil or source <= 0) then
        return
    end

    local params = ...

    Citizen.CreateThread(function()
        local playerId = tostring(source)

        while AntiCheat.EncryptedResourceName == nil do
            Citizen.Wait(0)
        end

        if (AntiCheat.ClientCallbacks[playerId] == nil) then
            AntiCheat.ClientCallbacks[playerId] = {}
            AntiCheat.ClientCallbacks[playerId].CurrentRequestId = 0
        end

        local currentRequestId = AntiCheat.ClientCallbacks[playerId].CurrentRequestId

        AntiCheat.ClientCallbacks[playerId][tostring(currentRequestId)] = cb

        local clientEventCallback = AntiCheat.GenerateEvent(name)

        TriggerClientEvent(AntiCheat.GenerateEvent('triggerClientCallback'), source, clientEventCallback, currentRequestId, params)

        if (currentRequestId < 65535) then
            AntiCheat.ClientCallbacks[playerId].CurrentRequestId = currentRequestId + 1
        else
            AntiCheat.ClientCallbacks[playerId].CurrentRequestId = 0
        end
    end)
end

-- Trigger server callback
AntiCheat.TriggerServerCallback = function(source, name, cb, ...)
    if (source == nil or source <= 0) then
        return
    end

    local params = ...

    Citizen.CreateThread(function()
        while AntiCheat.EncryptedResourceParams == nil do
            Citizen.Wait(0)
        end

        if (AntiCheat.ServerCallbacks ~= nil and AntiCheat.ServerCallbacks[name] ~= nil) then
            AntiCheat.ServerCallbacks[name](source, cb, params)
        else
            print(AntiCheat.Render('[{{{resource}}}][ERROR] TriggerServerCallback => Server callback {{{callback}}} has not been found', {
                resource = GetCurrentResourceName(),
                callback = name
            }))
        end
    end)
end

-- Trigger server event
AntiCheat.TriggerServerEvent = function(source, name, ...)
    if (source == nil or source <= 0) then
        return
    end

    local params = ...

    Citizen.CreateThread(function()
        while AntiCheat.EncryptedResourceParams == nil do
            Citizen.Wait(0)
        end

        if (AntiCheat.ServerEvents ~= nil and AntiCheat.ServerEvents[name] ~= nil) then
            AntiCheat.ServerEvents[name](source, params)
        else
            print(AntiCheat.Render('[{{{resource}}}][ERROR] TriggerServerEvent => Server event {{{event}}} has not been found', {
                resource = GetCurrentResourceName(),
                event = name
            }))
        end
    end)
end

-- Generate new event name with given suffix
AntiCheat.GenerateEvent = function(suffix, ignorePrefix)
    ignorePrefix = ignorePrefix or false

    while AntiCheat.EncryptedResourceName == nil or AntiCheat.EncryptedResourceParams == nil do
        Citizen.Wait(0)
    end

    if (AntiCheat.AlradyEncryptedParams[string.lower(suffix)] ~= nil) then
        local storedValue = AntiCheat.AlradyEncryptedParams[string.lower(suffix)]

        AntiCheat.EncryptedResourceParams[storedValue] = suffix

        if (ignorePrefix) then
            return storedValue
        else
            return AntiCheat.Render('{{{resource}}}:{{{suffix}}}', {
                resource = AntiCheat.EncryptedResourceName,
                suffix = storedValue
            })
        end
    end

    local newEvent = AntiCheat.GenerateRandomString()

    while AntiCheat.EncryptedResourceParams[newEvent] ~= nil do
        newEvent = AntiCheat.GenerateRandomString()
    end

    AntiCheat.EncryptedResourceParams[newEvent] = suffix
    AntiCheat.AlradyEncryptedParams[string.lower(suffix)] = newEvent

    if (ignorePrefix) then
        return newEvent
    else
        return AntiCheat.Render('{{{resource}}}:{{{suffix}}}', {
            resource = AntiCheat.EncryptedResourceName,
            suffix = newEvent
        })
    end
end

-- Generate random string
AntiCheat.GenerateRandomString = function(length)
    if (length == nil or not length) then
        math.randomseed(os.clock()^4)

        length = math.random(12, 24)
    end

    local charset = {}  do -- [0-9a-zA-Z]
        for c = 48, 57  do table.insert(charset, string.char(c)) end
        for c = 65, 90  do table.insert(charset, string.char(c)) end
        for c = 97, 122 do table.insert(charset, string.char(c)) end
    end

    if (length == 1) then
        math.randomseed(os.clock()^3)

        if ((math.random(5, 75) %2) == 0) then
            return string.char(math.random(65, 90))
        end

        return string.char(math.random(97, 122))
    end

    if (not length or length <= 0) then
        return ''
    end

    math.randomseed(os.clock()^5)

    return AntiCheat.GenerateRandomString(length - 1) .. charset[math.random(1, #charset)]
end

-- Returns if object is null and hasn't a type mismatch
AntiCheat.IsNullOrDefault = function(object, objType, checkEmpty)
    object = object or nil
    checkEmpty = checkEmpty or false

    if (object == nil) then
        return true
    end

    if (object ~= nil and objType == nil) then
        objType = type(object)
    elseif (objType == nil) then
        objType = 'none'
    else
        objType = string.lower(objType)
    end

    local default = nil
    local expectedType = ''

    if (objType == 'table' or objType == 't') then
        default = {}
        expectedType = 'table'
    elseif (objType == 'string' or objType == 's' or objType == 'str') then
        default = ''
        expectedType = 'string'
    elseif (objType == 'number' or objType == 'n' or objType == 'num') then
        default = 0
        expectedType = 'number'
    elseif (objType == 'boolean' or objType == 'b' or objType == 'bool') then
        default = false
        expectedType = 'boolean'
    elseif (objType == 'function' or objType == 'f' or objType == 'func') then
        default = function() end
        expectedType = 'function'
    end

    if (default == nil) then
        return true
    end

    return false
end

-- Returns if player is allowed to be ignored
AntiCheat.IsPlayerBypassed = function(playerId)
    local isConsole = (playerId == nil or playerId <= 0 or tostring(playerId) == '0')

    if (isConsole) then
        return true
    end

    if (not (AntiCheat.BypassEnabled or false)) then
        return false
    end

    local ace = AntiCheat.BypassAce or 'tigoanticheat.bypass'

    return IsPlayerAceAllowed(playerId, ace)
end

-- Returns if table contains given item
AntiCheat.TableContainsItem = function(item, table, ignoreCase)
    return AntiCheat.TableContainsAnyItem({ item }, table, ignoreCase)
end

-- Returns if table contains any item in items
AntiCheat.TableContainsAnyItem = function (items, table, ignoreCase)
    items = items or {}
    table = table or {}
    ignoreCase = ignoreCase or false

    if (string.lower(type(items)) ~= 'table' or
        string.lower(type(table)) ~= 'table') then
        return false
    end

    if (#items <= 0 or #table <= 0) then
        return false
    end

    if (ignoreCase) then
        ignoreCase = true
    else
        ignoreCase = false
    end

    for _, tableItem in pairs(table) do
        for _, item in pairs(items) do
            if (ignoreCase and AntiCheat.TrimAndLower(tostring(item)) == AntiCheat.TrimAndLower(tostring(tableItem))) then
                return true
            elseif (tostring(item) == tostring(tableItem)) then
                return true
            end
        end
    end

    return false
end

-- Trim value and lower the string
AntiCheat.TrimAndLower = function(value)
    if (value) then
        return string.lower(string.gsub(value, "^%s*(.-)%s*$", "%1"))
    end

    return ''
end

-- Render template with given params
AntiCheat.Render = function(template, params)
    if (AntiCheat.IsNullOrDefault(template, 'string', true)) then
        template = ''
    end

    if (AntiCheat.IsNullOrDefault(params, 'table', true)) then
        params = {}
    end

    local results = Mustache.Render(template, params)

    while results == nil do
        Citizen.Wait(0)
    end

    return results
end

-- Register events when anticheat is ready
AntiCheat.Ready(function()
    AntiCheat.Initialize()
end)

-- When AntiCheat is fully loaded
AntiCheat.FullyReady(function()
    RegisterServerEvent(AntiCheat.GenerateEvent('clientCallback'))
    AddEventHandler(AntiCheat.GenerateEvent('clientCallback'), function(requestId, ...)
        local _source = source
        local playerId = tonumber(_source)
        requestId = requestId or 0

        if (AntiCheat.ClientCallbacks ~= nil and AntiCheat.ClientCallbacks[tostring(playerId)] ~= nil and AntiCheat.ClientCallbacks[tostring(playerId)][tostring(requestId)] ~= nil) then
            AntiCheat.ClientCallbacks[tostring(playerId)][tostring(requestId)](...)
            AntiCheat.ClientCallbacks[tostring(playerId)][tostring(requestId)] = nil
        end
    end)
end)

AddEventHandler('playerConnecting', function(name, setCallback, deferrals)
    AntiCheat.Event.PlayerConnecting(source, setCallback, deferrals)
end)