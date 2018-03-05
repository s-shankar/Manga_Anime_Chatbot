dark = require("dark")

--[[for f in os.dir("anime/perso") do
	name = f
	l = dofile("anime/perso/"..f)
	--print(l['id'])
	name = name:gsub("perso_","")
	--print(name)
	r = dofile(""..name)
	print(r["title"])

	r["id"] = l["id"]
	r["title_alternative"] = l["title_alternative"]
	for i,v in ipairs(r["characters"]) do
		print(l["characters"][i]["firstname"])
		v["nicknames"] = l["characters"][i]["nicknames"]
		v["nicknames"] = l["characters"][i]["description"]
	end
	file = io.open(r, "w")
	io.output(file)
	io.write("return")
	io.write(serialize(r))
	io.close(file)
end]]--


for f in os.dir("manga/perso") do
	name = f
	l = dofile("manga/perso/"..f)
	name = name:gsub("perso_","")
	r = dofile(""..name)
	print(r["title"])

	r["id"] = l["id"]
	r["title_alternative"] = l["title_alternative"]
	for i,v in ipairs(r["characters"]) do
		v["nicknames"] = l["characters"][i]["nicknames"]
		v["description"] = l["characters"][i]["description"]
	end
	file = io.open(name, "w")
	io.output(file)
	io.write("return")
	io.write(serialize(r))
io.close(file)
end