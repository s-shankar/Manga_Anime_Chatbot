"""
This formats MAL review into a lua table format

How to use :

1. Gather your pages of reviews :
for i in `seq <nbofpages>`; do wget "https://myanimelist.net/.../reviews?p=$i" -O $i ; done
(obv adapt URL and number of pages to anime)

2. run script :
for i in `seq <nbofpages>`; do python3 parseReviews.py $i >> anime-file.lua ; done

3. Complete anime-file with the rest of the info

3b. Call me if problems


Better usage : (for fish)
rm * ; for i in (seq 100)
	wget "https://myanimelist.net/.../reviews?p="$i -O $i
	python3 parseReviews.py $i >> anime-file.lua
	if test $status -eq 1
		break
	end
end

Avoids downloading more than necessary and requires fewer input

"""


from bs4 import BeautifulSoup
from sys import stdin, stderr, argv, exit

with open(argv[1], 'r') as f:
	soup = BeautifulSoup(f.read(), "html.parser")


#coms = soup.find_all("div", class_="spaceit textReadability word-break pt8 mt8")
coms = soup.find_all("div", class_="borderDark")

if len(coms) == 0:
	print("No comments",file=stderr)
	exit(1)

else:
	print("\t\t--\n\t\t-- "+str(soup.title.string).strip()+"\n\t\t--\n")

k=-1
for i in coms:
	k+=1
	# pls don't touch my children pyramid
	# actually no need to, it breaks on its own

	score = int(i.contents[3].contents[1].contents[1].contents[1].contents[3].contents[0].contents[0])

	helpful=int(i.contents[1].contents[2].contents[1].contents[1].contents[3].contents[4].contents[1].contents[1].contents[1].contents[0])
	#helpful=int(i.contents[1].contents[2].contents[1].contents[1].contents[3].contents[6].contents[1].contents[1].contents[0])


	text = i.contents[3].get_text()

	text = text[len("\n\n\n\nOverall\n0\n\n\nStory\n0\n\n\nAnimation\n0\n\n\nSound\n0\n\n\nCharacter\n0\n\n\nEnjoyment\n0\n\n\n\n\n"):]

	while text[0] in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]:
		text = text[1:]

	text = text[:-len("\n\nHelpful\n\n\nread more\n")]



	text = text.replace("\\", "\\\\")

	text = text.replace("<br>","\n")
	text = text.replace("<br/>","\n")
	text = text.replace("\n\n","\n")

	# BS4 is SUPPOSED to return Unicode but we don't call its formatter
	text = text.replace("&quot;","'")
	text = text.replace("&rsquo;","'")
	text = text.replace("&ldquo;","'")
	text = text.replace("&rdquo;","'")
	text = text.replace("&eacute;","é")
	text = text.replace("&hellip;","...")
	text = text.replace("&amp;","&")
	text = text.replace("&lt;","<")
	text = text.replace("&gt;",">")
	text = text.replace("&sup1;","¹")
	text = text.replace("&sup2;","²")
	text = text.replace("&sup3;","³")
	text = text.replace("&bull;","•")
	text = text.replace("&ocirc;","ô")
	text = text.replace("&ndash;"," - ")
	text = text.replace("&mdash;"," - ")

	text = text.replace("“", "\"")
	text = text.replace("”", "\"")

	text = text.replace("\"","\\\"")

	text = text.replace("\n","\\n")
	text = text.replace("\r","\\r")

	if k==1:
		pass #import pdb ; pdb.set_trace()

	toPrint = "\t\t"
	toPrint += "{[\"score\"]="+str(score)+","+(" "*(3-len(str(score))))
	toPrint += "[\"helpful\"]="+str(helpful)+","+(" "*(5-len(str(helpful))))
	toPrint += "[\"text\"]=\""+text+"\"},"

	print(toPrint)
