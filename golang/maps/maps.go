package main

import "fmt"

func main() {

    m := make(map[string]int)

    m["key_1"] = 7
    m["key_2"] = 13

    fmt.Println(fmt.Sprintf("map: %T %v", m, m))

    value_1 := m["key_1"]
    fmt.Println("value_1: ", value_1)

    fmt.Println("len:", len(m))

    delete(m, "key_2")
    fmt.Println("map:", m)

    _, present := m["key_2"]
    fmt.Println("present:", present)

    n := map[string]int{"foo": 1, "bar": 2}
    fmt.Println("map:", n)

    o := map[string]int{
      "food": 1,
      "good": 2,
    }
    fmt.Println("omap:", o)
}
