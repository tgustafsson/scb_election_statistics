// cargo run --release
extern crate hyper;
extern crate core;
extern crate rustc_serialize;
use std::io::Read;
use hyper::Client;
use std::str::FromStr;
use rustc_serialize::json;
use std::collections::HashSet;
use std::collections::HashMap;
use std::f64;

#[derive(RustcDecodable, RustcEncodable)]
pub struct VariablesStruct {
    code : String,
    text : String,
    values : Option<Vec<String>>,
    valueTexts : Option<Vec<String>>,
    time : Option<bool>,
    type_name : Option<String>
}

#[derive(RustcDecodable, RustcEncodable)]
pub struct MetaStruct {
    title : String,
    variables : Vec<VariablesStruct>
}

#[derive(RustcDecodable, RustcEncodable)]
pub struct DataPointStruct {
    key : Vec<String>,
    values : Vec<String>
}

#[derive(RustcDecodable, RustcEncodable)]
pub struct CommentsStruct {
    variable : String,
    value : String,
    comment : String
}

#[derive(RustcDecodable, RustcEncodable)]
pub struct DataStruct {
    columns : Vec<VariablesStruct>,
    comments : Vec<CommentsStruct>,
    data : Vec<DataPointStruct>
}

pub struct OrtPercentage {
    ort : String,
    percentage : f64
}

fn main() {
    let client = Client::new();
    let mut res = client.get("http://api.scb.se/OV0104/v1/doris/sv/ssd/START/ME/ME0104/ME0104D/ME0104T4").send().unwrap();
    if res.status == hyper::Ok {
        let mut body = String::new();
        res.read_to_string(&mut body).unwrap();
        let meta_decoded: MetaStruct = json::decode(body.as_str()).unwrap();

        res = client.post("http://api.scb.se/OV0104/v1/doris/sv/ssd/START/ME/ME0104/ME0104D/ME0104T4").body(r#"
            {"query" : 
               [
               {"code" : "Region", "selection" : {"filter" : "all", "values" : ["*"]}},
               {"code" : "ContentsCode", "selection" : {"filter" : "item", "values" : ["ME0104B8"]}},
               {"code" : "Tid", "selection" : {"filter" : "all" , "values" : ["*"]}}
               ],
             "response" : {"format" : "json"}
            }"#).send().unwrap();
        if res.status == hyper::Ok {
            body.clear();
            res.read_to_string(&mut body).unwrap();
            body = body.replace("\"type\"", "\"type_name\"");
            let mut riktnummer_ort = HashMap::new();
            let ref values = (&meta_decoded.variables[0]).values.as_ref().unwrap();
            let ref valueTexts = (&meta_decoded.variables[0]).valueTexts.as_ref().unwrap();
            for i in 0 .. values.len() {
                riktnummer_ort.insert(values[i].clone(), valueTexts[i].clone());
            }
            let data: DataStruct;
            unsafe{
                data = json::decode(body.slice_unchecked(3,body.len())).unwrap();
            }
            let mut years = HashSet::new();
            for d in &data.data {
                let year = d.key[1].clone();
                years.insert(year);
            }
            let mut _years = (&years).into_iter().collect::<Vec<&String>>();
            _years.sort_by(|a, b| a.partial_cmp(b).unwrap());
            for y in _years.iter() {
                let mut current_year = (&data.data).into_iter().filter(|ref x| &x.key[1] == *y).filter(|ref x| &x.values[0] != "..").map(|x| OrtPercentage{ort: riktnummer_ort.get(&x.key[0]).unwrap().clone(), percentage: FromStr::from_str(&x.values[0]).unwrap()}).collect::<Vec<OrtPercentage>>();
                current_year.sort_by(|a, b| a.percentage.partial_cmp(&b.percentage).unwrap());
                let highest = (&current_year).into_iter().filter(|ref x| x.percentage == current_year.last().unwrap().percentage).collect::<Vec<&OrtPercentage>>();
                print!("{} ", y);
                for h in highest.iter() {
                    print!("{}, ", &h.ort);
                }
                print!("{}%\n", highest.last().unwrap().percentage);
            }
            
        }
        else {
            println!("Could not get data");
        }
    }
    else {
        println!("Could not get meta data");
    }
}
