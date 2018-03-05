dark = require("dark")
base = dofile("work-base.lua")
dofile("functions.lua")


function getState(question)

	--D'abord hors context
	dialog_state.hctypes, dialog_state.hckey = understandQuestion(question)
	
end

dialog_state = {}



adjectives = dofile("adjectives.lua")
adjList = listAdjectives(adjectives)
characterNames = {}
characterFirstNames = {}
characterLastNames = {}
mangaTitles, animeTitles, titles = listTitles(base)
characterNames, characterFirstNames, characterLastNames = listCharacterNames(base["manga"], characterNames, characterFirstNames, characterLastNames)
characterNames, characterFirstNames, characterLastNames = listCharacterNames(base["anime"], characterNames, characterFirstNames, characterLastNames)

print("Hello !")

local input = ""
local answer = ""


dofile("dark/readQuestion.lua")
focusQuestion = {}
repeat
	answer = ""
	local quit = false
	local input = io.read():lower()
	if input:sub(1,5) == "hello" or input:sub(1,2) == "hi" or (input:sub(1,5) == "good " and (input:sub(6,12) == "morning" or input:sub(6,12) == "evening" or input:sub(6,14) == "afternoon")) then
		answer = "How can I help you?"
	elseif input:sub(1,3) == "bye" or input:sub(1,8) == "good bye" then
		quit = true
		answer = "See you soon!"
	else
		understandQuestion(input)
		--print("testa "..serialize(dialog_state.hckey[1]["themes"]))
		--focusQuestion = getFocusQ(input,focusQuestion)
		
		
		-- en contexte on veut récupérer ssi on a au moins un élément
		-- d'une autre classe (key ou types)
		if (dialog_state.hckey) then
			dialog_state.eckey = dialog_state.hckey
		elseif (dialog_state.hctypes) then
			-- on conserve la key précédente
			dialog_state.eckey = dialog_state.eckey
		else
			dialog_state.eckey = nil
		end

		if (dialog_state.hctypes) then
			dialog_state.ectypes = dialog_state.hctypes
		elseif (dialog_state.hckey) then
			-- on conserve la key précédente
			dialog_state.ectypes = dialog_state.ectypes
		else
			dialog_state.ectypes = nil
		end
		
		--print(serialize(dialog_state.eckey[1]))
		if dialog_state.ectypes then
			if dialog_state.ectypes == "QTHEME" then
				if #dialog_state.eckey == 2 then
					found = false
					for	theme, value in pairs(dialog_state.eckey[1]["themes"]) do
						if dialog_state.eckey[2] == theme then
							found = true
							break
						end
					end
					for	theme, value in pairs(dialog_state.eckey[1]["candidate_themes"]) do
						if dialog_state.eckey[2] == theme then
							found = true
							break
						end
					end
					if found == true then
						answer = "Yes, "..dialog_state.eckey[1]["title"].." is about "..dialog_state.eckey[2].."."
					else 
						answer = "No, "..dialog_state.eckey[1]["title"].." is not about "..dialog_state.eckey[2].."."
					end
				else
					themes = getLargestKeys(dialog_state.eckey[1]["themes"], 3)
					answer = dialog_state.eckey[1]["title"].." is about "..themes[1]
					for i = 2,#themes do
						if i<#themes then
							answer = answer..", "..themes[i]
						else
							answer = answer.." and "..themes[i].."."
						end
					end
					dialog_state.eckey[2] = themes[1]
				end
			elseif dialog_state.ectypes == "QBEHAVIOUR" then
				if #dialog_state.eckey == 2 then
					found = false
					for	k, behav in pairs(dialog_state.eckey[1]["behaviours"]) do
						if dialog_state.eckey[2] == behav then
							found = true
							break
						end
					end
					for	k, behav in pairs(dialog_state.eckey[1]["candidate_behaviours"]) do
						if dialog_state.eckey[2] == behav then
							found = true
							break
						end
					end
					if found == true then
						answer = "Yes, "..dialog_state.eckey[1]["firstname"].." is "..dialog_state.eckey[2].."."
					else 
						answer = "No, "..dialog_state.eckey[1]["firstname"].." is not "..dialog_state.eckey[2].."."
					end
				else
					behavs = dialog_state.eckey[1]["behaviours"]
					--print("test"..serialize(dialog_state.eckey[1]))
					if(#behavs == 0) then
						answer = "I don't know much about "..dialog_state.eckey[1]["firstname"].."."
					else
						answer = dialog_state.eckey[1]["firstname"].." is "..behavs[1]
						for i = 2,#behavs do
							if i<#behavs then
								answer = answer..", "..behavs[i]
							else
								answer = answer.." and "..behavs[i].."."
							end
						end
						dialog_state.eckey[2] = behavs[1]
					end
				end
			else
				answer = "Sorry, I don't understand"
			end
		else
			answer = "Woops, I don't understand your question."
		end
	end
	print(answer)
until quit == true
