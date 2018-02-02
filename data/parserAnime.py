#! /usr/bin/python
# encoding=utf8
"""
1. parse :

curl -sb -H "Accept: application/json" "https://api.jikan.me/anime/...
"
or
curl -sb -H "Accept: application/json" "https://api.jikan.me/anime/.../character_staff"

then pipeline it with | json_pp or any prettyprintifyer
and store the output into animeFiche.json or animeChar.json
"""

import sys
import io
import json
from pprint import pprint
from pprint import PrettyPrinter

if __name__ == '__main__':
    reload(sys)
    sys.setdefaultencoding('utf8')
    with io.open("bebop.json",encoding="utf-8") as animeData:
        data = json.load(animeData)
    animeFiche = ""
    animeFiche = animeFiche.join('{')
    print("\t{")
    print("\t\t[\"title\"] = \"{0}\",".format(str(data["title"])))
    buff ="\t\t[\"title\"] = \"{0}\",".format(str(data["title"]))
    animeFiche = ''.join([animeFiche,buff])
    studioString = ""
    for s in data["studio"]:
        #studioString = studioString+(str(s['name'])+',')
        studioString = "%s\"%s\"," % (studioString,(str(s['name'])))
    studioString = studioString[:-1]
    print("\t\t[\"studios\"] = {{{0}}},".format(studioString))
    buff = "\t\t[\"studios\"] = {{{0}}},".format(studioString)
    animeFiche = ''.join([animeFiche,buff])
    print("\t\t[\"episodes\"] = {0},".format(str(data["episodes"])))
    buff  = "\t\t[\"episodes\"] = {0},".format(str(data["episodes"]))
    animeFiche = ''.join([animeFiche,buff])
    print("\t\t[\"status\"] = \"{0}\",".format(str(data["status"])))
    buff = "\t\t[\"status\"] = \"{0}\",".format(str(data["status"]))
    animeFiche = ''.join([animeFiche,buff])
    genreString = ""
    for g in data["genre"]:
        genreString = "%s\"%s\"," % (genreString,str(g['name']))
    genreString = genreString[:-1]
    print("\t\t[\"genres\"] = {{{0}}},".format(str(genreString)))
    buff = "\t\t[\"genres\"] = {{{0}}},".format(str(genreString))
    animeFiche = ''.join([animeFiche,buff])
    print("\t\t[\"synopsis\"] = \"{0}\",".format(data["synopsis"].encode('utf-8')))
    buff = "\t\t[\"synopsis\"] = \"%s\"," % (data["synopsis"])
    animeFiche = ''.join([animeFiche,buff])
    print("\t\t[\"popularity\"] = "+str(data["popularity"])+",")
    buff = "\t\t[\"popularity\"] = "+str(data["popularity"])+","
    animeFiche = ''.join([animeFiche,buff])
    relatedW = ""
    if "Summary" in data["related"] :
        summaryW = ""
        for s in data["related"]["Summary"]:
            summaryW= "%s{[\"title\"] = \"%s\", [\"type\"] = \"%s\"}, " % (summaryW,s["title"],s["type"])
        #print(str(summaryW))
        relatedW = "%s%s" % (relatedW, summaryW)
    if "Adaptation" in data["related"] :
        adaptW = ""
        for a in data["related"]["Adaptation"]:
            adaptW = "%s{[\"title\"] = \"%s\", [\"type\"] = \"%s\"}, " % (adaptW,a["title"],a["type"])
        #print(str(adaptW))
        relatedW = "%s%s" % (relatedW,adaptW)
    if "Side story" in data["related"]:
        sideW = ""
        for side in data["related"]["Side story"]:
            sideW = "%s{[\"title\"] = \"%s\", [\"type\"] = \"%s\"}, " % (sideW,side["title"],side["type"])
        #print(str(sideW))
        relatedW = "%s%s" % (relatedW,sideW)
        relatedW = relatedW[:-2]
    relatedW = "{{{0}}},".format(relatedW)
    print('\t\t[\"relatedWorks\"] = %s,'%(relatedW))
    animeFiche = ''.join([animeFiche,relatedW])
    characterW = ""
    for c in data["character"]:
        name = c["name"].split(", ")
        characterW = "%s{[\"firstname\"] = \"%s\", [\"lastname\"] = \"%s\", [\"role\"] = \"%s\"}, " % (characterW, name[-1],name[0],c["role"])
    characterW = characterW[:-2]
    print("\t\t[\"characters\"] = {%s},"% (characterW))
    buff = "\t\t[\"characters\"] = {%s},"% (characterW)
    animeFiche = ''.join([animeFiche,buff])
    staffW =""
    for s in data["staff"]:
        name = s["name"].split(", ")
        staffW = "%s [\"%s %s\"], " % (staffW,name[-1],name[0])
    staffW = staffW[:-2]
    print("\t\t[\"staff\"] = {{{0}}},".format(str(staffW)))
    buff = "\t\t[\"staff\"] = {{{0}}},".format(str(staffW))
    animeFiche = ''.join([animeFiche,buff])
    print("\t\t[\"reviews\"] = { },")
    buff = "\t\t[\"reviews\"] = { },"
    animeFiche = ''.join([animeFiche,buff,'\t}'])
    print("\t},")
    PrettyPrinter(indent=4)
    #pprint(animeFiche)
    animeData.close()
