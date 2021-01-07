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

func (p *Passport)nFields() int {
  return len(p.kv)
}

type Validator func(string, bool) bool

func vallen(str string, min,max int) (b bool) {
  return (len(str) >= min) && (len(str) <= max)
}

func numberBetween(str string, min,max int) (b bool) {
  toolong,_ := strconv.ParseInt(str,10,32)
  number := int(toolong)
  return number >= min && number <= max
}

func match(pattern, str string) (matched bool) {
  matched, _ = regexp.MatchString(pattern, str)
  return
}

var heightRegexp = regexp.MustCompile("(\\d+)(cm|in)")

/*
    If cm, the number must be at least 150 and at most 193.
    If in, the number must be at least 59 and at most 76.
*/
func validateHeight(val string) (ok bool) {
  result := heightRegexp.FindStringSubmatch(val)
  if result == nil {
    return
  }
  toolong,_ := strconv.ParseInt(result[1],10,32)
  height := int(toolong)

  switch result[2] {
  case "in":
    return height >= 59 && height <= 76
  case "cm":
    return height >= 150 && height <= 193
  }
  return
}

func (pass *Passport) valid() (valid bool) {
  //fmt.Println("Validating: ", pass)

  validations := map[string]Validator  {
    "byr": func(val string, prs bool) bool { return prs && vallen(val,4,4) && numberBetween(val,1920,2002) },
    "iyr": func(val string, prs bool) bool { return prs && vallen(val,4,4) && numberBetween(val,2010,2020) },
    "eyr": func(val string, prs bool) bool { return prs && vallen(val,4,4) && numberBetween(val,2020,2030) },
    "hgt": func(val string, prs bool) bool { return prs && validateHeight(val)},
    "hcl": func(val string, prs bool) bool { return prs && match("^#[[:xdigit:]]{6,6}$", val) },
    "ecl": func(val string, prs bool) bool { return prs && match("^(amb|blu|brn|gry|grn|hzl|oth)$", val)},
    "pid": func(val string, prs bool) bool { return prs && match("^[[:digit:]]{9,9}$", val) },
    "cid": func(val string, prs bool) bool { return true },
  }

  for k,validator := range(validations) {
    value, present := pass.kv[k]

    if !validator(value, present) {
      // fmt.Println(k, "value", value, "is invalid")
      return false
    }
  }
  return true
}

var kvRegexp = regexp.MustCompile("(\\S+):(\\S+)\\s*")

func readPassports(rdr reader) (passports []Passport, err error) {
  passport := NewPassport()

  var nonempty bool
  for rdr.scanner.Scan() {
    line := rdr.scanner.Text()

    if len(line) == 0 {
      if passport.nFields() > 0 {
        // fmt.Println("Read passport:", passport)
        passports = append(passports,passport)
        passport = NewPassport()
        nonempty = false
      }
      continue
    }

    matches := kvRegexp.FindAllStringSubmatch(line, -1)

    for _, match := range(matches) {
      passport.kv[match[1]] = match[2]
    }
    nonempty = true
  }
  if nonempty {
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
      // fmt.Println("Good:", passport.kv["pid"])
      good++
    }
  }
  fmt.Println(good)
}
