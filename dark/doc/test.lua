local dark = require("dark")

local function str2seq(str)
	local tok, tag = {}, {}
	for seg in str:gmatch("%S+") do
		tok[#tok + 1] = seg:match("^[^/]+")
		for itm in seg:gmatch("/([^/]+)") do
			local t, l = itm:match("([^:]+):(%d+)")
			if not t then t, l = itm, 1 end
			tag[#tag + 1] = {t, #tok, l}
		end
	end
	local seq = dark.sequence(tok)
	for _, lst in ipairs(tag) do
		seq:add("#"..lst[1], lst[2], lst[2] + lst[3] - 1)
	end
	return seq
end

local function seq2str(seq)
	local res = {}
	for pos, tok, tags in seq:iter() do
		table.sort(tags, function(a, b)
			if a.length < b.length then
				return true
			elseif a.length > b.length then
				return false
			elseif a.name < b.name then
				return true
			end
			return false
		end)
		for i, tag in ipairs(tags) do
			tok = tok.."/"..tag.name:gsub("^#", "")
			if tag.length > 1 then
				tok = tok..":"..tag.length
			end
		end
		res[pos] = tok
	end
	return table.concat(res, " ")
end

local tests = {
  {"a b c",     "[#A x]",      "a b c"          },
  {"x b c",     "[#A x]",      "x/A b c"        },
  {"x x c",     "[#A x]",      "x/A x/A c"      },
  {"x x x",     "[#A x]",      "x/A x/A x/A"    },
  {"a b c",     "[#A a b]",    "a/A:2 b c"      },
  {"a b c",     "[#A b c]",    "a b/A:2 c"      },
  {"a b c",     "[#A c d]",    "a b c"          },
  {"a b c",     "[#A a]b",     "a/A b c"        },
  {"a b c",     "[#A b]c",     "a b/A c"        },
  {"a b c",     "[#A c]d",     "a b c"          },
  {"a b c",     "a[#A b]",     "a b/A c"        },
  {"a b c",     "b[#A c]",     "a b c/A"        },
  {"a b c",     "c[#A d]",     "a b c"          },
  {"a b c",     "[#A a]",      "a/A b c"        },
  {"a b c",     "[#A a|b]",    "a/A b/A c"      },
  {"a b c",     "[#A a|b|c]",  "a/A b/A c/A"    },
  {"a b b b c", "[#A b*]",     "a b/A:3 b b c"  },
  {"a b b b c", "[#A b*b]",    "a b/A:3 b b c"  },
  {"a b b b c", "[#A b*]b",    "a b/A:2 b b c"  },
  {"a b b b c", "[#A b*?]",    "a b b b c"      },
  {"a b b b c", "[#A b*?b]",   "a b/A b/A b/A c"},
  {"a b b b c", "[#A b*?]b",   "a b b b c"      },
  {"a b b b c", "[#A b+]",     "a b/A:3 b b c"  },
  {"a b b b c", "[#A b+b]",    "a b/A:3 b b c"  },
  {"a b b b c", "[#A b+]b",    "a b/A:2 b b c"  },
  {"a b b b c", "[#A b+?]",    "a b/A b/A b/A c"},
  {"a b b b c", "[#A b+?b]",   "a b/A:2 b b c"  },
  {"a b b b c", "[#A b+?]b",   "a b/A b b c"    },
  {"a b b b c", "[#A b?]",     "a b/A b/A b/A c"},
  {"a b b b c", "[#A b?b]",    "a b/A:2 b b/A c"},
  {"a b b b c", "[#A b?]b",    "a b/A b b c"    },
  {"a b b b c", "[#A b??]",    "a b b b c"      },
  {"a b b b c", "[#A b??b]",   "a b/A b/A b/A c"},
  {"a b b b c", "[#A b??]b",   "a b b b c"      },
  {"a b b b c", "[#A b{1}]",   "a b/A b/A b/A c"},
  {"a b b b c", "[#A b{2}]",   "a b/A:2 b b c"  },
  {"a b b b c", "[#A b{3}]",   "a b/A:3 b b c"  },
  {"a b b b c", "[#A b{4}]",   "a b b b c"      },
  {"a b b b c", "[#A b{,1}]",  "a b/A b/A b/A c"},
  {"a b b b c", "[#A b{,2}]",  "a b/A:2 b b/A c"},
  {"a b b b c", "[#A b{,3}]",  "a b/A:3 b b c"  },
  {"a b b b c", "[#A b{,4}]",  "a b/A:3 b b c"  },
  {"a b b b c", "[#A b{1,}]",  "a b/A:3 b b c"  },
  {"a b b b c", "[#A b{2,}]",  "a b/A:3 b b c"  },
  {"a b b b c", "[#A b{3,}]",  "a b/A:3 b b c"  },
  {"a b b b c", "[#A b{4,}]",  "a b b b c"      },
  {"a b b b c", "[#A b{,1}?]", "a b b b c"      },
  {"a b b b c", "[#A b{,2}?]", "a b b b c"      },
  {"a b b b c", "[#A b{,3}?]", "a b b b c"      },
  {"a b b b c", "[#A b{,4}?]", "a b b b c"      },
  {"a b b b c", "[#A b{1,}?]", "a b/A b/A b/A c"},
  {"a b b b c", "[#A b{2,}?]", "a b/A:2 b b c"  },
  {"a b b b c", "[#A b{3,}?]", "a b/A:3 b b c"  },
  {"a b b b c", "[#A b{4,}?]", "a b b b c"      },

  {"a/A:2 b/B:3 c d e", "[#X #A b]",   "a/A:2 b/B:3 c d e"    },
  {"a/A:2 b/B:3 c d e", "[#X #A c]",   "a/A:2/X:3 b/B:3 c d e"},
  {"a/A:2 b/B:3 c d e", "[#X #A d]",   "a/A:2 b/B:3 c d e"    },
  {"a/A:2 b/B:3 c d e", "[#X #A #B]",  "a/A:2 b/B:3 c d e"    },
  {"a/A:2 b/B:3 c d e", "[#X #A? #B]", "a/A:2 b/B:3/X:3 c d e"},

--  {"", "", ""},
}

local cnt, err = 0, 0
for idx, tst in ipairs(tests) do
	local seq = str2seq(tst[1])
	local pat = dark.pattern(tst[2])
	local res = seq2str(pat(seq))
	if res ~= tst[3] then
		print("Failed test "..idx)
		print("  seq: "..tst[1])
		print("  pat: "..tst[2])
		print("  ref: "..tst[3])
		print("  got: "..res)
		err = err + 1
	end
	cnt = cnt + 1
end

print("Result : "..(cnt - err).."/"..cnt.." test passed")

