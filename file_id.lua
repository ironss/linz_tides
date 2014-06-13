

local function md5sum(filename)
   local f = io.popen(string.format('md5sum "%s"', filename))
   local l = f:read('*l')
   f:close()
   
   local md5sum = l:sub(1, 32)
   return md5sum
end

local M = {}

M.md5sum = md5sum

return M

