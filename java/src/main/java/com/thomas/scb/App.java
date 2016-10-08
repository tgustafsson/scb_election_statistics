// mvn compile assembly:single
// java -cp target/scb-1.0-SNAPSHOT-jar-with-dependencies.jar com.thomas.scb.App
package com.thomas.scb;

import java.io.BufferedReader;
import java.io.DataOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.io.UnsupportedEncodingException;
import java.lang.reflect.Type;
import java.net.HttpURLConnection;
import java.net.MalformedURLException;
import java.net.ProtocolException;
import java.net.URL;
import java.net.URLEncoder;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeSet;
import java.util.regex.Pattern;
import java.util.stream.Collectors;

import org.apache.http.*;
import org.apache.http.client.*;
import org.apache.http.client.methods.*;
import org.apache.http.entity.*;
import org.apache.http.impl.client.*;

import com.google.gson.*;
import com.sun.org.apache.xpath.internal.operations.Variable;

// Classes used for writing json to query the server
class Selection {
	public String filter;
	public List<String> values;
	public Selection() {
	}
	public Selection(String filter, List<String> values) {
		this.filter = filter;
		this.values = values;
	}
}

class Filter {
	public String code;
	public Selection selection;
	public Filter() {
	}
	public Filter(String code, Selection selection) {
		this.code = code;
		this.selection = selection;
	}
}

class PostRequest {
	public List<Filter> query;
	public HashMap<String, String> response;
}

class FilterInstanceCreator implements InstanceCreator<Filter> {
	public Filter createInstance(Type type) {
		return new Filter();
	}
}

class SelectionInstanceCreator implements InstanceCreator<Selection> {
	public Selection createInstance(Type type) {
		return new Selection();
	}
}

// Class for representing the meta information, and a method for querying the meta data, and a method for transforming riktnummer to ort
class Meta {
	public String title;
	public List<Variables> variables;

	public static Meta readFromUrl() {
		GsonBuilder gsonBuilder = new GsonBuilder();
		gsonBuilder.registerTypeAdapter(Variables.class, new VariablesInstanceCreator());
		Gson gson = gsonBuilder.create();
		URL url = null;
		try {
			url = new URL("http://api.scb.se/OV0104/v1/doris/sv/ssd/START/ME/ME0104/ME0104D/ME0104T4");
		} catch ( MalformedURLException e ) {
			System.exit(1);
		}
		HttpURLConnection con = null;
		try {
			con = (HttpURLConnection)url.openConnection();
		} catch ( IOException e ) {
			System.exit(1);
		}
		try {
			con.setRequestMethod("GET");
		} catch ( ProtocolException e  ) {
			System.exit(1);
		}
		StringBuffer response = null;
		try {

			int responseCode = con.getResponseCode();
			BufferedReader in = new BufferedReader(
				new InputStreamReader(con.getInputStream()));
			String inputLine;
			response = new StringBuffer();

			while ( (inputLine = in.readLine()) != null ) {
				response.append(inputLine);
			}
			in.close();
		} catch ( IOException e ) {}
		Meta m = gson.fromJson(response.toString(), Meta.class);
		return m;
	}

	String getOrt(String riktnummer) {
		for ( int i = 0; i < variables.size(); i++ ) {
			if ( variables.get(i).code.equals("Region") ) {
				for ( int j = 0; j < variables.get(i).valueTexts.size(); j++ ) {
					if ( variables.get(i).values.get(j).equals(riktnummer) ) {
						return variables.get(i).valueTexts.get(j);
					}
				}
			}
		}
		return "";
	}
}

// Class for representing meta data from the server
class Variables {
	String code;
	String text;
	List<String> values;
	List<String> valueTexts;
}

class VariablesInstanceCreator implements InstanceCreator<Variables> {
	public Variables createInstance(Type type) {
		return new Variables();
	}
}

// Class used for representing data points in the queried data from the server
class DataPoint {
	List<String> key;
	List<String> values;
}

class DataPointInstanceCreator implements InstanceCreator<DataPoint> {
	public DataPoint createInstance(Type type) {
		return new DataPoint();
	}
}

// Class used for representing the data and a method for reading it
class Data {
	List<DataPoint> data;

	public static Data readFromUrl() throws UnsupportedEncodingException, IOException, Exception {
		GsonBuilder gsonBuilder = new GsonBuilder();
		gsonBuilder.registerTypeAdapter(Selection.class, new SelectionInstanceCreator());
		gsonBuilder.registerTypeAdapter(Filter.class, new FilterInstanceCreator());
		Gson gson = gsonBuilder.create();

		PostRequest pr = new PostRequest();
		pr.query = new ArrayList<Filter>();
		pr.query.add(new Filter("Region", new Selection("all", Arrays.asList("*"))));
		pr.query.add(new Filter("ContentsCode", new Selection("item", Arrays.asList("ME0104B8"))));
		pr.query.add(new Filter("Tid", new Selection("all", Arrays.asList("*"))));
		pr.response = new HashMap<String, String>();
		pr.response.put("format", "json");

		HttpClient client = HttpClients.createDefault();
		HttpPost request = new HttpPost("http://api.scb.se/OV0104/v1/doris/sv/ssd/START/ME/ME0104/ME0104D/ME0104T4");
		StringEntity se = new StringEntity(gson.toJson(pr));
		request.setHeader("Content-Type", "application/json;charset=utf-8");
		request.setEntity(se);
		HttpResponse response = client.execute(request);

		if ( response.getStatusLine().getStatusCode() == 200 ) {
			InputStream ips  = response.getEntity().getContent();
			GsonBuilder dataJsonBuilder = new GsonBuilder();
			dataJsonBuilder.registerTypeAdapter(DataPoint.class, new DataPointInstanceCreator());
			Gson dataJson = dataJsonBuilder.create();
			BufferedReader buf = new BufferedReader(new InputStreamReader(ips, "UTF-8"));
			StringBuilder sb = new StringBuilder();
			String s;
			while ( true ) {
				s = buf.readLine();
				if ( s == null || s.length() == 0 ) break;
				sb.append(s);
			}
			buf.close();
			ips.close();
			Data d = dataJson.fromJson(sb.toString(), Data.class);
			return d;
		}
		return null;
	}
}

// Class for mapping Ort to Percentage
class OrtValue {
	public String ort;
	public float value;
	public OrtValue(String ort, float value) {
		this.ort = ort;
		this.value = value;
	}
}

// The program logic. It finds the maximum percentage per year and lista the Orts having it.
class Program {
	public void run() {
		Meta m = Meta.readFromUrl(); // Get the meta data
		Data d = null;
		try {
			d = Data.readFromUrl(); // Get the data
		} catch ( Exception e ) {
			System.out.println(e.toString());
		}
		// Derive the years having data by collecting all years, but form a set of them. Each year will occur only once
		Set<String> years = d.data.stream().map(p -> p.key.get(1)).collect(Collectors.toCollection(TreeSet::new));
		// For each year
		for(String year : years){
			// derive, for each valid data point, an OrtValue object, and collect all these into a list
			List<OrtValue> temp = d.data.stream()
			    .filter(p -> !p.values.get(0).equals(".."))
			    .filter(p -> p.key.get(1).equals(year))
			    .map(p -> new OrtValue(m.getOrt(p.key.get(0)), Float.parseFloat(p.values.get(0))))
			    .collect(Collectors.toList());
			// sort this list falling with respect to percentage
			Collections.sort(temp, (a, b) -> a.value > b.value ? -1 : a.value == b.value ? 0 : 1);
			// derive a new list with Ort names of those Orts having maximum percentage
			List<String> temp2 = temp.stream()
			    .filter(p -> p.value == temp.get(0).value )
			    .map(p -> p.ort)
			    .collect(Collectors.toList());
			// Print the found data
			System.out.println(year + ": " + String.join(", ", temp2) + " " + Float.toString(temp.get(0).value) + "%");
		}
	}
}

public class App {
	public static void main(String[] args) {
		Program prg = new Program();
		prg.run();
	}
}
