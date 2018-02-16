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
