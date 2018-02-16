dark = require("dark")
base = dofile("base.lua")



local function listCharacterNames(table, characterNames, characterFirstnames, characterLastnames)
	for key, work in pairs(table) do
		for key2, character in pairs(work["characters"]) do
			local found = false
			for key3, autres in pairs(characterNames) do
				if autres["firstname"] == character["firstname"] and autres["lastname"] == character["lastname"] then
					found = true
					break
				end
			end
			if found==false then
				characterNames[#characterNames+1] = {["firstname"] = character["firstname"], ["lastname"] = character["lastname"]}
			end
			found = false
			for key3, autres in pairs(characterFirstnames) do
				if autres == character["firstname"] then
					found = true
					break
				end
			end
			if found==false then
				characterFirstnames[#characterFirstnames+1] = character["firstname"]
			end
			found = false
			for key3, autres in pairs(characterLastnames) do
				if autres == character["lastname"] then
					found = true
					break
				end
			end
			if found==false then
				characterLastnames[#characterLastnames+1] = character["lastname"]
			end
		end
	end
	return characterNames, characterFirstnames, characterLastnames
end

function listTitles(base)
	mangaTitles = {}
	animeTitles = {}
	--for
end

local function listAdjectives(adjectives)
	adjList = {}
	for key, groups in pairs(adjectives) do
		for key2, adj in pairs(groups) do
			adjList[#adjList+1] = adj
		end
	end
	return adjList
end

adjectives = dofile("adjectives.lua")
adjList = listAdjectives(adjectives)
characterNames = {}
characterFirstNames = {}
characterLastNames = {}
characterNames, characterFirstNames, characterLastNames = listCharacterNames(base["manga"], characterNames, characterFirstNames, characterLastNames)
characterNames, characterFirstNames, characterLastNames = listCharacterNames(base["anime"], characterNames, characterFirstNames, characterLastNames)

--print(serialize(adjList))
print("I am ready !")

local input = ""
local answer = "I am sorry, I do not understand"

dofile("dark/main.lua")
repeat
	local input = io.read()
	if input == "hello" then
		answer = "Hello, how can I help you?"
	end
	if input == "bye" then
		answer = "See you soon!"
	end
	for key, chara in pairs(characterNames) do
		if string.find(input, chara["firstname"]) and string.find(input, chara["lastname"]) then
			answer = "You want some information about"..chara["firstname"].." "..chara["lastname"].."." 
			break
		end
		if (#chara["firstname"]>0 and string.find(input, chara["firstname"])) or (#chara["lastname"]>0 and string.find(input, chara["lastname"])) then
			answer = "Did you mean "..chara["firstname"].." "..chara["lastname"].."?" 
		end
	end
	print(answer)
	answer = "I am sorry, I do not understand"
until input == "bye"
