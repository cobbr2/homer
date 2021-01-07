package main

import "fmt"

func main() {

    messages := make(chan string)

    go func() { messages <- string(0x40) }()

    msg := <-messages
    fmt.Println(msg)
}
