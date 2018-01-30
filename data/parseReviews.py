from bs4 import BeautifulSoup
from sys import stdin, stderr

soup = BeautifulSoup(stdin.read(), "html.parser")


#coms = soup.find_all("div", class_="spaceit textReadability word-break pt8 mt8")
coms = soup.find_all("div", class_="borderDark")

if len(coms) == 0:
	print("No comments",file=stderr)

else:
	print("--\n-- "+str(soup.title.string).strip()+"\n--\n")

k=-1
for i in coms:
	k+=1
	# pls don't touch my children pyramid

	score = int(i.contents[3].contents[1].contents[1].contents[1].contents[3].contents[0].contents[0])

	helpful=int(i.contents[1].contents[2].contents[1].contents[1].contents[3].contents[4].contents[1].contents[1].contents[1].contents[0])

	#print(score, helpful, len(i.contents[3].contents))
	#continue
	text = i.contents[3].contents[2:-3]
	
	"""
	if k==2:
		for t in text :
			print(t, file=stderr)
			print("\n\n\n\n", file=stderr)
		print(len(i.contents[3].contents), file=stderr)
		print(len(text), file=stderr)
	"""
	# heuristics
	if len(i.contents[3].contents) <= 7:
		#print(i.contents[3].contents[2],file=stderr)
		text = [i.contents[3].contents[2]] + text;
	else:
		try:
			text = text[:-1] + text[-1].contents[:-2] # problem here    cat 12 | py3 parse.py > base4.lua
		except Exception:
			print(k, len(i.contents[3].contents),text, file=stderr)
			
	#if k==3:
	#	print(text, file=stderr)
		
	text = [str(x) for x in text]
	text = " ".join(text)
	


	text = text.replace("<br>","\n")
	text = text.replace("<br/>","\n")
	text = text.replace("\n\n","\n")
	text = text.replace("&quot;","'")
	text = text.replace("\"","\\\"")
	
	text = text.replace("\n","\\n")
	text = text.replace("\r","\\r")
	
	print("{[\"score\"]="+str(score)+", [\"helpful\"]="+str(helpful)+", [\"text\"]=\""+text+"\"},")
	print()
