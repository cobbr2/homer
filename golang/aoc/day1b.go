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

func findtriple(list []int64, sum int64) (a,b,c int64, err error) {
  err = nil
  for ix := 0; ix < len(list); ix++ {
    for jx := ix; jx < len(list); jx++ {
      for kx := jx; kx < len(list); kx++ {
        a,b,c = list[ix], list[jx], list[kx]
        if a + b + c == sum {
          return
        }
      }
    }
  }
  err = fmt.Errorf("No pair sums to %d", sum)

  return
}

func main() {
  numbers := readem()
  fmt.Println("Read",len(numbers),"numbers")

  a,b,c,err := findtriple(numbers, 2020)

  if err == nil {
    fmt.Println(a * b * c)
  } else {
    fmt.Println(err)
  }
}
