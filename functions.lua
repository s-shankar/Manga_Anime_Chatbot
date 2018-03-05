function listCharacterNames(table, characterNames, characterFirstnames, characterLastnames)
	for key, work in pairs(table) do
		for key2, character in pairs(work["characters"]) do
			local found = false
			for key3, autres in pairs(characterNames) do
				if autres["firstname"] == character["firstname"]:lower() and autres["lastname"] == character["lastname"]:lower() then
					found = true
					break
				end
			end
			if found==false then
				characterNames[#characterNames+1] = {["firstname"] = character["firstname"]:lower(), ["lastname"] = character["lastname"]:lower()}
			end
			found = false
			for key3, autres in pairs(characterFirstnames) do
				if autres == character["firstname"]:lower() then
					found = true
					break
				end
			end
			if found==false then
				characterFirstnames[#characterFirstnames+1] = character["firstname"]:lower()
			end
			found = false
			for key3, autres in pairs(characterLastnames) do
				if autres == character["lastname"]:lower() then
					found = true
					break
				end
			end
			if found==false then
				characterLastnames[#characterLastnames+1] = character["lastname"]:lower()
			end
		end
	end
	return characterNames, characterFirstnames, characterLastnames
end

function listTitles(base)
	mangaTitles = {}
	animeTitles = {}
	titles = {}
	for key, anime in pairs(base["anime"]) do
		animeTitles[#animeTitles+1] = anime["title"]:lower()
		local found = false
		for key2, other in pairs(titles) do
			if other == anime["title"]:lower() then
				found = true
				break
			end
		end
		if found == false then
			titles[#titles+1] = anime['title']:lower()
		end
	end

	for key, manga in pairs(base["manga"]) do
		mangaTitles[#mangaTitles+1] = manga["title"]:lower()
		found = false
		for key2, other in pairs(titles) do
			if other == manga["title"]:lower() then
				found = true
				break
			end
		end
		if found == false then
			titles[#titles+1] = manga['title']:lower()
		end
	end
	return mangaTitles, animeTitles, titles
end

function listAdjectives(adjectives)
	adjList = {}
	for key, groups in pairs(adjectives) do
		for key2, adj in pairs(groups) do
			adjList[#adjList+1] = adj
		end
	end
	return adjList
end

-- Returns the Levenshtein distance between the two given strings
function levenshtein(str1, str2)
	local len1 = string.len(str1)
	local len2 = string.len(str2)
	local matrix = {}
	local cost = 0

        -- quick cut-offs to save time
	if (len1 == 0) then
		return len2
	elseif (len2 == 0) then
		return len1
	elseif (str1 == str2) then
		return 0
	end

        -- initialise the base matrix values
	for i = 0, len1, 1 do
		matrix[i] = {}
		matrix[i][0] = i
	end
	for j = 0, len2, 1 do
		matrix[0][j] = j
	end

        -- actual Levenshtein algorithm
	for i = 1, len1, 1 do
		for j = 1, len2, 1 do
			if (str1:byte(i) == str2:byte(j)) then
				cost = 0
			else
				cost = 1
			end

			matrix[i][j] = math.min(matrix[i-1][j] + 1, matrix[i][j-1] + 1, matrix[i-1][j-1] + cost)
		end
	end

        -- return the last value - this is the Levenshtein distance
	return matrix[len1][len2]
end

--print("TEST : "..levenshtein("Naruto", "Naruta"))

--Prend un nom et recherche si c'est une anime, un manga ou un nom de personnage.
function getContext(name)
	local distancemax = 1
	local animefound = ""
	local mangafound = ""
	local charactersfound = {}
	for key, anime in pairs(base["anime"]) do
		if levenshtein(name, anime["title"])<distancemax then
			animefound = anime
		end
		for key, charac in pairs(anime[characters]) do
			if levenshtein(charac["firstname"].." "..charac["lastname"], name)<distancemax or levenshtein(charac["lastname"].." "..charac["firstname"],name)<distancemax or levenshtein(charac["firstname"],name)<distancemas or levenshtein(charac["lastname"],name)<distancemax then
				charactersfound[#charactersfound+1] = {["anime"] = anime, ["character"] = charac}
			end
		end
	end
	for key, manga in pairs(base["manga"]) do
		if(name == manga["title"]) then
			mangafound = manga
		end
		for key, charac in pairs(manga[characters]) do
			if levenshtein(charac["firstname"].." "..charac["lastname"], name)<distancemax or levenshtein(charac["lastname"].." "..charac["firstname"],name)<distancemax or levenshtein(charac["firstname"],name)<distancemas or levenshtein(charac["lastname"],name)<distancemax then
				charactersfound[#charactersfound+1] = {["manga"] = manga, ["character"] = charac}
			end
		end
	end
	return animefound, mangafound, characterfound
end


function findCharacterName( firstname, lastname, listChara, ... )
	local distancemax = 1
	local listName = {}
	local name = ""
	local args = {...}
	local animeTitle = args[1] or nil
	if(firstname == nil or lastname == nil) then
		name = firstname or lastname
	else
		name = firstname..' '..lastname
	end

	if animeTitle ~= nil then
		animeFound = getAnimeOrMangaBase(animeTitle,base)
		if animeFound ~= nil then
			for k,chara in pairs(animeFound) do
				if levenshtein(chara["firstname"]..' '..chara["lastname"],name)<=distancemax or lastname ~= nil and levenshtein(chara["firstname"]..' '..chara["lastname"],lastname..' '..firstname)<distancemax then
					listName[#listName+1]= {firstname=chara["firstname"],lastname= chara["lastname"]}
				end
			end
		end
	else
		for key, chara in pairs(listChara) do
		--	print("\t",firstname,lastname,name)
			if levenshtein(chara["firstname"]..' '..chara["lastname"],name)<3 or lastname ~= nil and levenshtein(chara["firstname"]..' '..chara["lastname"],lastname..' '..firstname)<3 then
				listName[#listName+1]= {firstname=chara["firstname"],lastname= chara["lastname"]}
			end
		end
	end
	return listName
end


--Retourne le behaviour d'un personnage en se basant sur son nom et le titre de son anime.
function getBehaviours(firstname,lastname, title, type)
	if type == "anime" then
		for key, anime in pairs(base["anime"]) do
			if anime["title"] == title then
				for key, charac in pairs(anime["characters"]) do
					if charac["firstname"] == firstname and charac["lastname"] == lastname then
						return charac["behaviours"]
					end
				end
			end
		end
	end
	if type == "manga" then
		for key, manga in pairs(base["manga"]) do
			if manga["title"] == title then
				for key, charac in pairs(manga["characters"]) do
					if charac["firstname"] == firstname and charac["lastname"] == lastname then
						return charac["behaviours"]
					end
				end
			end
		end
	end
end

function findCharacterInWorks(name)

	local count = 0
	found = {}
	found["anime"] = {}
	found["manga"] = {}
	for k,anime in pairs(base["anime"]) do
		for k, charac in pairs(anime["characters"]) do
			if charac["firstname"] == name or charac["lastname"] == name or charac["lastname"].." "..charac["firstname"] == name or charac["firstname"].." "..charac["lastname"] == name then
				count = count + 1
				if(found["anime"][anime["title"]] == nil) then
					found["anime"][anime["title"]] = {}
				end
				found["anime"][anime["title"]][#found["anime"][anime["title"]]+1] = charac
			end
		end
	end
	for k,manga in pairs(base["manga"]) do
		for k, charac in pairs(manga["characters"]) do
			if charac["firstname"] == name or charac["lastname"] == name or charac["lastname"].." "..charac["firstname"] == name or charac["firstname"].." "..charac["lastname"] == name then
				count = count + 1
				if(found["manga"][manga["title"]] == nil) then
					found["manga"][manga["title"]] = {}
				end
				found["manga"][manga["title"]][#found["manga"][manga["title"]]+1] = charac
			end
		end
	end
	return found, count
end

function findWorkFromTitle(title)
	
	found = {}
	for k,anime in pairs(base["anime"]) do
		if title == anime["title"] then
			found["anime"] = anime
			break
		end
	end
	for k, manga in pairs(base["manga"]) do
		if title == manga["title"] then
			found["manga"] = manga
			break
		end
	end
	return found
end

--Retourne le theme d'un anime ou d'un manga en se basant sur le nom.
function getTheme(title_name, type)
	minimalIndice = 0.025
	if type == "anime" then
		for key, anime in pairs(base["anime"]) do
			if anime["title"] == title_name then
				themes = {}
				for theme, indice in pairs(anime["themes"]) do
					if indice/anime["nbreviews"] > minimalIndice then
						themes[#themes+1] = theme
					end
				end
			return themes
			end
		end
	end
	
	if type == "manga" then
		for key, manga in pairs(base["manga"]) do
			if manga["title"] == title_name then
				themes = {}
				for theme, indice in pairs(manga["themes"]) do
					if indice/manga["nbreviews"] > minimalIndice then
						themes[#themes+1] = theme
					end
				end
			return themes
			end
		end
	end
	return nil
end

--retourne un anime ou un manga en se basant sur son titre
function getAnimeOrMangaBase( title, base , type)
	-- body
	if type == "manga" then
		for k,anime in pairs(base["anime"]) do
			if string.find(anime["title"],title) then
				return anime
			end
		end
	end
	if type == "anime" then
		for k, manga in pairs(base["manga"]) do
			if string.find(manga["title"],title) then
				return manga
			end
		end
	end
	return nil
end

function charaFromWhichAnimeOrManga( firstname, lastname )
	-- body
	for k,anime in pairs(base["anime"]) do
		for k2,chara in pairs(anime["characters"]) do
			if string.find(chara["firstname"]..' '..chara["lastname"],firstname..' '..lastname) or string.find(chara["firstname"]..' '..chara["lastname"],lastname..' '..firstname) then
				return anime["title"]
			end
		end
	end
	for k,manga in pairs(base["manga"]) do
		for k2,chara in pairs(manga["characters"]) do
			if string.find(chara["firstname"]..' '..chara["lastname"],firstname..' '..lastname) or string.find(chara["firstname"]..' '..chara["lastname"],lastname..' '..firstname) then
				return manga["title"]
			end
		end
	end
	return nil
end


-- takes a key/number dictionary as input (dic)
-- returns a list of the (number) keys with the largest values, in order
function getLargestKeys(dic, number)
	-- sorting ? eh
	output = {}
	opdic = {}
	for k,i in pairs(dic) do
		opdic[k] = i
	end

	while #output < number do
		largestK = ""
		largestV = -100
		dicIsEmpty = true
		for k,i in pairs(opdic) do
			if i > largestV then
				largestK = k
			end
			dicIsEmpty = false
		end
		if dicIsEmpty then break end
		output[#output+1] = largestK
		opdic[largestK] = nil
	end
	return output
end





