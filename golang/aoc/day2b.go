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

type policy struct {
  needs         rune
  min           int
  max           int
  err           error
}

var policyRegexp = regexp.MustCompile("(\\d+)-(\\d+)\\s+(\\S):\\s+(.*)")

func (r *reader) Nextline() (p policy, password string, done bool) {
  if r.scanner.Scan() {
    result := policyRegexp.FindStringSubmatch(r.scanner.Text())

    if result == nil {
      p = policy{err: fmt.Errorf("Regexes in Go SUCK!")}
    } else {
      min, _ := strconv.ParseInt(result[1],10,32)
      max, _ := strconv.ParseInt(result[2],10,32)
      submatch_3_as_runes := []rune(result[3])
      p = policy{
        needs: submatch_3_as_runes[0],
        min: int(min),
        max: int(max),
      }
      password = result[4]
    }
    return
  } else {
    done = true
    return
  }
}

func (p policy) check(password string) (good bool) {
  if p.err != nil {
    return
  }

  usefulstring := []rune(password)

  if len(usefulstring) < p.max {
    return
  }

  if (usefulstring[p.min-1] == p.needs) != (usefulstring[p.max-1] == p.needs) {
    good = true
  }
  return
}


func main() {

  r,_ := NewReader(os.Stdin)

  var good int
  for {
    policy, password, done := r.Nextline()
    if done {
      break
    }
    if policy.check(password) {
      good++
    }
  }
  fmt.Println(good)
}
