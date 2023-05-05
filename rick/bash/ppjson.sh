ppjson ()
{
  cat ${1:- --} | ruby -rjson -rpp -e "pp JSON.parse(STDIN.read)"
}

splitandppjson ()
{
  cat ${1:- --} | ruby -rjson -rpp -e "pp JSON.parse(STDIN.read)"
}

# For terraform, use `landscape` viz `tf plan | landscape`

json2yaml()
{
  cat ${1:- --} | ruby -ryaml -rjson -e 'puts YAML.dump(JSON.parse(STDIN.read))'
}
