-- Création d'un pipeline pour DARK
local main = dark.pipeline()


dofile("listFunctions.lua")
base = dofile("base.lua")
mangaTitles, animeTitles, titles = listTitles(base)
characterNames, characterFirstNames, characterLastNames = listCharacterNames(base["anime"], {},{},{})
characterNames, characterFirstNames, characterLastNames = listCharacterNames(base["manga"], characterNames,characterFirstNames,characterLastNames)
adjList = listAdjectives(dofile("adjectives.lua"))


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
	[#DESCRIPTION
		(#CHARACTERNAME 'is' 'very'? #BEHAVIOUR (',' #BEHAVIOUR)* ('and' #BEHAVIOUR)?)
	]
]])

main:pattern([[
	[#WORKTHEME
		<(.*? (#TITLE | 'story' | 'anime' | 'manga' | 'show' | 'work' | 'it') .*? ((('s' | 'is') 'about') | ('deals' 'with')) .*?)
		#THEME 
		
	]
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
	sen = sen:gsub("^[A-Z]%p^[A-Z]", " %0 ")            --%0 correspond à toute la capture
	local seq = dark.sequence(sen) -- ça découpe sur les espaces
	main(seq)
	--print(seq:tostring(tags))
end

local function splitsen(line)
	for sen in line:gmatch("(.-[a-z][.?!])") do
		process(sen)
	end
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


for key, anime in ipairs(base["anime"]) do
	for key,review in ipairs(anime["reviews"]) do
		if review["text"] ~= "" then
			splitsen(review["text"])
		end	
	end
end


--function seekDescription(character, work, type)
	
	
--end
