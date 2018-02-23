-- Création d'un pipeline pour DARK
local main = dark.pipeline()


dofile("functions.lua")
base = dofile("base.lua")
mangaTitles, animeTitles, titles = listTitles(base)
characterNames, characterFirstNames, characterLastNames = listCharacterNames(base["anime"], {},{},{})
characterNames, characterFirstNames, characterLastNames = listCharacterNames(base["manga"], characterNames,characterFirstNames,characterLastNames)
adjList = listAdjectives(dofile("adjectives.lua"))


-- Création d'un lexique ou chargement d'un lexique existant
main:lexicon("#CHARACTERFIRSTNAME", characterFirstNames)
main:lexicon("#CHARACTERLASTNAME", characterLastNames)
main:lexicon("#CHIFFRES", {"un","deux","trois","quatre","cinq","six","sept","huit","neuf","dix"})
main:lexicon("#ISVERB", {"is","seem","seems","look","looks","sound","sounds","appear","appears", "was"})
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
	[#DESCRIPTION
		(#CHARACTERNAME #ISVERB ('to' 'be')? ('really'|'very'|'extremely'|('kind' 'of')|'kinda'|('a' 'little'? 'bit')|'so'|'soo'|'sooo'|'soooo')? #BEHAVIOUR ((','|'and') #BEHAVIOUR)*)
	]
]])

-- <( ('s' | 'is' | 'was') .*?) #THEME >('show' | 'anime' | 'manga' | 'series' | 'program')
--[[
 <(.*? (#TITLE | 'story' | 'anime' | 'manga' | 'show' | 'work' | 'series' | 'program' | 'it') .*?
			(('s' | 'is') 'about') | ('deals' 'with')) .*?
			#THEME (',' #THEME)*?
]]--

--[[
	.*? (#TITLE | 'story' | 'anime' | 'manga' | 'show' | 'work' | 'series' | 'program' | 'it') .*?
	((('s' | 'is') 'about') | ('deals' 'with'))
	[#WORKTHEME
			 #THEME 
	]
--]]

--using look-arounds because it totally gives better results

main:pattern([[
	[#WORKTHEME
		<(.*? (#TITLE | 'story' | 'anime' | 'manga' | 'show' | 'work' | 'it') .*?
		((('s' | 'is') 'about') | ('deals' 'with')) .*?)
		#THEME (',' 'and'? #THEME)*?
	]
]])




main:pattern([[
	[#WORKTHEME
			<(('s' | 'is' | 'was') .*?)
			#THEME
	]
	('show' | 'anime' | 'manga' | 'series' | 'program')
	
]])




main:pattern("[#DUREE ( #CHIFFRES | /%d+/ ) ( /mois%p?/ | /jours%p?/ ) ]")

-- Sélection des étiquettes voulues, attribution d'une couleur (black,
-- blue, cyan, green, magenta, red, white, yellow) pour affichage sur
-- le terminal ou valeur "true" si redirection vers un fichier de
-- sortie (obligatoire pour éviter de copier les caractères de
-- contrôle)

local tags = {
	["#CHARACTERLASTNAME"] = "blue",
	["#CHARACTERFIRSTNAME"] = "blue",
	["#CHARACTERNAME"] = "cyan",
	["#DUREE"] = "magenta",
	["#BEHAVIOUR"] = "red",
	["#DESCRIPTION"] = "green",
	["#WORKTHEME"] = "yellow",
}


-- Traitement des lignes du fichier
--[[local sentence = "In the first season finale, C.C. triggers a trap set by V.V., causing herself and Lelouch to be submerged in a shock image sequence similar to the one she used on Suzaku. Through this, Lelouch sees memories of her past, including repeated deaths. sensitive"
for line in sentence.lines() do
        -- Toutes les étiquettes
	--print(main(line))
        -- Uniquement les étiquettes voulues
print(main(sentence):tostring(tags))
end--]]



local function havetag(seq, tag)
	return #seq[tag] ~= 0
end

local function tagstr(seq, tag, lim_debut, lim_fin)
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

local function GetValueInLink(seq, entity, link)
	for i, pos in ipairs(seq[link]) do
		local res = tagstr(seq, entity, pos[1], pos[2])
		if res then
			return res
		end
	end
	return nil
end


local function process(sen)
	sen = sen:gsub("([^A-Z])(%p)([^A-Z])", "%1 %2 %3")            --%0 correspond à toute la capture
	sen = sen:gsub("([^A-Z])(%p)$", "%1 %2")
	local seq = dark.sequence(sen) -- ça découpe sur les espaces
	return main(seq)
	--print(seq:tostring(tags))
end

-- returns a table of dark.sequence
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
	--for sen in line:gmatch("(.-[a-zA-Z][.?!]) [A-Z]") do
	for key, sen in pairs(sents) do
		p = process(sen)
		output[#output+1] = p
	end
	return output
end



local function havetag(seq, tag)
	return #seq[tag] ~= 0
end


local function tagstr(seq, tag, lim_debut, lim_fin)
	local results = {}
	lim_debut = lim_debut or 1
	lim_fin   = lim_fin   or #seq
	if not havetag(seq, tag) then
		return {""}
	end
	local list = seq[tag]
	for i, position in ipairs(list) do
		local tokens = {}
		local debut, fin = position[1], position[2]
		if debut >= lim_debut and fin <= lim_fin then
			for i = debut, fin do
				tokens[#tokens + 1] = seq[i].token
			end
		end
		if #tokens ~= 0 then
			results[#results+1] = table.concat(tokens, " ")
		end
	end
	if #results == 0 then
		return {""}
	end
	return results
end

local function GetValueInLink(seq, entity, link)
	results = {}
	for i, pos in ipairs(seq[link]) do
		local res = tagstr(seq, entity, pos[1], pos[2])
		--print("TESTA : "..serialize(res))
		if res then
			results[#results+1] = res
		end
	end
	if #results == 0 then
		return nil
	end
	return results
end

-- un champ personnage de la base
--[[local getCharacBehaviours(character)
	
end]]--

--Pour afficher le corpus
--[[for f in os.dir("sentences") do
	for line in io.lines("sentences/"..f) do
		--print(line)
		if line ~= "" then
			splitsen(line)
		end
	end
end]]--


function getAnalyzedBase(base)
	animeOut={}
	for keya, anime in ipairs(base) do
		animeOut[keya] = {}
		animeOut[keya]["title"] = anime["title"]
		animeOut[keya]["nbreviews"] = #anime["reviews"]
		animeOut[keya]["characters"] = anime["characters"]
		for keyb, charac in ipairs(animeOut[keya]["characters"]) do
			charac["behaviours"] = {}
		end
		animeOut[keya]["themes"] = {}
		for key,review in ipairs(anime["reviews"]) do
			revThemes = {}
			if review["text"] ~= "" then
				tablesen = splitsen(review["text"])
				for key, sen in ipairs(tablesen) do 
					for key, t in ipairs(sen:tag2str("#WORKTHEME")) do
						if revThemes[t] == nil then
							-- one "helpful" click counts as 1/10th of a review
								revThemes[t] = 1+0.1*(review["helpful"])
							--end
						else
							-- helpful bonus is only applied once
							revThemes[t] = revThemes[t] + 1
						end
						
					end
					
					if havetag(sen, "#DESCRIPTION") then
						firstnames = {}
						for key, value in pairs(GetValueInLink(sen, "#CHARACTERFIRSTNAME", "#DESCRIPTION")) do
							firstnames[#firstnames+1] = value[1]
						end
						lastnames = {}
						for key, value in pairs(GetValueInLink(sen, "#CHARACTERLASTNAME", "#DESCRIPTION")) do
							lastnames[#lastnames+1] = value[1]
						end
						behavs = {}
						for key, value in pairs(GetValueInLink(sen, "#BEHAVIOUR", "#DESCRIPTION")) do
							behavs[#behavs+1] = value
						end
						for i = 1, #behavs do
							for keyb, charac in pairs(animeOut[keya]["characters"]) do
								if firstnames[i] == charac["firstname"] or lastnames[i] == charac["lastname"] then
									for key, behav in pairs(behavs[i]) do
										local found = false
										for key, other in pairs(charac["behaviours"]) do
											if other == behav then
												found = true
												break
											end
										end
										if found == false then
											charac["behaviours"][#charac["behaviours"]+1] = behav
										end
									end
								end
							end
						end
					end
				end
			end
			
			for keyt, t in pairs(revThemes) do
				if animeOut[keya]["themes"][keyt] == nil then
					animeOut[keya]["themes"][keyt] = t
				else
					animeOut[keya]["themes"][keyt] = animeOut[keya]["themes"][keyt] + t
				end
			end
		end
		
		--[[
		for key, charac in pairs(animeOut[keya]["characters"]) do
			if #charac["behaviours"] ~= 0 then
				print(charac["firstname"].." : "..serialize(charac["behaviours"]))
			end
			--print("TEST : "..serialize(charac))--..serialize(charac["behaviours"]))
		end
		]]--
		
		print(keya .. "/" .. #base)
		--if keya > 1 then break end
	end
	return animeOut
end

outbase={}
print("Parsing animes")
outbase["anime"] = getAnalyzedBase(base["anime"])
print("Parsing mangas")
outbase["manga"] = getAnalyzedBase(base["manga"])


-- consolidation : add scores of synonyms

-- this takes a list of themes (list), the reference term (ref),
-- and a list of synonyms of the ref (synonyms)
local function consolidate(list, ref, synonyms)
	for key, t in pairs(list) do
		for _, v in pairs(synonyms) do -- who needs tools when you can just bash nails in with a rock ?
			-- it's not an original theme, but a synonym, so we fold it
			if key == v then
				if list[ref] == nil then list[ref] = 0 end
				list[ref] = list[ref] + t
				list[key] = nil
			end
		end
	end
	return list
end

-- yeah I know it's not pretty
local function overConsolidate(base)
	for keya, a in ipairs(base) do
		a["themes"] = consolidate(a["themes"], "psychology", {"psychological"})
		a["themes"] = consolidate(a["themes"], "pirates", {"pirate"})
		a["themes"] = consolidate(a["themes"], "ninjas", {"ninja"})
		a["themes"] = consolidate(a["themes"], "zombies", {"zombie", "zombi", "zombis"})
		a["themes"] = consolidate(a["themes"], "robots", {"robot"})
		a["themes"] = consolidate(a["themes"], "mechas", {"mecha","mechs","mech"})
		a["themes"] = consolidate(a["themes"], "kaijus", {"kaiju"})
		a["themes"] = consolidate(a["themes"], "magical girls", {"magicka girls", "magic girls"})
		a["themes"] = consolidate(a["themes"], "post-apocalypse", {"post-apocalyptic", "post-apo", "post apocalypse","post apocalyptic", "post apo"})
		a["themes"] = consolidate(a["themes"], "cowboys", {"cowboy", "western", "old west", "wild west"})
		a["themes"] = consolidate(a["themes"], "vikings", {"viking"})
		a["themes"] = consolidate(a["themes"], "history", {"historical"})
		a["themes"] = consolidate(a["themes"], "super heroes", {"superhero", "super hero", "super-hero", "superheroes", "super-heroes"})
		a["themes"] = consolidate(a["themes"], "video games", {"videogames", "video games", "vidya", "videogaming", "video-gaming", "video gaming"})
		
		a["themes"] = consolidate(a["themes"], "romance", {"romantism", "romantic"}) -- I just became my worst enemy by conflating romantism and romance
		a["themes"] = consolidate(a["themes"], "serial killers", {"serial killer"})
		a["themes"] = consolidate(a["themes"], "dilemmas", {"dilemma"})
		a["themes"] = consolidate(a["themes"], "serious issues", {"serious problems", "serious questions"})
		a["themes"] = consolidate(a["themes"], "important questions", {"serious problems", "serious issues"}) --basically cheating
		
		a["themes"] = consolidate(a["themes"], "good versus evil", {"good vs evil", "good versus bad", "good vs bad"})
		a["themes"] = consolidate(a["themes"], "man versus nature", {"man vs nature", "man against nature"})
		base[keya] = a
	end
	return base
end

outbase["anime"] = overConsolidate(outbase["anime"])
outbase["manga"] = overConsolidate(outbase["manga"])


--print(serialize(animeOut))
file = io.open("work-base.lua", "w")
io.output(file)
io.write(serialize(outbase))
io.close(file)



--function seekDescription(character, work, type)
	
	
--end
