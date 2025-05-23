import std/options

proc main() =
  echo "Testing options in Nim 2.2.4"
  
  let someVal = some(42)
  echo "someVal: ", someVal
  
  # Check method syntax
  echo "someVal.isSome: ", someVal.isSome
  if someVal.isSome:
    echo "someVal.get: ", someVal.get
  
  # Check function syntax
  echo "isSome(someVal): ", isSome(someVal)
  if isSome(someVal):
    echo "get(someVal): ", get(someVal)
  
  let noneVal = none(int)
  echo "noneVal: ", noneVal
  echo "noneVal.isNone: ", noneVal.isNone
  echo "isNone(noneVal): ", isNone(noneVal)

main()