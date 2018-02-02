local input = ""
local answer = "I am sorry, I do not understand"



repeat
	local input = io.read()
	if input == "hello" then
		answer = "Konichiwa"
	end
	if input == "bye" then
		answer = "Sayonara"
	end
	print(answer)
	answer = "I am sorry, I do not understand"
until input == "bye"
