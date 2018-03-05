-- Création d'un pipeline pour DARK
main = dark.pipeline()


-- Création d'un lexique ou chargement d'un lexique existant
main:lexicon("#CHARACTERFIRSTNAME", characterFirstNames)
main:lexicon("#CHARACTERLASTNAME", characterLastNames)
main:lexicon("#CHIFFRES", {"un","deux","trois","quatre","cinq","six","sept","huit","neuf","dix"})
main:lexicon("#BEHAVIOUR", adjList)
main:lexicon("#MANGATITLE", mangaTitles)
main:lexicon("#ANIMETITLE", animeTitles)
main:lexicon("#TITLE", titles)
main:lexicon("#THEME", "themes")

-- Création de patterns en LUA, soit sur plusieurs lignes pour gagner
-- en visibilité, soit sur une seule ligne. La capture se fait avec
-- les crochets, l'étiquette à afficher est précédée de # : #word

-- Pattern avec expressions régulières (pas de coordination possible)
main:pattern('[#WORD /^%a+$/ ]')
main:pattern('[#PONCT /%p/ ]')

main:pattern([[
	[#CHARACTERNAME
		((#CHARACTERFIRSTNAME #CHARACTERLASTNAME?) | (#CHARACTERLASTNAME #CHARACTERFIRSTNAME?))
	]
]])

main:pattern([[
	[#QDESCRIPTION1
		('how' 'is' .{1,10}?) |
		('tell' 'me' 'how' .{1,10}? 'is') |
		('what' 'is' .{1,10}? '%'' 's' 'main'? 'behaviour') |
		('what' 'are' .{1,10}? '%'' 's' 'main'? 'behaviours') 
	]
]])

main:pattern([[
	[#QDESCRIPTION2
		('is' .{1,10}? #BEHAVIOUR) |
		('is' .{1,10}? 'a' #BEHAVIOUR (('type'|'sort') 'of')? ('person' | 'guy' | 'boy' | 'girl' | 'man' | 'woman' | 'lady')) |
		('tell' 'me' 'if' .{1,10}? 'is' #BEHAVIOUR) |
		('tell' 'me' 'if' .{1,10}? 'is' 'a' #BEHAVIOUR ('person' | 'guy' | 'boy' | 'girl' | 'man' | 'woman' | 'lady'))
	]
]])

main:pattern([[
	[#QTHEME1
		('what' 'is' .{1,10}? 'about' '?'?) |
		('what' 'is' .{1,10}? '%'' 's' 'main' 'theme') |
		('what' 'are' .{1,10}?'%'' 's' 'main' 'themes')
	]
]])

main:pattern([[
	[#QTHEME2
		('is' .{1,10}? 'about' #THEME) |
		('tell' 'me' 'if' .{1,10}? 'is' 'about' #THEME)
	]
]])

main:pattern([[
	[#QUNKNOWN
		('do' 'you' 'know' .{1,10}?) |
		('have' 'you' 'ever'? 'heard' 'of' .{1,10}?) |
		('what' 'about' .{1,10}?)|
		('tell' 'me' 'about' .{1,10}?) 
	]
]])

main:pattern("[#DUREE ( #CHIFFRES | /%d+/ ) ( /mois%p?/ | /jours%p?/ ) ]")

-- Sélection des étiquettes voulues, attribution d'une couleur (black,
-- blue, cyan, green, magenta, red, white, yellow) pour affichage sur
-- le terminal ou valeur "true" si redirection vers un fichier de
-- sortie (obligatoire pour éviter de copier les caractères de
-- contrôle)

tags = {
	["#CHARACTERLASTNAME"] = "blue",
	["#CHARACTERFIRSTNAME"] = "blue",
	["#CHARACTERNAME"] = "cyan",
	["#TITLE"] = "yellow",
	["#ANIMETITLE"] = "blue",
	["#MANGATITLE"] = "blue",
	["#DUREE"] = "magenta",
	["#BEHAVIOUR"] = "red",
	["#QDESCRIPTION1"] = "green",
	["#QDESCRIPTION2"] = "green",
	["#QTHEME1"]	=	"magenta",
	["#QTHEME2"]	=	"magenta",
	["#QUNKNOWN"]	= "green"
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



function process(sen)
	sen = sen:gsub("([^A-Z])(%p)([^A-Z])", "%1 %2 %3")            --%0 correspond à toute la capture
	sen = sen:gsub("([^A-Z])(%p)$", "%1 %2")
	local seq = dark.sequence(sen) -- ça découpe sur les espaces
	return main(seq)
	--print(seq:tostring(tags))
end

--Une phrase finit par un point suivi d'un espace ou d'une majuscule
local function splitsen(line)
	output = {}
	sents = {""}
	local i=1
	for j = 1, #line do
		local letter = line:sub(j,j)
		if letter ~= "." and letter ~= "?" and letter ~= "!" then
			sents[i] = ""..sents[i]..letter
		elseif j == #line or (j==#line-1 and line:sub(j+1, j+1) == " ")then
			sents[i] = ""..sents[i]..letter
			break
		elseif line:sub(j+1,j+1) == " " and line:sub(j+2,j+2):find("[A-Z]") then
			sents[i] = ""..sents[i]..letter
			i=i+1
			sents[i] = ""
		else
			sents[i] = ""..sents[i]..letter
		end
	end
	for key, sen in pairs(sents) do
		p = process(sen)
		output[#output+1] = p
	end
	return output
end


function understandQuestion(question)
	if question~="" then
		local sum = 0
		workfound = {}
		local nbcharacters = 0
		question = process(question)
		if havetag(question, "#CHARACTERNAME") then
			characFound, nbcharacters = findCharacterInWorks(question:tag2str("#CHARACTERNAME")[1])
			sum = nbcharacters
		end
		if havetag(question, "#TITLE") then
			workfound = findWorkFromTitle(question:tag2str("#TITLE")[1])
		end
		
		if havetag(question, "#QUNKNOWN")==true then
			if workfound["anime"] ~= nil then sum = sum+1 end
			if workfound["manga"] ~= nil then sum = sum+1 end
			
			if sum > 1 then
				print("Hum, I am not certain, as there are multiple things you may refer to :")
				if workfound["anime"] ~= nil then
					sum = sum-1
					if sum == 0 then
						print("And there is an anime named "..workfound["anime"]["title"]..".")
					else
						print("There is an anime named "..workfound["anime"]["title"].." ;")
					end
				end
				if workfound["manga"] ~= nil then
					sum = sum-1
					if sum == 0 then
						print("And there is a manga named "..workfound["manga"]["title"]..".")
					else
						print("There is a manga named "..workfound["manga"]["title"].." ;")
					end
				end
				if characFound ~= nil then
					for title, characs in pairs(characFound["anime"]) do
						for k, charac in pairs(characs) do
							sum = sum-1
							if sum == 0 then
								print("And in the anime "..title..", there is a character named "..charac["firstname"].." "..charac["lastname"]..".")
							else
								print("In the anime "..title..", there is a character named "..charac["firstname"].." "..charac["lastname"].." ;")
							end
						end
					end
					for title, characs in pairs(characFound["manga"]) do
						for k, charac in pairs(characs) do
							sum = sum-1
							if sum == 0 then
								print("And in the manga "..title..", there is a character named "..charac["firstname"].." "..charac["lastname"]..".")
							else
								print("In the manga "..title..", there is a character named "..charac["firstname"].." "..charac["lastname"].." ;")
							end
						end
					end
				end
				print("Which one are you talking about ?")
				local s = io.read():lower()
				if characFound == nil and s:find("anime") then
					dialog_state.hckey = {workfound["anime"]}
					dialog_state.hctypes  = "QTHEME"
					return
				elseif characFound == nil and s:find("manga") then
					dialog_state.hckey = {workfound["manga"]}
					dialog_state.hctypes  = "QTHEME"
					return
				elseif nbcharacters == 1 and #characFound["manga"] == 1 and #characFound["anime"] == 0 and s:find("character") then
					for key, manga in pairs(characFound["manga"]) do
						dialog_state.hckey = {manga[1]}
						dialog_state.hctypes  = "QBEHAVIOUR"
					end
					return
				elseif nbcharacters == 1 and #characFound["manga"] == 0 and #characFound["anime"] == 1 and s:find("character") then
					for key, anime in pairs(characFound["anime"]) do
						dialog_state.hckey = {anime[1]}
						dialog_state.hctypes  = "QBEHAVIOUR"
					end
					return
				elseif workfound["anime"] ~= nil and s:find("anime") ~= nil and s:find("character") == nil and s:find(" from ") == nil then
					dialog_state.hckey = {workfound["anime"]}
					dialog_state.hctypes  = "QTHEME"
					return
				elseif workfound["manga"] ~= nil and s:find("manga") ~= nil and s:find("character") == nil and s:find(" from ") == nil then
					dialog_state.hckey = {workfound["manga"]}
					dialog_state.hctypes  = "QTHEME"
					return
				elseif s:find("character") ~= nil or s:find(" from ") ~= nil then
					local foundwork = ""
					local foundcharac = false
					if s:find("anime") ~=nil then
						worktype = "anime"
					elseif s:find("manga") ~=nil then
						worktype = "manga"
					else 
						print("Sorry, I don't understand which one you want")
						dialog_state.hckey = nil
						dialog_state.hctypes = nil
						return
					end
					--compte le nombre de manga/d'animes trouves
					local count = 0
					for title, characs in pairs(characFound[worktype]) do
						count = count + 1
					end
					for title, characs in pairs(characFound[worktype]) do
						if count == 1 then
							foundwork = title
							break
						elseif s:find(title) ~= nil then
							foundwork = title
							break
						end
					end
					if foundwork =="" then
						print("Sorry, I don't know this "..worktype..".")
						dialog_state.hckey = nil
						dialog_state.hctypes = nil
						return
					end
					if #characFound[worktype][foundwork] == 1 then
						foundcharac = true
						dialog_state.hckey = {characFound[worktype][foundwork][1]}
						dialog_state.hctypes = "QBEHAVIOUR"
						return
					else
						for k, charac in pairs(characFound[worktype][foundwork]) do
							if s:find(charac["firstname"]) and s:find(charac["lastname"]) then
								foundcharac = true
								dialog_state.hckey = {charac}
								dialog_state.hctypes = "QBEHAVIOUR"
								break
							end
						end
						if foundcharac == false then
							for k, charac in pairs(characFound[worktype][foundwork]) do
								if s:find(charac["firstname"]) or s:find(charac["lastname"]) then
									foundcharac = true
									dialog_state.hckey = {charac}
									dialog_state.hctypes = "QBEHAVIOUR"
								end
							end
						end
					end
					if foundcharac == false then
						print("Sorry, I don't know this character")
						dialog_state.hckey = nil
						dialog_state.hctypes = nil
						return
					end
				else
					print("Sorry, I don't know what you are talking about")
					dialog_state.hctypes  = nil
					dialog_state.hckey = nil
					return
				end
			elseif sum == 1 then
				if workfound["anime"] ~= nil then
					dialog_state.hckey = {workfound["anime"]}
					dialog_state.hctypes  = "QTHEME"
					return
				elseif workfound["manga"] ~= nil then
					dialog_state.hckey = {workfound["manga"]}	
					dialog_state.hctypes  = "QTHEME"
					return
				else
					for title, characs in ipairs(characFound["anime"]) do
						for key, charac in ipairs(characs) do
							dialog_state.hckey = {charac}
							dialog_state.hctypes  = "QBEHAVIOUR"
							return
						end
					end
					for title, characs in ipairs(characFound["manga"]) do
						for key, charac in ipairs(characs) do
							dialog_state.hckey = {charac}
							dialog_state.hctypes  = "QBEHAVIOUR"
							return
						end
					end
				end
			else
				print("Sorry, I don't know what you are talking about.")
				dialog_state.hckey = nil
				dialog_state.hctypes  = nil
				return
			end
		elseif havetag(question, "#QDESCRIPTION1")==true then
			if sum > 1 then
				print("Hum, I am not certain, as there are multiple things you may refer to :")
				if characFound ~= nil then
					for title, characs in pairs(characFound["anime"]) do
						for k, charac in pairs(characs) do
							sum = sum-1
							if sum == 0 then
								print("And in the anime "..title..", there is a character named "..charac["firstname"].." "..charac["lastname"]..".")
							else
								print("In the anime "..title..", there is a character named "..charac["firstname"].." "..charac["lastname"].." ;")
							end
						end
					end
					for title, characs in pairs(characFound["manga"]) do
						for k, charac in pairs(characs) do
							sum = sum-1
							if sum == 0 then
								print("And in the manga "..title..", there is a character named "..charac["firstname"].." "..charac["lastname"]..".")
							else
									print("In the manga "..title..", there is a character named "..charac["firstname"].." "..charac["lastname"].." ;")
							end
						end
					end
				end
				print("Which one are you talking about ?")
				local s = io.read():lower()local foundwork = ""
				local foundcharac = false
				if s:find("anime") ~=nil then
					worktype = "anime"
				elseif s:find("manga") ~=nil then
					worktype = "manga"
				else 
					print("Sorry, I don't understand which one you want")
					dialog_state.hckey = nil
					dialog_state.hctypes = nil
					return
				end
				--compte le nombre de manga/d'animes trouves
				local count = 0
				for title, characs in pairs(characFound[worktype]) do
					count = count + 1
				end
				for title, characs in pairs(characFound[worktype]) do
					if count == 1 then
						foundwork = title
						break
					elseif s:find(title) ~= nil then
						foundwork = title
						break
					end
				end
				if foundwork =="" then
					print("Sorry, I don't know this "..worktype..".")
					dialog_state.hckey = nil
					dialog_state.hctypes = nil
					return
				end
				if #characFound[worktype][foundwork] == 1 then
					foundcharac = true
					dialog_state.hckey = {characFound[worktype][foundwork][1]}
					dialog_state.hctypes = "QBEHAVIOUR"
					return
				else
					for k, charac in pairs(characFound[worktype][foundwork]) do
						if s:find(charac["firstname"]) and s:find(charac["lastname"]) then
							foundcharac = true
							dialog_state.hckey = {charac}
							dialog_state.hctypes = "QBEHAVIOUR"
							return
						end
					end
					if foundcharac == false then
						for k, charac in pairs(characFound[worktype][foundwork]) do
							if s:find(charac["firstname"]) or s:find(charac["lastname"]) then
								foundcharac = true
								dialog_state.hckey = {charac}
								dialog_state.hctypes = "QBEHAVIOUR"
								return
							end
						end
					end
				end
				if foundcharac == false then
					print("Sorry, I don't know this character")
					dialog_state.hckey = nil
					dialog_state.hctypes = nil
					return
				end
			elseif sum == 1 then
				for title, characs in pairs(characFound["anime"]) do
					for key, charac in pairs(characs) do
						dialog_state.hckey = {charac}
						dialog_state.hctypes  = "QBEHAVIOUR"
						return
					end
				end
				for key, characs in pairs(characFound["manga"]) do
					for key, charac in pairs(characs) do
						dialog_state.hckey = {charac}
						dialog_state.hctypes  = "QBEHAVIOUR"
						return
					end
				end
			else
				print("Sorry, I don't know what you are talking about.")
				dialog_state.hckey = nil
				dialog_state.hctypes  = nil
			end
		elseif havetag(question, "#QDESCRIPTION2")==true then
			if sum > 1 then
				print("Hum, I am not certain, as there are multiple things you may refer to :")
				if characFound ~= nil then
					for title, characs in pairs(characFound["anime"]) do
						for k, charac in pairs(characs) do
							sum = sum-1
							if sum == 0 then
								print("And in the anime "..title..", there is a character named "..charac["firstname"].." "..charac["lastname"]..".")
							else
								print("In the anime "..title..", there is a character named "..charac["firstname"].." "..charac["lastname"].." ;")
							end
						end
					end
					for title, characs in pairs(characFound["manga"]) do
						for k, charac in pairs(characs) do
							sum = sum-1
							if sum == 0 then
								print("And in the manga "..title..", there is a character named "..charac["firstname"].." "..charac["lastname"]..".")
							else
								print("In the manga "..title..", there is a character named "..charac["firstname"].." "..charac["lastname"].." ;")
							end
						end
					end
				end
				print("Which one are you talking about ?")
				local s = io.read():lower()local foundwork = ""
				local foundcharac = false
				if s:find("anime") ~=nil then
					worktype = "anime"
				elseif s:find("manga") ~=nil then
					worktype = "manga"
				else 
					print("Sorry, I don't understand which one you want")
					dialog_state.hckey = nil
					dialog_state.hctypes = nil
					return
				end
				--compte le nombre de manga/d'animes trouves
				local count = 0
				for title, characs in pairs(characFound[worktype]) do
					count = count + 1
				end
				for title, characs in pairs(characFound[worktype]) do
					if count == 1 then
						foundwork = title
						break
					elseif s:find(title) ~= nil then
						foundwork = title
						break
					end
				end
				if foundwork =="" then
					print("Sorry, I don't know this "..worktype..".")
					dialog_state.hckey = nil
					dialog_state.hctypes = nil
					return
				end
				if #characFound[worktype][foundwork] == 1 then
					foundcharac = true
					dialog_state.hckey = {characFound[worktype][foundwork][1], GetValueInLink(question, "#BEHAVIOUR", "#QDESCRIPTION2")}
					dialog_state.hctypes = "QBEHAVIOUR"
					return
				else
					for k, charac in pairs(characFound[worktype][foundwork]) do
						if s:find(charac["firstname"]) and s:find(charac["lastname"]) then
							foundcharac = true
							dialog_state.hckey = {charac, GetValueInLink(question, "#BEHAVIOUR", "#QDESCRIPTION2")}
							dialog_state.hctypes = "QBEHAVIOUR"
							return
						end
					end
					if foundcharac == false then
						for k, charac in pairs(characFound[worktype][foundwork]) do
							if s:find(charac["firstname"]) or s:find(charac["lastname"]) then
								foundcharac = true
								dialog_state.hckey = {charac, GetValueInLink(question, "#BEHAVIOUR", "#QDESCRIPTION2")}
								dialog_state.hctypes = "QBEHAVIOUR"
								return
							end
						end
					end
				end
				if foundcharac == false then
					print("Sorry, I don't know this character")
					dialog_state.hckey = nil
					dialog_state.types = nil
					return
				end
			elseif sum == 1 then
				for title, characs in pairs(characFound["anime"]) do
					for key, charac in pairs(characs) do
						dialog_state.hckey = {charac, GetValueInLink(question, "#BEHAVIOUR", "#QDESCRIPTION2")}
						dialog_state.hctypes  = "QBEHAVIOUR"
						return
					end
				end
				for title, characs in pairs(characFound["manga"]) do
					for key, charac in pairs(characs) do
						dialog_state.hckey = {charac, GetValueInLink(question, "#BEHAVIOUR", "#QDESCRIPTION2")}
						dialog_state.hctypes  = "QBEHAVIOUR"
						return
					end
				end
			else
				print("Sorry, I don't know what you are talking about.")
				dialog_state.hckey = nil
				dialog_state.hctypes  = nil
				return
			end
		elseif havetag(question, "#QTHEME1")==true then
			sum = 0
			if workfound["anime"] ~= nil then sum = sum+1 end
			if workfound["manga"] ~= nil then sum = sum+1 end
			if sum > 1 then
				print("Hum, I am not certain, as there are multiple things you may refer to :")
				if workfound["anime"] ~= nil then
					sum = sum-1
					if sum == 0 then
						print("And there is an anime named "..workfound["anime"]["title"]..".")
					else
						print("There is an anime named "..workfound["anime"]["title"].." ;")
					end
				end
				if workfound["manga"] ~= nil then
					sum = sum-1
					if sum == 0 then
						print("And there is a manga named "..workfound["manga"]["title"]..".")
					else
						print("There is a manga named "..workfound["manga"]["title"].." ;")
					end
				end
				print("Which one are you talking about ?")
				local s = io.read():lower()
				if s:find("anime") then
					dialog_state.hckey = {workfound["anime"]}
					dialog_state.hctypes  = "QTHEME"
					return
				elseif s:find("manga") then
					dialog_state.hckey = {workfound["manga"]}
					dialog_state.hctypes  = "QTHEME"
					return
				end
			elseif sum == 1 then
				if workfound["anime"] ~= nil then
					dialog_state.hckey = {workfound["anime"]}
					dialog_state.hctypes  = "QTHEME"
					return
				elseif workfound["manga"] ~= nil then
					dialog_state.hckey = {workfound["manga"]}
					dialog_state.hctypes  = "QTHEME"
					return
				end
			else
				print("Sorry, I don't know what you are talking about.")
				dialog_state.hckey = nil
				dialog_state.hctypes  = nil
				return
			end
		elseif havetag(question, "#QTHEME2")==true then
			sum = 0
			if workfound["anime"] ~= nil then sum = sum+1 end
			if workfound["manga"] ~= nil then sum = sum+1 end
			if sum > 1 then
				print("Hum, I am not certain, as there are multiple things you may refer to :")
				if workfound["anime"] ~= nil then
					sum = sum-1
					if sum == 0 then
						print("And there is an anime named "..workfound["anime"]["title"]..".")
					else
						print("There is an anime named "..workfound["anime"]["title"].." ;")
					end
				end
				if workfound["manga"] ~= nil then
					sum = sum-1
					if sum == 0 then
						print("And there is a manga named "..workfound["manga"]["title"]..".")
					else
						print("There is a manga named "..workfound["manga"]["title"].." ;")
					end
				end
				print("Which one are you talking about ?")
				local s = io.read():lower()
				if s:find("anime") then
					dialog_state.hckey = {workfound["anime"], GetValueInLink(question, "#THEME", "#QTHEME2")}
					dialog_state.hctypes  = "QTHEME"
					return
				elseif s:find("manga") then
					dialog_state.hckey = {workfound["manga"], GetValueInLink(question, "#THEME", "#QTHEME2")}
					dialog_state.hctypes  = "QTHEME"
					return
				end
			elseif sum == 1 then
				if workfound["anime"] ~= nil then
					dialog_state.hckey = {workfound["anime"], GetValueInLink(question, "#THEME", "#QTHEME2")}
					dialog_state.hctypes  = "QTHEME"
					return
				elseif workfound["manga"] ~= nil then
					dialog_state.hckey = {workfound["manga"], GetValueInLink(question, "#THEME", "#QTHEME2")}
					dialog_state.hctypes  = "QTHEME"
					return
				end
			else
				print("Sorry, I don't know what you are talking about.")
				dialog_state.hckey = nil
				dialog_state.hctypes  = nil
				return
			end
		else
			return "#UNRECOGNIZED", nil
		end
	end
end

