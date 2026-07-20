--[[
Copyright: Ajatt-Tools and contributors; https://github.com/Ajatt-Tools
License: GNU GPL, version 3 or later; http://www.gnu.org/licenses/gpl.html

Fixtures shared by standalone and in-mpv tests.
]]

local defaults = require('config.defaults')
local mp = require('mp')
local h = require('helpers')

local this = {}

local function pack(...)
    return { n = select('#', ...), ... }
end

function this.contains(args, expected)
    --- Return true when args contains expected.
    for _, arg in ipairs(args) do
        if arg == expected then
            return true
        end
    end
    return false
end

function this.index_of(args, expected)
    --- Return the one-based index of expected in args, or nil when absent.
    for i, arg in ipairs(args) do
        if arg == expected then
            return i
        end
    end
    return nil
end

function this.make_config(opts)
    --- Return config for encoder tests, based on the real defaults.
    opts = opts or {}
    local config = defaults.get_default()
    config.video_folder_path = opts.video_folder_path or '/tmp'
    config.audio_folder_path = opts.audio_folder_path or '/tmp'
    for key, value in pairs(opts) do
        config[key] = value
    end
    return config
end

function this.with_properties(callable, properties)
    --- Temporarily set mp properties while callable runs, then restore originals.
    local original_properties = {}

    for name, value in pairs(properties) do
        table.insert(original_properties, {
            name = name,
            value = mp.get_property(name),
        })
        mp.set_property(name, value)
    end

    local result = pack(pcall(callable))

    for _, property in ipairs(original_properties) do
        if property.value ~= nil then
            mp.set_property(property.name, property.value)
        end
    end

    if result[1] == false then
        error(result[2])
    end

    return h.unpack(result, 2, result.n)
end

function this.make_timings()
    --- Return minimal timings for encoder tests.
    return { start = 1, ['end'] = 2, validate = function() return true end, reset = function() end }
end

return this
