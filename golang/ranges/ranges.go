package main

import (
  "fmt"
  "io/ioutil"
  "regexp"
)

var digitRegexp = regexp.MustCompile("[0-9]+")

func CopyDigits(filename string) (c []byte, err error) {
    b, err := ioutil.ReadFile(filename)
    if err != nil {
      fmt.Println("Error: ", err)
      return c, err
    }
    b = digitRegexp.Find(b)
    c = append(c,b...)
    return c, err
}

func main() {

    nums := make([]int,0)
    nums = append(nums,2, 3, 4)
    sum := 0
    for _, num := range nums {
        sum += num
    }
    fmt.Println("sum:", sum)

    for i, num := range nums {
        if num == 3 {
            fmt.Println("index:", i)
        }
    }

    kvs := map[string]string{"a": "apple", "b": "banana"}
    for k, v := range kvs {
        fmt.Printf("%s -> %s\n", k, v)
    }

    for k := range kvs {
        fmt.Println("key:", k)
    }

    for i, c := range "go" {
        fmt.Println(i, c)
    }

    digits, _ := CopyDigits("wackamole.txt")
    fmt.Println(string(digits))
}
