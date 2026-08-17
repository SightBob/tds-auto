-- JNKIE inner-script dumper. Run this INSTEAD of AutoProgress.lua directly.
-- Dumps every loadstring payload + every HTTP response body to workspace folder.

local DUMP_PREFIX = "dump_"
local dumpCount = 0

local function dump(name, content)
    if type(content) ~= "string" or #content == 0 then
        return
    end
    dumpCount = dumpCount + 1
    local fname = DUMP_PREFIX .. dumpCount .. "_" .. name .. ".lua"
    pcall(function()
        writefile(fname, content)
    end)
    print("[DUMP] " .. fname .. " (" .. #content .. " bytes)")
end

-- Hook loadstring: catches the final `loadstring(b)` in the jnkie loader
local realLoadstring = loadstring
loadstring = function(src, ...)
    if type(src) == "string" then
        local tag = "loadstring"
        if src:find("JNKIE Loader") then
            tag = "LOADER"
        elseif #src > 30000 then
            tag = "INNER_BIG"
        end
        dump(tag, src)
    end
    return realLoadstring(src, ...)
end

-- Hook request functions: catches delivery endpoint POST + CDN GET
local function hookRequest(original, label)
    if type(original) ~= "function" then
        return original
    end
    return function(options, ...)
        local isDelivery = type(options) == "table"
            and type(options.Url) == "string"
            and options.Url:find("api.jnkie.com")

        local response = original(options, ...)

        if isDelivery and type(response) == "table" then
            dump(label .. "_RESPONSE", tostring(response.Body))
            print("[DUMP] request -> " .. tostring(options.Url)
                .. " | status " .. tostring(response.StatusCode))
        end

        return response
    end
end

if type(syn) == "table" and type(syn.request) == "function" then
    syn.request = hookRequest(syn.request, "syn")
end
if type(request) == "function" then
    request = hookRequest(request, "request")
    getgenv().request = request
end
if type(http_request) == "function" then
    http_request = hookRequest(http_request, "http_request")
    getgenv().http_request = http_request
end
if type(http) == "table" and type(http.request) == "function" then
    http.request = hookRequest(http.request, "http")
end

print("[DUMP] hooks installed, loading AutoProgress...")

local ok, err = pcall(function()
    realLoadstring(game:HttpGet(
        "https://raw.githubusercontent.com/SightBob/tds-auto/refs/heads/main/AutoProgress.lua"
    ))()
end)

if not ok then
    warn("[DUMP] AutoProgress error: " .. tostring(err))
end

print("[DUMP] done, " .. dumpCount .. " file(s) written")
