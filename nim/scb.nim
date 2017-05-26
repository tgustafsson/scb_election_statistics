import httpclient, json, sequtils, sets, algorithm, tables, strutils
type
  YearValueRiktnummer = tuple[year: string, value: float, riktnummer: string]
  Variablest = object
    code: string
    text: string
    values: seq[string]
    valueTexts: seq[string]
  Meta = object
    title: string
    variables: seq[Variablest]
  DataPoint = object
    key: seq[string]
    values: seq[string]
  Datat = object
    data: seq[DataPoint]
var client = newHttpClient()
let meta = parseJson(getContent("http://api.scb.se/OV0104/v1/doris/sv/ssd/START/ME/ME0104/ME0104D/ME0104T4"))
let mmeta = to(meta, Meta)
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
let temp2 = parseJson(response.body[3 .. response.body.high])
#let data = temp2["data"]
let ddata = to(temp2, Datat)
var riktnummer_ort = initTable[string, string](512)
for i in 0..len(mmeta.variables[0].values) - 1:
  riktnummer_ort[mmeta.variables[0].values[i]] = mmeta.variables[0].valueTexts[i]
var temp = filter(ddata.data, proc(item : DataPoint):bool = item.values[0] != "..")
var year_value_riktnummer = map(temp, proc(item: DataPoint) : YearValueRiktnummer = (year: item.key[1], value: item.values[0].parseFloat(), riktnummer: item.key[0]))
var years = toOrderedSet(map(year_value_riktnummer, proc(item : YearValueRiktnummer):string=item.year))
proc cmp(a,b:YearValueRiktnummer):int = 
  if a.value < b.value: result = -1 elif a.value==b.value: result = 0 else: result = 1
for year in years:
  var correct_year = filter(year_value_riktnummer, proc(item : YearValueRiktnummer):bool=year==item.year)
  correct_year.sort(cmp)
  var all_largest = filter(correct_year, proc(item : YearValueRiktnummer):bool=item.value==correct_year[high(correct_year)].value)
  var orter = map(all_largest, proc(item:YearValueRiktnummer):string=riktnummer_ort[item.riktnummer])
  echo $year & " " & join(orter, ",") & " " & correct_year[0].value.formatFloat(precision=1,format=ffDecimal) & "%" 
