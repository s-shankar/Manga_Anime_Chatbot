local s = "My name is Pierre. I love apples. My name is C.C. and I love pears."

for sen in s:gmatch("(.-[a-z][.?!])") do
	print(sen)
end
