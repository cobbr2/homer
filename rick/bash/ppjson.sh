ppjson ()
{
    cat ${1:- --} | ruby -rjson -rpp -e "pp JSON.parse(STDIN.read)"
}

splitandppjson ()
{
    cat ${1:- --} | ruby -rjson -rpp -e "pp JSON.parse(STDIN.read)"
}

# For terraform, use `landscape` viz `tf plan | landscape`
