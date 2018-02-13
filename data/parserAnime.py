#! /usr/bin/python
# encoding=utf8
"""
1. parse :

curl -sb -H "Accept: application/json" "https://api.jikan.me/anime/...
"
or
curl -sb -H "Accept: application/json" "https://api.jikan.me/anime/.../characters_staff"

then pipeline it with | json_pp or any prettyprintifyer
and store the output into animeFiche.json or animeChar.json
"""

import sys
import io
import json
import argparse
from pprint import pprint
from pprint import PrettyPrinter

def parseAnime(data,ficheName):
    luaFileName = ficheName.split(".json",1)[0] + str(".lua")
    aFile = open(luaFileName,"w")
    sys.stdout = aFile
    #animeFiche = ""
    #animeFiche = animeFiche.join('{')
    print("return {")
    print("\t[\"title\"] = \"{0}\",".format(str(data["title"])))
    #buff ="\t[\"title\"] = \"{0}\",".format(str(data["title"]))
    #animeFiche = ''.join([animeFiche,buff])
    studioString = ""
    for s in data["studio"]:
        studioString = "%s\"%s\"," % (studioString,(str(s['name'])))
    studioString = studioString[:-1]
    print("\t[\"studios\"] = {{{0}}},".format(studioString))
    #buff = "\t[\"studios\"] = {{{0}}},".format(studioString)
    #animeFiche = ''.join([animeFiche,buff])
    ep = str(data["episodes"]) if type(data["episodes"]) is int else "\"Unknown\""
    print("\t[\"episodes\"] = {0},".format(ep))
    #buff  = "\t[\"episodes\"] = {0},".format(ep)
    #animeFiche = ''.join([animeFiche,buff])
    print("\t[\"status\"] = \"{0}\",".format(str(data["status"].lower())))
    #buff = "\t[\"status\"] = \"{0}\",".format(str(data["status"]))
    #animeFiche = ''.join([animeFiche,buff])
    genreString = ""
    for g in data["genre"]:
        genreString = "%s\"%s\"," % (genreString,str(g['name'].lower()))
    genreString = genreString[:-1]
    print("\t[\"genres\"] = {{{0}}},".format(str(genreString)))
    #buff = "\t[\"genres\"] = {{{0}}},".format(str(genreString))
    #animeFiche = ''.join([animeFiche,buff])
    print("\t[\"synopsis\"] = \"{0}\",".format(normalize_string(data["synopsis"].encode('utf-8'))))
    #buff = "\t[\"synopsis\"] = \"%s\"," % (data["synopsis"])
    #animeFiche = ''.join([animeFiche,buff])
    pop = str(data["popularity"]) if type(data["popularity"]) is int else "\Unknown"
    print("\t[\"popularity\"] = "+str(data["popularity"])+",")
    #buff = "\t[\"popularity\"] = "+str(data["popularity"])+","
    #animeFiche = ''.join([animeFiche,buff])
    relatedW = ""
    if "Summary" in data["related"] :
        summaryW = ""
        for s in data["related"]["Summary"]:
            summaryW= "%s{[\"title\"] = \"%s\", [\"type\"] = \"%s\"}, " % (summaryW,s["title"],s["type"])
        relatedW = "%s%s" % (relatedW, summaryW)
    if "Adaptation" in data["related"] :
        adaptW = ""
        for a in data["related"]["Adaptation"]:
            adaptW = "%s{[\"title\"] = \"%s\", [\"type\"] = \"%s\"}, " % (adaptW,a["title"],a["type"])
        relatedW = "%s%s" % (relatedW,adaptW)
    if "Side story" in data["related"]:
        sideW = ""
        for side in data["related"]["Side story"]:
            sideW = "%s{[\"title\"] = \"%s\", [\"type\"] = \"%s\"}, " % (sideW,side["title"],side["type"])
        relatedW = "%s%s" % (relatedW,sideW)
        relatedW = relatedW[:-2]
    relatedW = "{{{0}}},".format(relatedW)
    print('\t[\"relatedWorks\"] = %s'%(relatedW))
    #animeFiche = ''.join([animeFiche,relatedW])
    characterW = ""
    for c in data["character"]:
        name = c["name"].encode("utf-8").split(", ")
        characterW = "%s{[\"firstname\"] = \"%s\", [\"lastname\"] = \"%s\", [\"role\"] = \"%s\"}, " % (characterW, normalize_string(name[-1].encode('utf-8')),normalize_string(name[0].encode('utf-8')),c["role"])
    characterW = characterW[:-2].encode('utf-8')
    print("\t[\"characters\"] = {%s},"% (characterW))
    #buff = "\t[\"characters\"] = {%s},"% (characterW)
    #animeFiche = ''.join([animeFiche,buff])
    staffW =""
    for s in data["staff"]:
        name = normalize_string(s["name"]).split(", ")
        staffW = "%s{\"%s %s\"}, " % (staffW,name[-1],name[0])
    staffW = staffW[:-2]
    print("\t[\"staff\"] = {{{0}}},".format(str(staffW)))
    #buff = "\t[\"staff\"] = {{{0}}},".format(str(staffW))
    #animeFiche = ''.join([animeFiche,buff])
    print("\t[\"reviews\"] = { },")
    #buff = "\t[\"reviews\"] = { \n\t},"
    #animeFiche = ''.join([animeFiche,buff,'\t}'])
    print("}")
    aFile.close()
    #pprint(animeFiche)

def parseManga(data,mangaName):
    luaFileName = mangaName.split(".json",1)[0] + str(".lua")
    mFile = open(luaFileName,"w")
    sys.stdout = mFile
    mangaFiche = ""
    mangaFiche = mangaFiche.join('{')
    print("return {")
    print("\t[\"title\"] = \"{0}\",".format(str(data["title"])))
    authorString = ""
    for a in data["author"]:
        name = normalize_string(a["name"]).split(", ")
        authorString = "%s \"%s %s\"," % (authorString,(str(name[-1])),str(name[0]))
    authorString = authorString[:-1]
    print("\t[\"authors\"] = {%s}"% (authorString))
    vol = str(data["volumes"]) if type(data["volumes"]) is int else "\"Unknown\""
    print("\t[\"volumes\"] = %s,"%(vol))
    chap = str(data["chapters"]) if type(data["chapters"]) is int else "\"Unknown\""
    print("\t[\"chapters\"] = %s,"%(chap))
    print("\t[\"status\"] = \"%s\","%(data["status"]).lower())
    genreString = ""
    for g in data["genre"]:
        genreString = "%s\"%s\"," % (genreString,str(g['name'].lower()))
    genreString = genreString[:-1]
    print("\t[\"genres\"] = {{{0}}},".format(str(genreString)))
    print("\t[\"synopsis\"] = \"{0}\",".format(normalize_string(data["synopsis"].encode('utf-8'))))
    print("\t[\"popularity\"] = "+str(data["popularity"])+",")
    relatedW = ""
    if "Summary" in data["related"] :
        summaryW = ""
        for s in data["related"]["Summary"]:
            summaryW= "%s{[\"title\"] = \"%s\", [\"type\"] = \"%s\"}, " % (summaryW,s["title"],s["type"])
        relatedW = "%s%s" % (relatedW, summaryW)
    if "Adaptation" in data["related"] :
        adaptW = ""
        for a in data["related"]["Adaptation"]:
            adaptW = "%s{[\"title\"] = \"%s\", [\"type\"] = \"%s\"}, " % (adaptW,a["title"],a["type"])
        relatedW = "%s%s" % (relatedW,adaptW)
    if "Side story" in data["related"]:
        sideW = ""
        for side in data["related"]["Side story"]:
            sideW = "%s{[\"title\"] = \"%s\", [\"type\"] = \"%s\"}, " % (sideW,side["title"],side["type"])
        relatedW = "%s%s" % (relatedW,sideW)
        relatedW = relatedW[:-2]
    relatedW = "{{{0}}},".format(relatedW)
    print('\t[\"relatedWorks\"] = %s'%(relatedW))
    characterW = ""
    for c in data["character"]:
        name = normalize_string(c["name"].encode("utf-8")).split(", ")
        characterW = "%s{[\"firstname\"] = \"%s\", [\"lastname\"] = \"%s\", [\"role\"] = \"%s\"}, " % (characterW, name[-1],name[0],c["role"])
    characterW = characterW[:-2]
    print("\t[\"characters\"] = {%s},"% (characterW.encode("utf-8")))
    print("\t[\"reviews\"] = { \n\n\t}")
    print("}")
    mFile.close()

def normalize_string(raw_string):
    raw_string = raw_string.replace("\"","\\\"")
    raw_string = raw_string.replace("&#039;","'")
    return raw_string

if __name__ == '__main__':
    reload(sys)
    sys.setdefaultencoding('utf8')

    argparser = argparse.ArgumentParser()
    g=argparser.add_mutually_exclusive_group(required=True)
    g.add_argument("-a","--anime",help='anime sheet in json file')
    g.add_argument("-m","--manga",help='manga sheet in json file')
    args = argparser.parse_args()
    pathName = ""
    if args.anime is not None:
        pathName = "anime/"+str(args.anime).split("anime\\",1)[1]
    elif args.manga is not None:
        pathName = "manga"+str(args.manga)

    with io.open(pathName,encoding="utf8") as fp:
        data = json.load(fp,encoding="utf8")

    orig_stdout = sys.stdout
    parseAnime(data,pathName) if args.anime is not None else parseManga(data,pathName)

    sys.stdout = orig_stdout
    fp.close()
    print("Done")
