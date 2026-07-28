package.path = "videoclip/?.lua;" .. package.path

local mp_properties = {
    path = '/tmp/input.mkv',
    filename = 'input.mkv',
    ['media-title'] = 'input.mkv',
    aid = '1',
    mute = 'no',
    volume = '100',
    ['ytdl-format'] = '',
    sid = 'no',
    ['secondary-sid'] = 'no',
    ['sub-delay'] = '0',
    ['sub-visibility'] = 'yes',
    ['secondary-sub-visibility'] = 'no',
    ['sub-back-color'] = '#00000000',
    ['current-tracks/video/ff-index'] = 0,
    ['current-tracks/audio/ff-index'] = 1,
    ['current-tracks/audio/codec'] = 'aac',
    ['track-list'] = {},
}

local function get_property(name, default)
    local value = mp_properties[name]
    if value == nil then
        return default
    end
    return value
end

local function get_property_native(name)
    return mp_properties[name]
end

local function set_property(name, value)
    mp_properties[name] = value
end

local function command_native(command)
    local args = command.args or {}
    if args[1] == 'mpv' and args[2] == '--version' then
        return { status = 0, stdout = 'mpv 0.40.0', stderr = '' }
    elseif args[1] == 'ffmpeg' and args[2] == '-version' then
        return { status = 0, stdout = 'ffmpeg version n8.1.2', stderr = '' }
    end
    return { status = 0, stdout = '', stderr = '' }
end

local function command_native_async(_, callback)
    if callback then
        callback(nil, { status = 0, stdout = '', stderr = '' }, nil)
    end
end

local function noop()
    return
end

local mp_stub = {
    _videoclip_test_stub = true,
    get_property = get_property,
    get_property_native = get_property_native,
    set_property = set_property,
    command_native = command_native,
    command_native_async = command_native_async,
    msg = {
        info = noop,
        warn = noop,
        error = noop,
    },
    osd_message = noop,
    get_property_osd = function()
        return ''
    end,
}

local function json_escape_string(s)
    local replacements = {
        ['"'] = '\\"',
        ['\\'] = '\\\\',
        ['\n'] = '\\n',
        ['\r'] = '\\r',
        ['\t'] = '\\t',
    }
    return '"' .. s:gsub('["\\\n\r\t]', replacements) .. '"'
end

local function is_array(t)
    local n = #t
    for k, _ in pairs(t) do
        if type(k) ~= "number" or k < 1 or k > n or k ~= math.floor(k) then
            return false
        end
    end
    return true
end

local function format_json(value)
    local t = type(value)
    if value == nil then
        return "null"
    elseif t == "boolean" then
        return value and "true" or "false"
    elseif t == "number" then
        if value ~= value then
            return "null"
        end -- NaN
        if value == math.huge then
            return "null"
        end
        if value == -math.huge then
            return "null"
        end
        -- Format integers without decimal point
        if value == math.floor(value) and math.abs(value) < 1e15 then
            return string.format("%d", value)
        end
        return tostring(value)
    elseif t == "string" then
        return json_escape_string(value)
    elseif t == "table" then
        if next(value) == nil then
            -- mpv's format_json treats empty tables as empty arrays.
            return "[]"
        end
        if is_array(value) then
            local parts = {}
            for i = 1, #value do
                parts[i] = format_json(value[i])
            end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            -- Sort keys alphabetically for deterministic output.
            local keys = {}
            for k in pairs(value) do
                keys[#keys + 1] = k
            end
            table.sort(keys, function(a, b)
                return tostring(a) < tostring(b)
            end)
            local parts = {}
            for _, k in ipairs(keys) do
                parts[#parts + 1] = json_escape_string(tostring(k)) .. ":" .. format_json(value[k])
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    else
        error("format_json: unsupported type: " .. t)
    end
end

local mp_msg_stub = {
    info = noop,
    warn = noop,
    error = noop,
    fatal = noop,
    trace = noop,
    debug = noop,
    verbose = noop,
}

local mp_options_stub = {
    read_options = noop,
}

local mp_utils_stub = {
    format_json = format_json,
    join_path = function(parent, child)
        return parent .. '/' .. child
    end,
    split_path = function(path)
        local dir, file = path:match("^(.*/)(.*)")
        return dir or '', file or path
    end,
    file_info = function()
        return nil
    end,
}

-- Register stubs before any videoclip module is required.
package.loaded['mp'] = mp_stub
package.loaded['mp.msg'] = mp_msg_stub
package.loaded['mp.utils'] = mp_utils_stub
package.loaded['mp.options'] = mp_options_stub

local fixtures = require('test_fixtures')

local h = require('helpers')

h.subprocess = function(args)
    if args[1] == 'mpv' and args[2] == '--version' then
        return { status = 0, stdout = 'mpv 0.40.0', stderr = '' }
    elseif args[1] == 'ffmpeg' and args[2] == '-version' then
        return { status = 0, stdout = 'ffmpeg version n8.1.2', stderr = '' }
    end
    return { status = 0, stdout = '', stderr = '' }
end

h.subprocess_async = function(_, callback)
    if callback then
        callback(nil, { status = 0, stdout = '', stderr = '' }, nil)
    end
end

h.expand_path = function(path)
    return path
end

h.assert_equals(mp_utils_stub.format_json({ a = 1 }), '{"a":1}')

return fixtures
