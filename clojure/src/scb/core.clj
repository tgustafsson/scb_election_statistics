(ns scb.core
  (:gen-class)
  (:require [clj-http.client :as client])
  (:require [cheshire.core :refer :all])
  )

(def query-url "http://api.scb.se/OV0104/v1/doris/sv/ssd/START/ME/ME0104/ME0104D/ME0104T4")

(defn read-meta-data [query] (with-open [rdr (clojure.java.io/reader query)]
                               (parse-string (clojure.string/join "" (line-seq rdr)) true)))

(defn read-data [query-url]
  (client/post query-url
               {:body (generate-string {:query [
                                                {:code "Region" :selection {:filter "all" :values ["*"]}},
                                                {:code "ContentsCode" :selection {:filter "item" :values ["ME0104B8"]}},
                                                {:code "Tid" :selection {:filter "all" :values ["*"]}}
                                                ],
                                        :response  {:format "json"}
                                        }
                                       )}))
(defn parse-number
  "Reads a number from a string. Returns nil if not a number."
  [s]
  (if (re-find #"^-?\d+\.?\d*$" s)
    (read-string s)))

(defn my-get-year [data y]
  (let [sorted-by-value (sort-by #(%1 :value) (filter #(= (%1 :year) y) data))
        rn (map #(%1 :riktnummer) (filter #(= (%1 :value) ((last sorted-by-value) :value)) sorted-by-value))]  
    {:value ((last sorted-by-value) :value) :riktnummer rn :year y}
    )
  )

(defn -main
  "I don't do a whole lot ... yet."
  [& args]
  (let [meta (read-meta-data query-url)
	data (get (parse-string (clojure.string/join "" (rest (get (read-data query-url) :body))) true) :data) ; get the body of the post result, strip out the first char, and convert to json, and get the data part of the json
        variables-to-keywords  (map #(keyword %1) (get (first (get meta :variables)) :values))
        value-texts (get (first (get meta :variables)) :valueTexts)
	assoc-riktnummer-ort (zipmap variables-to-keywords value-texts)
	year-value-riktnummer (map (fn [a] {:year (second (get a :key)) :value (first (get a :values)) :riktnummer (first (get a :key))}) data)
	years (set (map (fn [a] (a :year)) year-value-riktnummer))
        largest (sort-by #(%1 :year) (map (partial my-get-year year-value-riktnummer) (seq years)))
	]
    (doseq [item largest] (print (format "%s %s%% %s\n" (item :year) (item :value) (clojure.string/join ", " (map #(assoc-riktnummer-ort (keyword %1)) (item :riktnummer))))))
    )
  )

