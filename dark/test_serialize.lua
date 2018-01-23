local theme = {}

theme["cooking"] = {"cook", "cooking", "food", "chef"}

s = serialize(theme)
z = loadstring(s)()
print(z)
