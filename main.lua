-- For compatibility, allow running videoclip
-- by placing the project folder in mpv's scripts directory (e.g. ~/.config/mpv/scripts).

local mp = require('mp')
local utils = require('mp.utils')
local src_root = utils.join_path(mp.get_script_directory(), "videoclip")

-- Add src subfolder to Lua search path
package.path = string.format("%s/?.lua;%s", src_root, package.path)
print("new package path", package.path)

-- Run the main script
dofile(utils.join_path(src_root, "main.lua"))
