package main

import (
  "bufio"
  "fmt"
  "os"
  "strconv"
)

func readem() []int64 {
  list := make([]int64,0,20)

  scanner := bufio.NewScanner(os.Stdin)
  for scanner.Scan() {
    var entry int64
    entry, err := strconv.ParseInt(scanner.Text(),10,64)
    if err != nil {
      fmt.Println(err)
      continue
    }
    list = append(list, entry)
  }

  return list
}

func findpair(list []int64, sum int64) (a,b int64, err error) {
  err = nil
  for ix := 0; ix < len(list); ix++ {
    for jx := ix; jx < len(list); jx++ {
      a,b = list[ix], list[jx]
      if a + b == sum {
        return
      }
    }
  }
  err = fmt.Errorf("No pair sums to %d", sum)

  return
}

func main() {
  numbers := readem()
  fmt.Println("Read",len(numbers),"numbers")

  a,b,err := findpair(numbers, 2020)

  if err == nil {
    fmt.Println(a * b)
  } else {
    fmt.Println(err)
  }
}
