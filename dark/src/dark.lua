--[[
--      DARK -- Data Annotation using Rules and Knowledge
--
-- Copyright (c) 2014  CNRS
-- All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:
--     * Redistributions of source code must retain the above copyright
--       notice, this list of conditions and the following disclaimer.
--     * Redistributions in binary form must reproduce the above copyright
--       notice, this list of conditions and the following disclaimer in the
--       documentation and/or other materials provided with the distribution.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
-- IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
-- ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
-- LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
-- CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
-- SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
-- CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
-- POSSIBILITY OF SUCH DAMAGE.
--]]

dark = require("dark")
type = dark.type

--[[----------------------------------------------------------------------------
--  Toolbox
--]]----------------------------------------------------------------------------

local function checktype(val, type, lvl)
	lvl = lvl or 0
	if dark.type(val) ~= type then
		error(type.." expected (got "..dark.type(val)..")", lvl + 1)
	end
end

-- fileexists:
--   Return true iff the the given file exists and can be read.
function os.fileexists(name)
	local file = io.open(name)
	if file then
		file:close()
		return true
	end
	return false
end

-- serialize:
--   Serialize a Lua object to a readable string representation. It support nil,
--   booleans, numbers, strings, and tables. Tables can have boolean, numbers,
--   and strings key and any serializable value as long as there is no cycles in
--   the non-oriented graph.
function serialize(obj, lvl, ccl)
	local fbd = {
		["and"]      = true, ["break"]    = true, ["do"]       = true,
		["else"]     = true, ["elseif"]   = true, ["end"]      = true,
		["false"]    = true, ["for"]      = true, ["function"] = true,
		["goto"]     = true, ["if"]       = true, ["in"]       = true,
		["local"]    = true, ["nil"]      = true, ["not"]      = true,
		["or"]       = true, ["repeat"]   = true, ["return"]   = true,
		["then"]     = true, ["true"]     = true, ["until"]    = true,
		["while"]    = true,
	}
	lvl, ccl = lvl or 1, ccl or {}
	if type(obj) == "nil" then
		return "nil"
	elseif type(obj) == "boolean" or type(obj) == "number" then
		return tostring(obj)
	elseif type(obj) == "string" then
		return ("%q"):format(obj)
	end
	if type(obj) ~= "table" then
		error(type(obj).." are not serializable")
	elseif ccl[obj] then
		error("table with cycles are not serializable")
	end
	ccl[obj] = true
	local res, pre = {"{\n"}, ("  "):rep(lvl)
	for key, val in pairs(obj) do
		if type(key) == "boolean" or type(key) == "number" then
			key = "["..key.."]"
		elseif type(key) == "string" then
			if key:match("%W") or fbd[key] then
				key = ("[%q]"):format(key)
			end
		else
			error(type(obj).." keys are not supported")
		end
		val = serialize(val, lvl + 1)
		res[#res + 1] = pre..key.." = "..val..",\n"
	end
	res[#res + 1] = ("  "):rep(lvl - 1).."}"
	return table.concat(res)
end

--[[----------------------------------------------------------------------------
--  Sequence object
--]]----------------------------------------------------------------------------

-- dump:
--   Low level dumping method for sequence object only intendeed for debugging,
--   not for production use. Output directly to stderr.
dark.method("sequence").dump = function(seq)
	checktype(seq, "sequence")
	for i = 1, #seq do
		local tok = seq[i]
		io.stderr:write(("[%2d] %-10s {"):format(i, tok.token))
		for _, tag in ipairs(tok) do
			io.stderr:write(" ", tag.name, ":", tag.length)
		end
		io.stderr:write(" }\n")
	end
end

-- foreach:
--   Call the given function on each tokens of the sequence and add its return
--   values as tags to the token.
dark.method("sequence").foreach = function(seq, func)
	checktype(seq,  "sequence")
	checktype(func, "function")
	for pos = 1, #seq do
		local res = {func(seq[pos].token)}
		for idx, tag in ipairs(res) do
			seq:add(tag, pos)
		end
	end
end

-- iter:
--   Return an iterator over the sequence who return in sequence the index, 
--   token and associated list of starting tags.
dark.method("sequence").iter = function(seq)
	checktype(seq, "sequence")
	local i = 0
	return function()
		i = i + 1
		if i > #seq then
			return
		end
		return i, seq[i].token, seq[i]
	end
end

-- tostring:
--   Lua side implementation of the tostring meta-method. There is some magic on
--   the C side to make this work. This make an XML string from a sequence so it
--   can be visualized more cleanly.
--   The set parameter is optional and useable only if the function is called
--   directly. It is a table of the tag to be printed, all tags who are not a
--   key in this table are ignored. The associated value may be a color name who
--   is used to make output pretty if send to a terminal.
local color = {black = 0, red     = 1, green = 2, yellow = 3,
               blue  = 4, magenta = 5, cyan  = 6, white  = 7}
dark.method("sequence").tostring = function(seq, set)
	            checktype(seq, "sequence", 2)
	if set then checktype(set, "table",    2) end
	local res = {}
	for idx = 1, #seq do
		res[idx] = seq[idx].token
	end
	for len = 1, #seq do
	for pos = 1, #seq - len + 1 do
		local trg = pos + len - 1
		for _, tag in ipairs(seq[pos]) do
			local f = tag.name
			local n = f:match("#(.+)")
			if tag.length == len and (not set or set[f]) then
				local p, s = "", ""
				if set and color[set[f]] then
					p = "\027[1;3"..color[set[f]].."m"
					s = "\027[0m"
				end
				res[pos] = p.."<"..n..">"..s..res[pos]
				res[trg] = res[trg]..p.."</"..n..">"..s
			end
		end
	end
	end
	return table.concat(res, " ")
end

dark.method("sequence").tag2str = function(seq, ...)
	local function sub(seq, sb, se, tags, res)
		if #tags == 1 then
			for idx, pos in ipairs(seq[tags[1]]) do
				local b, e, s = pos[1], pos[2], {}
				if sb <= b and e <= se then
					for i = b, e do
						s[#s + 1] = seq[i].token
					end
					res[#res + 1] = table.concat(s, " ")
				end
			end
			return res
		end
		local tag = tags[1]
		table.remove(tags, 1)
		for idx, pos in ipairs(seq[tag]) do
			local b, e = pos[1], pos[2]
			if sb <= b and e <= se then
				sub(seq, b, e, tags, res)
			end
		end
		table.insert(tags, 1, tag)
		return res
	end
	checktype(seq, "sequence", 2)
	local tags = {...}
	if #tags == 0 then
		return {}
	end
	return sub(seq, 1, #seq, tags, {})
end


--[[----------------------------------------------------------------------------
--  Maxent models
--]]----------------------------------------------------------------------------

-- model:
--   This function implement the high-level interface for Maxent models. It take
--   care of detecting if the model already exist or if it should be trained and
--   load training data as needed for the low-level function.
function dark.model(name)
	checktype(name, "string")
	-- Check if the model file already exist, if it is the case, we just
	-- load and return it.
	if os.fileexists(name..".mdl") then
		return dark.maxent(name..".mdl")
	elseif not os.fileexists(name..".dat") then
		error("neither model or data for "..name.." exists", 2)
	end
	-- If the model should be trained, the data are loaded, transformed in
	-- sequences, and tagged appropriately. This also take care or building
	-- the list of tags.
	local cnt, dat, lst = 0, {}, {}
	for line in io.lines(name..".dat") do
		local wrd, lbl = {}, {}
		for w, l in line:gmatch("(%S+)|(#[^|%s]+)") do
			wrd[#wrd + 1], lbl[#lbl + 1] = w, l
		end
		local seq = dark.sequence(wrd)
		for i, l in ipairs(lbl) do
			lst[l] = true
			seq:add(l, i)
		end
		dat[#dat + 1] = seq
	end
	local lbl = {}
	for tag in pairs(lst) do
		lbl[#lbl + 1] = tag
	end
	-- And finally, the model is trained and written in the model file
	-- before being returned.
	local mdl = dark.maxent(lbl, dat)
	mdl:write(name..".mdl")
	return mdl
end

--[[----------------------------------------------------------------------------
--  Lexicon
--]]----------------------------------------------------------------------------

-- lexicon:
--   Return a function who apply a lexicon on a sequence, adding the given tag
--   to each word matching an element of the lexicon. This support multi-token
--   entry. The list can be given either as a table or a file.
function dark.lexicon(tag, list)
	-- Frist check that arguments are valid and if a file is provided
	-- instead of a table, load its contents.
	if type(tag) ~= "string" or not tag:match("^%#[%w%=%-]+$") then
		error("missing or invalid tag name", 2)
	end
	if type(list) == "string" then
		local tmp = {}
		for line in io.lines(list) do
			tmp[#tmp + 1] = line
		end
		list = tmp
	elseif type(list) ~= "table" then
		error("invalid argument to lexicon", 2)
	end
	-- Convert each items in the list to a sequence of properly escaped
	-- tokens suitable to build a pattern.
	local pat = {}
	for id, seq in ipairs(list) do
		seq = seq:match("^%s*(.-)%s*$")
		if seq ~= "" then
			seq = seq:gsub('"', '%"'):gsub('%s+', '" "')
			pat[#pat + 1] = '"'..seq..'"'
		end
	end
	-- Now, build a pattern from this set. The pattern is just an
	-- alternation of all the tokens list.
	if #pat == 0 then
		return function(seq) return seq end
	end
	pat = dark.pattern("["..tag.." "..table.concat(pat, " | ").."]")
	return function(seq)
		return pat(seq)
	end		
end

--[[----------------------------------------------------------------------------
--  Category
--]]----------------------------------------------------------------------------

function dark.basic()
	local p1 = dark.pattern("          \
		  [#w /^[%a\xA0-\xFF]+$/ ] \
		| [#d /^[-+]?%d+%.?%d*$/ ] \
		| [#p /^%p+$/ ]            \
	")
	local p2 = dark.pattern("[#W /^%u[%a\xA0-\xFF]*$/ ]")
	return function(seq)
		return p2(p1(seq))
	end
end

--[[----------------------------------------------------------------------------
--  Pipeline
--]]----------------------------------------------------------------------------

local pipeline = {}
pipeline.__index = pipeline

function pipeline:add(pass)
	self[#self + 1] = pass
end

function pipeline:basic()
	return self:add(dark.basic())
end
function pipeline:model(...)
	return self:add(dark.model(...))
end
function pipeline:pattern(...)
	local ok, res = pcall(dark.pattern, ...)
	if ok then
		return self:add(res)
	end
	error(res, 2)
end
function pipeline:lexicon(...)
	return self:add(dark.lexicon(...))
end

function pipeline:__call(seq)
	if type(seq) == "string" or type(seq) == "table" then
		seq = dark.sequence(seq)
	elseif dark.type(seq) ~= "sequence" then
		error("invalid argument, sequence expected", 2)
	end
	for idx, pass in ipairs(self) do
		pass(seq)
	end
	return seq
end

function dark.pipeline()
	return setmetatable({}, pipeline)
end

--[[----------------------------------------------------------------------------
--  Process inputs
--]]----------------------------------------------------------------------------

if select("#", ...) == 0 then
	print("Dark v"..dark.version)
else
	local code, err = loadfile((...))
	if code then
		code(select(2, ...))
	else
		error(err)
	end
end

--[[----------------------------------------------------------------------------
--  This is the end...
--]]----------------------------------------------------------------------------

