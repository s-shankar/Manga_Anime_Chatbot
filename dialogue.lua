dark = require("dark")
base = dofile("base.lua")
dofile("functions.lua")

local function getFocusQ(quest,oldFocus)
	--quest = dark.sequence(quest)
	if(quest == "hello" or quest =="bye") then
		oldFocus.name = nil
		oldFocus.quest = nil
		return oldFocus
	end
	quest = quest:gsub("(%p)"," %1 ")
	quest = dark.sequence(quest)
	quest = main(quest)
	print(quest:tostring(tags))

	if(#quest["#CHARACTERNAME"]) ~= 0 then
		oldFocus.name = {}
		for i,name in ipairs(quest:tag2str("#CHARACTERNAME")) do
			local nameTab = {}
			for partName in string.gmatch(name, "%S+") do
				table.insert(nameTab,partName)
			end
			oldFocus.name[#oldFocus.name+1] = nameTab 
		end
	else
		oldFocus.name = nil
	end

	if(#quest["#TITLE"]) ~= 0 then
		oldFocus.title = {}
		local tTab = {}
		for i,v in ipairs(quest:tag2str("#TITLE")) do
			print(i,v)
			tTab[#tTab+1]=v
		end
		table.insert(oldFocus.title,tTab)
	end
	if(#quest["#BEHAVIOUR"]) ~= 0 then
		oldFocus.behav = {}
		local behavTab = {}
		for i,v in pairs(quest:tag2str("#BEHAVIOUR")) do
			print(i,v)
			behavTab[#behavTab+1] = v
		end
		table.insert(oldFocus.behav,behavTab)
	end

	if(#quest["#QTHEME1"]) ~= 0 then
		oldFocus.theme = {}
		local themeTab = {}
		for i,th in ipairs(quest:tag2str("#QTHEME1")) do
			themeTab[#themeTab+1] = th
		end
		table.insert(oldFocus.theme,themeTab)
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
		--print(#oldFocus.name)
		for k,v in ipairs(oldFocus.name) do
			for a,o in pairs(v) do
				print(a,o)
			end
			--print("lol")
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
	answer = "I am sorry, I do not understand"
	local input = io.read()
	if input == "hello" then
		answer = "Hello, how can I help you?"
	end
	if input == "bye" then
		answer = "See you soon!"
	end
	
	focusQuestion = getFocusQ(input,focusQuestion)
	if focusQuestion.quest == "QDESCRIPTION1" then
		answer=""
		for i,chara in ipairs(focusQuestion.name) do
			if i > 1 then
				answer = answer..'\n'
			end
			local fname, lname=nil,nil
			if #chara == 1 then
				fname = chara[1]
			elseif #chara == 2 then
				fname,lname = chara[1],chara[2]
			end
			--print("\t",fname,lname,#chara,chara[1],chara[2])
			resultListName = findCharacterName(fname,lname,characterNames)
			if #resultListName ~= 0 then
				answer = answer..""
				if #resultListName == 1 then
					workTitle = charaFromWhichAnimeOrManga(resultListName[1]["firstname"],resultListName[1]["lastname"])
					if fname and lname then
						answer = answer.."Yes, I know "..resultListName[1]["firstname"]..' '..resultListName[1]["lastname"].." from "..workTitle.."."
					else
						answer = answer.."Hum, I only know one character called like that : "..resultListName[1]["firstname"]..' '..resultListName[1]["lastname"].." from "..workTitle.."."
					end
				elseif #resultListName > 1 then
					if fname and last then
						answer = answer.."Hmmm, I know many characters named"..fname..' '..lname
						--[[for k,possibleName in pairs(resultListName) do
							local count = 1
							workTitle = charaFromWhichAnimeOrManga(fname,lname)
							answer = answer..'\n'
							if count > 1 then
								answer = answer..' and '
							end
							answer = answer.."Yes, I know "..fname..' '..lname.."from "..workTitle.."."
						end]]--
					else
						answer = answer.."Well, there are many characters called "..fname..'.\n'
						for i,possibleName in ipairs(resultListName) do
							workTitle = charaFromWhichAnimeOrManga(possibleName["firstname"],possibleName["lastname"])
							if i == #resultListName then
								answer = answer.."\nFinally, "
							elseif i > 1 then
								answer = answer.."\nAlso, "
							else
								answer = answer.."\nFirst, "
							end
							answer = answer.." I know "..possibleName["firstname"]..' '..possibleName["lastname"].." from "..workTitle.."."
						end
					end
				end
			else
				answer = answer..'Sorry , I do no know this character...'
			end
		end
	end
	--[[for key, chara in pairs(characterNames) do
		if string.find(input, chara["firstname"]) and string.find(input, chara["lastname"]) then
			answer = "You want some information about"..chara["firstname"].." "..chara["lastname"].."."
			break
		end
		if (#chara["firstname"]>0 and string.find(input, chara["firstname"])) or (#chara["lastname"]>0 and string.find(input, chara["lastname"])) then
			answer = "Did you mean "..chara["firstname"].." "..chara["lastname"].."?"
		end
	end]]--
	print(answer)
until input == "bye"
