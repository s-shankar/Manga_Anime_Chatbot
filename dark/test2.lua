local pipe = dark.pipeline()
pipe:basic()
pipe:lexicon("#monument", {"Tour Eiffel", "Notre Dame"})
pipe:lexicon("#unite",    {"metre"})
pipe:pattern("[#valeur #d]")
pipe:pattern("[#mesure #valeur #unite]")

pipe:pattern("[#hauteur #monument 'mesure' #mesure]")

local tags = {
	["#monument"] = "red",
	["#unite"]    = "red",
	["#valeur"]   = "red",
	["#mesure"]   = "green",
	["#hauteur"]  = "yellow",
}

function havetag(seq, tag)
	return #seq[tag] ~= 0
end

function tagstr(seq, tag, lim_debut, lim_fin)
	lim_debut = lim_debut or 1
	lim_fin   = lim_fin   or #seq
	if not havetag(seq, tag) then
		return nil
	end
	local list = seq[tag]
	for i, position in ipairs(list) do
		local debut, fin = position[1], position[2]
		if debut >= lim_debut and fin <= lim_fin then
			local tokens = {}
			for i = debut, fin do
				tokens[#tokens + 1] = seq[i].token
			end
			return table.concat(tokens, " ")
		end
	end
	return nil
end

function GetValueInLink(seq, entity, link)
	for i, pos in ipairs(seq[link]) do
		local res = tagstr(seq, entity, pos[1], pos[2])
		if res then
			return res
		end
	end
	return nil
end

local seq = dark.sequence("Près de Notre Dame , la Tour Eiffel mesure 324 metre .")

local db = {
	["Notre Dame"] = {
		position = "Paris",
		date     = 1163,
		hauteur  = {
			valeur = 69,
			unite  = "m",
		},
	},
}

pipe(seq)
if havetag(seq, "#monument") then
	local monu = tagstr(seq, "#monument")
	db[monu] = db[monu] or {}
end
if havetag(seq, "#hauteur") then
	local monu = GetValueInLink(seq, "#monument", "#hauteur")
	local val  = GetValueInLink(seq, "#valeur",   "#hauteur")
	local unit = GetValueInLink(seq, "#unite",    "#hauteur")
	val = tonumber(val)
	if val < 0.1 or val > 2000 then
		-- ...
	else
		db[monu] = db[monu] or {}
		db[monu].hauteur = {
			valeur = val,
			unite  = unit,
		}
	end
end


print(seq:tostring(tags))

local out_file = io.open("database.lua", "w")
out_file:write("return ")
out_file:write(serialize(db))
out_file:close()





local db2 = dofile("base1.lua")

print(serialize(db2))

