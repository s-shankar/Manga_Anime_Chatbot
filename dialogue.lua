dark = require("dark")
base = dofile("base.lua")
dofile("listFunctions.lua")

local function getFocusQ(quest)
	quest = dark.sequence(quest)

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
	question = input:gsub("(%p)","% l ")
	question = dark.sequence(question)
	pipe(question)
	print(pipe(question))
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
