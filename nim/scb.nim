import httpclient, json, sequtils, sets, algorithm, tables, strutils
type
  YearValueRiktnummer = tuple[year: string, value: float, riktnummer: string]
var client = newHttpClient()
var meta = parseJson(getContent("http://api.scb.se/OV0104/v1/doris/sv/ssd/START/ME/ME0104/ME0104D/ME0104T4"))
var body = %*
  {
     "query" : [
       { "code" : "Region", "selection" : {"filter" : "all", "values" : ["*"]} },
       { "code" : "ContentsCode", "selection" : {"filter" : "item", "values" : ["ME0104B8"]} },
       { "code" : "Tid", "selection" : {"filter" : "all", "values" : ["*"]} }
      ],
     "response" : {"format" : "json"}
   }
var response = client.post("http://api.scb.se/OV0104/v1/doris/sv/ssd/START/ME/ME0104/ME0104D/ME0104T4", $body)
var data = parseJson(response.body)["data"]
var riktnummer_ort = initTable[string, string]()
for i in 0..len(meta["variables"][0]["values"].getElems()) - 1:
  riktnummer_ort[meta["variables"][0]["values"].getElems()[i].getStr()] = meta["variables"][0]["valueTexts"].getElems()[i].getStr()
var temp = filter(data.getElems(), proc(item : JsonNode):bool=item["values"].getElems()[0].getStr()!="..")
var year_value_riktnummer = map(temp, proc(item: JsonNode):YearValueRiktnummer=(year: item["key"].getElems()[1].getStr(), value: item["values"].getElems()[0].getStr().parseFloat(), riktnummer: item["key"].getElems()[0].getStr()))
var years = toOrderedSet(map(year_value_riktnummer, proc(item : YearValueRiktnummer):string=item.year))
proc cmp(a,b:YearValueRiktnummer):int = 
  if a.value < b.value: result = -1 elif a.value==b.value: result = 0 else: result = 1
for year in years:
  var correct_year = filter(year_value_riktnummer, proc(item : YearValueRiktnummer):bool=year==item.year)
  correct_year.sort(cmp)
  var all_largest = filter(correct_year, proc(item : YearValueRiktnummer):bool=item.value==correct_year[high(correct_year)].value)
  var orter = map(all_largest, proc(item:YearValueRiktnummer):string=riktnummer_ort[item.riktnummer])
  echo $year & " " & join(orter, ",") & " " & correct_year[0].value.formatFloat(precision=1,format=ffDecimal) & "%" 
