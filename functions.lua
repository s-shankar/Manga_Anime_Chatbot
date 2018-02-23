function listCharacterNames(table, characterNames, characterFirstnames, characterLastnames)
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
	titles = {}
	for key, anime in pairs(base["anime"]) do
		animeTitles[#animeTitles+1] = anime["title"]
		local found = false
		for key2, other in pairs(titles) do
			if other == anime["title"] then
				found = true
				break
			end
		end
		if found == false then
			titles[#titles+1] = anime['title']
		end
	end

	for key, manga in pairs(base["manga"]) do
		mangaTitles[#mangaTitles+1] = manga["title"]
		found = false
		for key2, other in pairs(titles) do
			if other == manga["title"] then
				found = true
				break
			end
		end
		if found == false then
			titles[#titles+1] = manga['title']
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


function getContext(name)
	local animefound = ""
	local mangafound = ""
	local charactersfound = {}
	for key, anime in pairs(base["anime"]) do
		if(name == anime["title"]) then
			animefound = name
		end
		for key, charac in pairs(anime[characters]) do
			if charac["firstname"].." "..charac["lastname"] == name or charac["lastname"].." "..charac["firstname"] == name or charac["firstname"] == name or charac["lastname"] == name then
				charactersfound[#charactersfound+1] = {["anime"] = anime["title"], ["name"] = name}
			end
		end
	end
	for key, manga in pairs(base["manga"]) do
		if(name == manga["title"]) then
			mangafound = name
		end
		for key, charac in pairs(manga[characters]) do
			if charac["firstname"].." "..charac["lastname"] == name or charac["lastname"].." "..charac["firstname"] == name or charac["firstname"] == name or charac["lastname"] == name then
				charactersfound[#charactersfound+1] = {["manga"] = manga["title"], ["name"] = name}
			end
		end
	end

end

function findCharacterName( firstname, lastname, listChara, ... )
	local distancemax = 3
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

function getTheme(title_name, type)
	if type == "anime" then
		for key, anime in pairs(base["anime"]) do
			if anime["title"] == title_name then
				themes = {}
				for theme, indice in pairs(anime["themes"]) do
					if indice > 0.025 then
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
					if indice > 0.025 then
						themes[#themes+1] = theme
					end
				end
			return themes
			end
		end
	end
end


function getAnimeOrMangaBase( title, base )
	-- body
	for k,anime in pairs(base["anime"]) do
		print(title)
		if string.find(anime["title"],title) then
			return anime
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
