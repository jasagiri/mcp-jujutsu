import std/tables

proc main() =
  echo "Testing tables in Nim 2.2.4"
  
  var t = initTable[string, int]()
  t["one"] = 1
  t["two"] = 2
  
  echo "Table length: ", t.len
  
  echo "Direct iteration over table:"
  for k, v in t:
    echo "  - ", k, ": ", v

main()