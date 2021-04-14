--[[
A helper class for styling OSD messages
http://docs.aegisub.org/3.2/ASS_Tags/

Copyright (C) 2021 Ren Tatsumoto

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
]]

local OSD = {}
OSD.__index = OSD

function OSD:new()
    return setmetatable({ text = {} }, self)
end

function OSD:append(s)
    table.insert(self.text, s)
    return self
end

function OSD:bold(s)
    return self:append(string.format([[{\b1}%s{\b0}]], s))
end

function OSD:italics(s)
    return self:append('{\\i1}'):append(s):append('{\\i0}')
end

function OSD:newline()
    return self:append([[\N]])
end

function OSD:tab()
    return self:append([[\h\h\h\h]])
end

function OSD:size(size)
    return self:append(string.format([[{\fs%s}]], size))
end

function OSD:align(number)
    return self:append(string.format([[{\an%s}]], number))
end

function OSD:get_text()
    return table.concat(self.text)
end

return OSD
