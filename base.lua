--[[
Parses files (lua tables) in the data folder
and returns a big table
]]--

function getFiles(folder, type)
	local i, t, popen = 0, {}, io.popen
	local pfile = popen('ls -a '..folder..' | grep lua | grep '..type)
	for filename in pfile:lines() do
		i = i + 1
		t[i] = folder..'/'..filename
	end
	pfile:close()
    return t
end


local base = {}

base["anime"] = {}
for i,j in pairs(getFiles("data", "anime")) do
	table.insert(base["anime"], dofile(j)) 
end

base["manga"] = {}
for i,j in pairs(getFiles("data", "manga")) do
	table.insert(base["manga"], dofile(j)) 
end



print(base["anime"][1]["review"][1]["text"])
return base
