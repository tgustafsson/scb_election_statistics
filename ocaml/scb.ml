(*opam install ocurl *)
(*opam install yojson *)
(*ocamlfind -o scb ocamlc -package curl,yojson -linkpkg scb.ml*)

open Hashtbl;;
open Yojson.Basic.Util;;
open Set;;
open Printf;;
module SS = Set.Make(String);;
(* Helper methods *)
let _ = Curl.global_init Curl.CURLINIT_GLOBALALL

let writer_callback a d =
	Buffer.add_string a d;
	String.length d

let init_conn url =
	let r = Buffer.create 16384
	and c = Curl.init () in
	Curl.set_timeout c 1200;
	Curl.set_sslverifypeer c false;
	Curl.set_sslverifyhost c Curl.SSLVERIFYHOST_EXISTENCE;
	Curl.set_writefunction c (writer_callback r);
	Curl.set_tcpnodelay c true;
	Curl.set_verbose c false;
	Curl.set_post c false;
	Curl.set_url c url; r,c

(* GET *)
let get url =
	let r,c = init_conn url in
	Curl.set_followlocation c true;
	Curl.perform c;
	let rc = Curl.get_responsecode c in
	Curl.cleanup c;
	rc, (Buffer.contents r)

(* POST *)
let post ?(content_type = "text/html") url data =
	let r,c = init_conn url in
	Curl.set_post c true;
	Curl.set_httpheader c [ "Content-Type: " ^ content_type ];
	Curl.set_postfields c data;
	Curl.set_postfieldsize c (String.length data);
	Curl.perform c;
	let rc = Curl.get_responsecode c in
	Curl.cleanup c;
	rc, (Buffer.contents r)

let () =
  let rc, meta_json = get "http://api.scb.se/OV0104/v1/doris/sv/ssd/START/ME/ME0104/ME0104D/ME0104T4" in (* get meta data *)
  let meta = Yojson.Basic.from_string meta_json in (* transform into json *)
  let riktnummer = (List.nth (meta |> member "variables" |> to_list) 0) |> member "values" |> to_list |>filter_string in (* get a list of riktnummer *)
  let orter = (List.nth (meta |> member "variables" |> to_list) 0) |> member "valueTexts" |> to_list |>filter_string in (* get a list of orter *)
  let riktnummer_orter = Hashtbl.create 100 in (* create a hash to store mapping from riktnummer to ort *)
  let rec ro l1 l2 = match l1,l2 with
    | [],_ -> ()
    | _,[] -> ()
    | (l::ls),(r::rs) -> Hashtbl.add riktnummer_orter l r; ro ls rs in
  ro riktnummer orter; (* define and call a function for concatenating riktnummer and ort into a hash *)
  let data_json = `Assoc (* define json to query scb *)
                   [("query",
                     `List
                      [`Assoc
                        [("code", `String "Region");
                         ("selection",
                          `Assoc [("filter", `String "all"); ("values", `List [`String "*"])])];
                       `Assoc
                        [("code", `String "ContentsCode");
                         ("selection",
                          `Assoc
                           [("filter", `String "item"); ("values", `List [`String "ME0104B8"])])];
                       `Assoc
                        [("code", `String "Tid");
                         ("selection",
                          `Assoc [("filter", `String "all"); ("values", `List [`String "*"])])]]);
                    ("response", `Assoc [("format", `String "json")])] in
  let data_resp_string = Yojson.Basic.to_string data_json in (* convert json to string *)
  let rc, data_resp = post ~content_type:"Application/json;charset=utf-8" "http://api.scb.se/OV0104/v1/doris/sv/ssd/START/ME/ME0104/ME0104D/ME0104T4" (Yojson.Basic.to_string data_json) in (* perform query *)
  let stripped_data_resp = String.sub data_resp 3 (String.length data_resp - 3) in (* strip out 3 characters to reach response *)
  let data = (Yojson.Basic.from_string stripped_data_resp) |> member "data" |> to_list in (* convert to json and get the data member *)
  let years = SS.empty in (* create an empty set *)
  let years = List.fold_right SS.add (List.map (fun a -> List.nth a 1) (List.map (fun json -> member "key" json |> to_list |> filter_string) data)) years in (* put all years in the set *)
  SS.iter (fun year -> let filtered_year_data = List.filter (fun json -> let key = member "key" json |> to_list |> filter_string in (* iterate over the years, and for each year, filter out those entries with valid percentage and correct year *)
                                                                         let value = List.nth (member "values" json |> to_list |> filter_string) 0 in
                                                                         let fyear = List.nth key 1 in
                                                                         (year = fyear) & (value <> "..")) data in
                       let rikt_year_val = List.map (fun json ->let key = member "key" json |> to_list |> filter_string in (* construct a triple out of each data point *)
                                                                let value = member "values" json |> to_list |> filter_string in
                                                                let year = List.nth key 1 in
                                                                let rikt = List.nth key 0 in
                                                                let v = float_of_string (List.nth value 0) in
                                                                (rikt, year, v)) filtered_year_data in
                       let sorted_percentage = List.rev (List.sort (fun t1 t2 -> compare (match t1 with (* sort the triple according to percentage value *)
                                                                                          | (_,_,vt1) -> vt1) (match t2 with
                                                                                                               |(_,_,vt2) -> vt2)
                                                                   ) rikt_year_val) in
                       let max_percentage = match (List.nth sorted_percentage 0) with | (_,_,vt1) -> vt1 in
                       let orter = List.map (fun triple -> (match triple with (* filter all data points with max percentage, and get only the ort *)
                                                            |(rikt,_,_) -> Hashtbl.find riktnummer_orter rikt))  (List.filter (fun triple -> let percentage = (match triple with
                                                                                                                                                              | (_,_,vt1) -> vt1) in
                                                                                                                                            percentage = max_percentage)  rikt_year_val) in
                       let string_of_orter = String.concat "," orter in
                       Printf.printf  "%s %.1f%% %s\n" year max_percentage string_of_orter
          ) years
