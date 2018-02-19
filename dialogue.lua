dark = require("dark")
base = dofile("base.lua")
dofile("listFunctions.lua")

local function getFocusQ(quest,oldFocus)
	--quest = dark.sequence(quest)
	print(quest:tostring(tags))
	if(#quest["#CHARACTERNAME"]) ~= 0 then
		oldFocus.name = question:tag2str("#CHARACTERNAME")
	else
		oldFocus.name = nil
	end

	if(#quest["#QDESCRIPTION1"])  ~= 0 then
		oldFocus.quest = "QDESCRIPTION1"
	elseif (#quest["#QDESCRIPTION2"]) ~= 0 then
		oldFocus.quest = "QDESCRIPTION2"
	elseif (#quest["#QTHEME1"]) ~= 0 then
		oldFocus.quest = "QTHEME1"
	elseif (#quest["#QUNKNOWN"]) ~= 0 then
		oldFocus.quest = "QUNKNOWN"
	end
	print(oldFocus.quest)
	if oldFocus.name ~= nil then
		for k,v in ipairs(oldFocus.name) do
			print("\t",k,v)
		end
	end
	return oldFocus

end

adjectives = dofile("adjectives.lua")
adjList = listAdjectives(adjectives)
characterNames = {}
characterFirstNames = {}
characterLastNames = {}
mangaTitles, animeTitles, titles = listTitles(base)
characterNames, characterFirstNames, characterLastNames = listCharacterNames(base["manga"], characterNames, characterFirstNames, characterLastNames)
characterNames, characterFirstNames, characterLastNames = listCharacterNames(base["anime"], characterNames, characterFirstNames, characterLastNames)

--print(serialize(adjList))
print("I am ready !")

local input = ""
local answer = "I am sorry, I do not understand"


dofile("dark/readQuestion.lua")
focusQuestion = {}
repeat
	local input = io.read()
	if input == "hello" then
		answer = "Hello, how can I help you?"
	end
	if input == "bye" then
		answer = "See you soon!"
	end
	question = input:gsub("(%p)"," %1 ")
	question = dark.sequence(question)
	main(question)
	print(main(question))
	focusQuestion = getFocusQ(question,focusQuestion)
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
