package main

import (
  "bufio"
  "fmt"
  "os"
  "io"
  "regexp"
  "strconv"
)

type reader struct {
  scanner *bufio.Scanner
}

func NewReader(fd io.Reader) (r reader, err error) {
  r.scanner = bufio.NewScanner(fd)
  return
}

type Passport struct {
  kv map[string]string
}

func NewPassport() (pass Passport) {
  pass.kv = make(map[string]string)
  return
}

func length(str,min,max) (b bool) {
  return (len(str) >= min) && (len(str) <= max)
}

//func numberBetween(str,min,max) (b bool) {
//  number := strconv.parseInt(str,10,32)
//  return number >= min && number <= max
//}

func (pass *Passport) valid() (valid bool) {
  validations := map[string]interface{} {
    "byr": func(val,prs) bool { return prs && length(val,prs,4,4) && numberBetween(val,prs,1920,2002) },
    "iyr": func(val,prs) bool { return prs && length(val,prs,4,4) && numberBetween(val,prs,2010,2020) },
    "eyr": func(val,prs) bool { return true },
    "hgt": func(val,prs) bool { return true },
    "hcl": func(val,prs) bool { return true },
    "ecl": func(val,prs) bool { return true },
    "pid": func(val,prs) bool { return true },
    "cid": func(_,_) bool { return true },
    }

  for k,validator := range(validations) {
    value, present := pass.kv[k]

    if !validator(value, present) {
      return false
    }
  }
  return true
}

var kvRegexp = regexp.MustCompile("(\\S+):(\\S+)\\s*")

func readPassports(rdr reader) (passports []Passport, err error) {
  passport := NewPassport()

  var readany bool
  for rdr.scanner.Scan() {
    readany = true
    line := rdr.scanner.Text()

    if len(line) == 0 {
      passports = append(passports,passport)
      passport = NewPassport()
      continue
    }

    matches := kvRegexp.FindAllStringSubmatch(line, -1)

    for _, match := range(matches) {
      passport.kv[match[1]] = match[2]
    }
  }
  if readany {
    passports = append(passports,passport)
  }
  return
}

func main() {

  r,_ := NewReader(os.Stdin)
  passports, _ := readPassports(r)

  var good int
  for _, passport := range(passports) {
    if passport.valid() {
      good++
    }
  }
  fmt.Println(good)
}
