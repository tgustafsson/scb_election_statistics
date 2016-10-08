"""
Run the program with python3 lw.py

This program queries SCB about participation ratios in elections.  It 
processes the query and prints the result to the console.  

Design decisions:
* Keep it simple
* Run-time will be I/O bound so easy to read algorithms can be used 
  without too big effect on total run-time 
* Use MVC pattern as it fosters separation of concerns if, e.g., different 
  outputs shall be supported 
* Since SCB limits the number of queries, the number is reduced by storing 
  a bigger data set in the client and processing it.  The data set is rather 
  small and the memory effect should be negligible 

Produced output:
1973 Vellinge 95.4%
1976 Lomma 96.0%
1979 Lomma, Vellinge 95.3%
1982 Lomma 95.7%
1985 Danderyd 94.5%
1988 Danderyd, Vellinge 92.0%
1991 Danderyd 93.0%
1994 Vellinge 92.6%
1998 Danderyd 88.2%
2002 Lomma 88.1%
2006 Lomma 89.7%
2010 Lomma 91.3%
2014 Lomma 92.9%
"""

import http.client
import json
from string import Template
import unittest
import sys

class QueryError(Exception):
    pass

class ElectionParticipationPerYearModel(object):

    # type of query
    COUNTRY = 1
    MUNICIPALITY = 2
    COUNTY = 3

    def __init__(self):
        self._url = "/OV0104/v1/doris/sv/ssd/START/ME/ME0104/ME0104D/ME0104T4"

    def _aggregate(self):
        """
        Build internal data structures that are accessible via `get_years`, `get_regions`, `get_value`, and `run_filter`
        """
        map_region_code_region_name = {}
        map_region_name_region_code = {}
        agg = {}

        if "variables" in self._metadata:
            for variables in self._metadata["variables"]:
                if variables["code"] == "Region":
                    i=0
                    while i < len(variables["values"]):
                        map_region_code_region_name[variables["values"][i]] = variables["valueTexts"][i]
                        map_region_name_region_code[variables["valueTexts"][i]] = variables["values"][i]
                        i+=1

        regions = {}
        # aggregate data
        if "data" in self._data:
            for v in self._data["data"]:
                value = v["values"][0]
                year = v["key"][1]
                region = v["key"][0]
                regions[map_region_code_region_name[region]] = True
                if year not in agg:
                    agg[year] = {}
                if region not in agg[year]:
                    agg[year][region] = {}
                try:
                    agg[year][region] = float(value)
                except:
                    if value == "..":  # if the value is not present we remove it from the data structure
                        del agg[year][region]
                    else:
                        raise # otherwise, reraise the exception and handle it elsewhere

        self._agg = agg
        self._map_rcode_to_rname = map_region_code_region_name
        self._map_rname_to_rcode = map_region_name_region_code
        self._regions = regions

    def get_data(self, qtype):
        """
        Perform the query
        :param qtype: state which type of data that shall be fetched
        """
        scb = http.client.HTTPConnection("api.scb.se")
        scb.request("GET", self._url)
        metadata = scb.getresponse()
        if metadata.status != 200:
            raise QueryError()
        d = metadata.read()
        self._metadata = json.loads(str(d, encoding = "UTF-8"))
        qstring = Template("""
            {"query" : 
               [
               {"code" : "Region", "selection" : {"filter" : "all", "values" : ["*"]}},
               {"code" : "ContentsCode", "selection" : {"filter" : "item", "values" : ["$typeofdata"]}},
               {"code" : "Tid", "selection" : {"filter" : "all" , "values" : ["*"]}}
               ],
             "response" : {"format" : "json"}
            }""")
        # construct query with query type. This is controlled here so we should not
        # get some nasty text in the query to SCB
        if qtype == self.COUNTRY:
            qstring = qstring.substitute(typeofdata = "ME0104B8")
        elif qtype == self.COUNTY:
            qstring = qstring.substitute(typeofdata = "ME0104C5")
        elif qtype == self.MUNICIPALITY:
            qstring = qstring.substitute(typeofdata = "ME0104C6")
        else:
            raise QueryError()
        scb.request("POST", self._url, qstring)
        r1 = scb.getresponse()
        if r1.status != 200:
            raise QueryError()
        d = r1.read()
        scb.close()
        d3 = d[3:] # remove the UTF-8 BOM that seems to be part of the response
        self._data = json.loads(str(d3, encoding = "UTF-8"))
        self._aggregate()

    def get_years(self):
        """
        :returns: the years where statistics are available
        """
        return sorted(self._agg)

    def get_regions(self):
        """
        :returns: the regions in clear text that are available
        """
        return sorted(self._regions)

    def get_value(self, year, region):
        """
        :param year: the year
        :param region: the region in clear text
        :returns: the value that is available for `year` and `region`
        """
        return self._agg[year][self._map_rname_to_rcode[region]]

    def run_filter(self, query, init):
        """
        :param query: a function that is called on each element
        :param init: an init value to be input to the query
        :returns: the last returned value from `query`
        """
        for y in self.get_years():
            for r in self.get_regions():
                init = query(y, r, init)
        return init

class ConsoleView(object):
    """
    Formats the data for the console

    Data format is assumed to be
    {year : {"regions" : [regions], "value" : value}}
    e.g.
    {"1975" : {"regions" : ["A", "B"], "value" : 99}}
    """
    def __init__(self):
        self.__year_to_region = {}

    def set_data(self, data):
        self.__year_to_region = data

    def __str__(self):
        s=""
        for year in sorted(self.__year_to_region):
            s += year + " " + ", ".join(self.__year_to_region[year]["regions"]) + " " + str(self.__year_to_region[year]["value"]) + "%\n"
        return s

class Control(object):
    def __init__(self, model, view):
        """
        :param model: the model that keeps the data
        :param view: the view that formats the output
        """
        self.__model = model
        self.__view = view
        self.__processed_data = {}

    def fetch(self, qtype):
        """
        Fill the model with the data
        """
        self.__model.get_data(qtype)

    def process_max_election_participation_per_year(self):
        """
        Main algorithm to get the maxiumum election ratio for each year
        """
        for year in self.__model.get_years():            
            v = 0.0
            r = []
            for region in self.__model.get_regions():
                if region != "Riket": # Riket is not a specific region
                    try:
                        rv = self.__model.get_value(year, region)
                        if rv > v:
                            v = rv 
                            r = [region]
                        elif rv == v:
                            r.append(region)
                    except KeyError:
                        pass # if there is no available election data, then skip it with the effect of 0% ratio
                
            self.__processed_data[year] = {"regions" : r, "value" : v}

    def view(self):
        """
        :returns: the output of the processed data as formatted by the viewer
        """
        self.__view.set_data(self.__processed_data)
        return str(self.__view)

class TestModel(unittest.TestCase):
    """
    This set of unit tests tries to test _some_ of the corner cases
    I rather like when the tests also perform some integration of the parts, otherwise some tests mostly tests the mock ups!

    Run the tests with python3 -m unittest lw.py
    """
    class ModelMockup(ElectionParticipationPerYearModel):
        def __init__(self):
            super(TestModel.ModelMockup, self).__init__()

        def get_data(self, m, d):
            self._metadata = m
            self._data = d
            self._aggregate()

    def test_model_no_data(self):
        m = TestModel.ModelMockup()
        m.get_data({}, {})
        self.assertEqual(m.get_years(), [])
        self.assertEqual(m.get_regions(), [])

    def test_model_simple_data(self):
        m = TestModel.ModelMockup()
        m.get_data({"variables" : [{"code" : "Region", "values" : ["00"], "valueTexts" : ["Nyk"]}]}, {"data" : [{"values" : ["12.5"], "key" : ["00", "1975"]}]})
        self.assertEqual(m.get_years(), ["1975"])
        self.assertEqual(m.get_regions(), ["Nyk"])

    def test_exception_on_wrong_key(self):
        m = TestModel.ModelMockup()
        m.get_data({"variables" : [{"code" : "Region", "values" : ["00"], "valueTexts" : ["Nyk"]}]}, {"data" : [{"values" : ["12.5"], "key" : ["00", "1975"]}]})
        self.assertRaises(KeyError, m.get_value, "1976", "Nyk")

    def test_integration_some_data(self):
        m = TestModel.ModelMockup()
        m.get_data({"variables" : [{"code" : "Region", "values" : ["00", "01"], "valueTexts" : ["Nyk", "Esk"]}]}, {"data" : [{"values" : ["12.5"], "key" : ["00", "1975"]}, {"values" : ["18"], "key" : ["01", "1975"]}]})
        self.assertEqual(m.get_years(), ["1975"])
        self.assertEqual(m.get_regions(), ["Esk", "Nyk"])
        v = ConsoleView()
        c = Control(m, v)
        c.process_max_election_participation_per_year()
        self.assertEqual(c.view(), """1975 Esk 18.0%\n""")

    def test_integration_multiple_max(self):
        m = TestModel.ModelMockup()
        m.get_data({"variables" : [{"code" : "Region", "values" : ["00", "01"], "valueTexts" : ["Nyk", "Esk"]}]}, {"data" : [{"values" : ["18"], "key" : ["00", "1975"]}, {"values" : ["18"], "key" : ["01", "1975"]}]})
        self.assertEqual(m.get_years(), ["1975"])
        self.assertEqual(m.get_regions(), ["Esk", "Nyk"])
        v = ConsoleView()
        c = Control(m, v)
        c.process_max_election_participation_per_year()
        self.assertEqual(c.view(), """1975 Esk, Nyk 18.0%\n""")

if __name__== "__main__":
    m = ElectionParticipationPerYearModel()
    v = ConsoleView()
    c = Control(m, v)
    c.fetch(ElectionParticipationPerYearModel.COUNTRY)
    c.process_max_election_participation_per_year()
    print(c.view())
