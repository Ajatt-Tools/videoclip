--[[
Copyright: Ajatt-Tools and contributors; https://github.com/Ajatt-Tools
License: GNU GPL, version 3 or later; http://www.gnu.org/licenses/gpl.html

Various helper functions.
]]

local mp = require('mp')
local utils = require('mp.utils')
local this = {}
local ass_start = mp.get_property_osd("osd-ass-cc/0")

this.unpack = unpack or table.unpack

this.is_empty = function(var)
    return var == nil or var == '' or (type(var) == 'table' and next(var) == nil)
end

this.is_wayland = function()
    return os.getenv('WAYLAND_DISPLAY') ~= nil
end

this.is_win = function()
    return mp.get_property("platform") == "windows"
end

this.is_mac = function()
    return mp.get_property("platform") == "darwin"
end

this.notify = function(message, level, duration)
    level = level or 'info'
    duration = duration or 1
    mp.msg[level](message)
    if level == "error" then
        message = "{\\c&H7171f8&}" .. message
    end
    mp.osd_message(ass_start .. "{\\fs12}{\\bord0.75}" .. message, duration)
end

this.notify_error = function(message, level, duration)
    this.notify(message, level, duration)
end

this.subprocess = function(args, stdin)
    local command_table = {
        name = "subprocess",
        playback_only = false,
        capture_stdout = true,
        capture_stderr = true,
        args = args,
        stdin_data = (stdin or ""),
    }
    return mp.command_native(command_table)
end

this.subprocess_async = function(args, on_complete)
    local command_table = {
        name = "subprocess",
        playback_only = false,
        capture_stdout = true,
        capture_stderr = true,
        args = args
    }
    return mp.command_native_async(command_table, on_complete)
end

this.remove_extension = function(filename)
    return filename:gsub('%.%w+$', '')
end

this.remove_text_in_brackets = function(str)
    return str:gsub('%b[]', '')
end

this.remove_special_characters = function(str)
    return str:gsub('[%-_]', ' '):gsub('[%c%p]', ''):gsub('%s+', ' ')
end

this.strip = function(str)
    return str:gsub("^%s*(.-)%s*$", "%1")
end

this.two_digit = function(num)
    return string.format("%02d", num)
end

this.twelve_hour = function(num)
    local sign = "pm"
    local hour = num

    if num > 12 then
        hour = hour - 12
    else
        sign = "am"
    end

    return { sign = sign, hour = hour }
end

this.expand_path = function(str)
    return mp.command_native({ "expand-path", str })
end

this.human_readable_time = function(seconds)
    if type(seconds) ~= 'number' or seconds < 0 then
        return 'empty'
    end

    local parts = {}

    parts.h = math.floor(seconds / 3600)
    parts.m = math.floor(seconds / 60) % 60
    parts.s = math.floor(seconds % 60)
    parts.ms = math.floor((seconds * 1000) % 1000)

    local ret = string.format("%02dm%02ds%03dms", parts.m, parts.s, parts.ms)

    if parts.h > 0 then
        ret = string.format('%dh%s', parts.h, ret)
    end

    return ret
end

this.quote_if_necessary = function(args)
    local ret = {}
    for _, v in ipairs(args) do
        if v:find(" ", 1, true) or v:find("[", 1, true) then
            table.insert(ret, (v:find("'") and string.format('"%s"', v) or string.format("'%s'", v)))
        else
            table.insert(ret, v)
        end
    end
    return ret
end

--- Create a one-command parser whose helpers share only this instance's private state.
local function make_command_args_parser()
    local args = {}
    local buffer = ""
    local quote_char = nil
    local token_started = false
    local pub = {}

    --- Keep empty quoted arguments while skipping whitespace between tokens.
    local function emit_argument()
        if token_started then
            table.insert(args, buffer)
            buffer = ""
            token_started = false
        end
    end

    --- Track matching quotes without treating the other quote character as syntax.
    local function consume_character(c)
        if quote_char ~= nil then
            if c == quote_char then
                quote_char = nil
            else
                buffer = buffer .. c
            end
        elseif c == '"' or c == "'" then
            quote_char = c
            token_started = true
        elseif c:match("%s") then
            emit_argument()
        else
            buffer = buffer .. c
            token_started = true
        end
    end

    --- Return the grouped arguments, preserving empty groups and unfinished quoted text.
    function pub.parse_args(cmd_str)
        for i = 1, #cmd_str do
            consume_character(cmd_str:sub(i, i))
        end
        emit_argument()
        return args
    end

    return pub
end

--- Split a command string into argv-style tokens, honoring single and double quotes.
--- Return an argument array without shell expansion or backslash escaping.
--- An unmatched quote groups the rest of the input instead of reporting an error.
--- Empty input returns an empty array. All parsing state stays local to this call.
--- mpv's subprocess command takes argv directly, so grouping quotes must be removed here.
--- https://mpv.io/manual/stable/#command-interface
--- Examples:
---    parse_command_args('curl -F file=@x') → { "curl", "-F", "file=@x" }
---    parse_command_args([[curl -F'file=@x']]) → { "curl", "-Ffile=@x" }
---    parse_command_args('curl -F "a b"') → { "curl", "-F", "a b" }
---    parse_command_args('') → {}
this.parse_command_args = function(cmd_str)
    return make_command_args_parser().parse_args(cmd_str)
end

this.query_xdg_user_dir = function(name)
    local r = this.subprocess({ "xdg-user-dir", name })
    if r.status == 0 then
        return this.strip(r.stdout)
    end
    return nil
end

this.query_user_home_dir = function()
    --- "USERPROFILE" is used on ReactOS and other Windows-like systems.
    return os.getenv("HOME") or os.getenv("USERPROFILE")
end

this.clean_forbidden_characters = function(title)
    return title:gsub('[<>:"/\\|%?%*]+', '.')
end

this.repr = function(value)
    --- Return a test-friendly string representation of a value.
    if type(value) == 'table' then
        return utils.format_json(value)
    else
        return value
    end
end

this.equal = function(first, last)
    --- Test whether two values are equal.
    return this.repr(first) == this.repr(last)
end

this.assert_equals = function(actual, expected)
    --- Raise an error if actual and expected are not equal.
    if this.equal(actual, expected) == false then
        error(string.format("TEST FAILED: Expected '%s', got '%s'", this.repr(expected), this.repr(actual)))
    end
end

this.truncate_utf8_bytes = function(s, max_bytes)
    local size = #s
    local idx = 1

    if size <= max_bytes then
        return s
    end

    while idx <= size do
        local b = s:byte(idx)
        local char_len = 1
        if not b then
            break
        end

        if b <= 0x7F then
            char_len = 1
        elseif b >= 0xC2 and b <= 0xDF then
            char_len = 2
        elseif b >= 0xE0 and b <= 0xEF then
            char_len = 3
        elseif b >= 0xF0 and b <= 0xF4 then
            char_len = 4
        else
            break
        end

        if idx - 1 + char_len > max_bytes then
            break
        end

        idx = idx + char_len
    end

    if idx <= 1 then
        return "new_file"
    end
    return s:sub(1, idx - 1)
end

function this.partial(callable, ...)
    local preset = { ... }
    return function(...)
        local args = {}

        for i = 1, #preset do
            args[#args + 1] = preset[i]
        end
        for i = 1, select("#", ...) do
            args[#args + 1] = select(i, ...)
        end

        return callable(this.unpack(args))
    end
end

--- Exercise command grouping without involving a shell or starting an upload.
local function test_parse_command_args()
    for _, case in ipairs({
        { 'curl -F file=@x', { "curl", "-F", "file=@x" } },
        { 'curl -F "a b"', { "curl", "-F", "a b" } },
        -- This is the documented custom-upload form. Shell quotes must not survive in argv.
        { "curl -F'file=@%f' https://0x0.st", { "curl", "-Ffile=@%f", "https://0x0.st" } },
        -- Quotes group argv text, not shell input. Empty groups still occupy an argument.
        { [[tool 'with spaces']], { 'tool', 'with spaces' } },
        { [[tool pre'with spaces'post]], { 'tool', 'prewith spacespost' } },
        { [[tool "don't split"]], { 'tool', "don't split" } },
        { [[tool 'say "hi"']], { 'tool', 'say "hi"' } },
        { [[tool 'one'"two"three]], { 'tool', 'onetwothree' } },
        { [[tool '' ""]], { 'tool', '', '' } },
        { '', {} },
        { '  a  b  ', { "a", "b" } },
    }) do
        this.assert_equals(this.parse_command_args(case[1]), case[2])
    end
end

--- Preserve the small parser's limits instead of silently adding shell behavior.
local function test_command_args_parser_limits()
    for _, case in ipairs({
        { [[tool 'unfinished text]], { 'tool', 'unfinished text' } },
        { [[tool "unfinished text]], { 'tool', 'unfinished text' } },
        { [[tool a\ b]], { 'tool', [[a\]], 'b' } },
        { [[tool "C:\clip folder\video.mp4"]], { 'tool', [[C:\clip folder\video.mp4]] } },
        { [[tool '$HOME;$(echo unsafe)']], { 'tool', '$HOME;$(echo unsafe)' } },
        { [[tool pre''post]], { 'tool', 'prepost' } },
        { "tool\t'a b'\nend", { 'tool', 'a b', 'end' } },
        { '  \t\n  ', {} },
    }) do
        this.assert_equals(this.parse_command_args(case[1]), case[2])
    end
end

--- Unfinished quotes and returned arrays must not carry state into later calls.
local function test_command_args_parser_isolation()
    for _, command in ipairs({ [[tool 'unfinished]], [[tool "unfinished]], [[tool '']] }) do
        local first = this.parse_command_args(command)
        local second = this.parse_command_args('next value')
        assert(first ~= second)
        first[1] = 'changed'
        this.assert_equals(second, { 'next', 'value' })
        this.assert_equals(this.parse_command_args(''), {})
    end
end

this.run_tests = function()
    --- Run unit tests for helper functions.
    this.assert_equals(this.is_empty(nil), true)
    this.assert_equals(this.is_empty(''), true)
    this.assert_equals(this.is_empty({}), true)
    this.assert_equals(this.is_empty('x'), false)

    this.assert_equals(this.remove_extension('video.mkv'), 'video')
    this.assert_equals(this.remove_text_in_brackets('a [b] c'), 'a  c')
    this.assert_equals(this.remove_special_characters('a-b_c!'), 'a b c')
    this.assert_equals(this.strip('  abc  '), 'abc')
    this.assert_equals(this.two_digit(7), '07')
    this.assert_equals(this.twelve_hour(13).hour, 1)
    this.assert_equals(this.twelve_hour(13).sign, 'pm')

    this.assert_equals(this.human_readable_time(-1), 'empty')
    this.assert_equals(this.human_readable_time(61.234), '01m01s234ms')
    this.assert_equals(this.clean_forbidden_characters('a:b?c'), 'a.b.c')
    this.assert_equals(this.repr({ a = 1 }), utils.format_json({ a = 1 }))
    this.assert_equals(this.repr({ a = 1 }), '{"a":1}')
    this.assert_equals(this.equal({ a = 1 }, { a = 1 }), true)
    this.assert_equals(this.truncate_utf8_bytes('abcdef', 3), 'abc')

    local function greet(greeting, name)
        return greeting .. ", " .. name
    end

    this.assert_equals(this.partial(greet, "Hello")("Lua"), "Hello, Lua")

    test_parse_command_args()
    test_command_args_parser_limits()
    test_command_args_parser_isolation()
end

return this
