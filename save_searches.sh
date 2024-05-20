#!/usr/bin/env nu

if "search" not-in (curl -s $'http://localhost:5984/' | from json | get features) {
  echo "You need to be running Clouseau, otherwise I can't get the design documents."
  echo "There is a `start_clouseau.sh` script if you've run `install_clouseau.sh`.  Use it."
  return
} else {
  let db = "cbctryout"
  let ddocs = curl -s $'http://localhost:5984/($db)/_all_docs?inclusive_end=false&start_key=%22_design%22&end_key=%22_design0%22&skip=0'
    | from json
    | each { |x| get rows | each { |y| get id } }
    | each { |x| curl -s $'http://localhost:5984/($db)/($x)' | from json }
  { 'database': $db, 'designs': $ddocs } | save -f search_indices.json
}