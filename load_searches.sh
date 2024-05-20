#!/usr/bin/env nu

def main [password: string] {
  if "search" not-in (curl -s $'http://localhost:5984/' | from json | get features) {
    echo "You need to be running Clouseau, otherwise I can't get the design documents."
    echo "There is a `start_clouseau.sh` script if you've run `install_clouseau.sh`.  Use it."
    return
  } else {
    if ("search_indices.json" | path exists) {
      let data = open search_indices.json
      let db = $data.database
      echo $'Loading design documents into ($db).'
      $data | get designs | each { |x| curl -X PUT $'http://localhost:5984/($db)/($x._id)' --user $'admin:($password)' -H "Content-Type: application/json" -d ($x | to json) }
    } else {
      echo "You need to run `save_searches.sh` first."
    }
  }
}