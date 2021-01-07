package main

import (
  "bufio"
  "fmt"
  "os"
  "io"
  "regexp"
  "sort"
)

type reader struct {
  scanner *bufio.Scanner
}

func NewReader(fd io.Reader) (r reader, err error) {
  r.scanner = bufio.NewScanner(fd)
  return
}

type Plane struct {
  seats [][]bool
}

type Seat struct {
  row           int
  col           int
  descriptor    string
}

func intFromString(str string, first,second rune) (value int, err error) {
  min := 0
  max := 1 << len(str)
  half := max >> 1
  max = max - 1

  //fmt.Println("Start: min",min,"max",max,"half",half)

  for _, dir := range(str) {
    switch dir {
    case first:
      max = max - half
    case second:
      min = min + half
    default:
      err = fmt.Errorf("Unrecognized direction %s in descriptor %s with first %s and second %s", dir,str,first,second)
      return
    }
    half = half >> 1
    //fmt.Println("On",dir,"min",min,"max",max,"half",half)
  }
  if min != max || half != 0 {
    err = fmt.Errorf("Descriptor %s did not converge. Min %d max %d half %d",str,min,max,half)
    return
  }
  value = min

  return
}

const COLS_PER_ROW int = 8
func (seat *Seat) colsPerRow() int {
  return COLS_PER_ROW
}

func (seat *Seat) number() int {
  if len(seat.descriptor) == 0 {
    return -1
  }
  return seat.colsPerRow() * seat.row + seat.col
}

var splitter = regexp.MustCompile("^([FB]{7,7})([LR]{3,3})$")

func seatFromDescriptor(descriptor string) (seat Seat, err error) {
  result := splitter.FindStringSubmatch(descriptor)
  if result == nil {
    err = fmt.Errorf("descriptor out of spec: %s", descriptor)
    return
  }
  var row, col int
  if row, err = intFromString(result[1], 'F','B'); err != nil {
    return
  }
  if col, err = intFromString(result[2], 'L','R'); err != nil {
    return
  }
  seat.descriptor = descriptor
  seat.row = row
  seat.col = col

  return
}

func readSeats(rdr reader) (seats []Seat, err error) {
  for rdr.scanner.Scan() {
    line := rdr.scanner.Text()

    var seat Seat
    seat, err = seatFromDescriptor(line)
    if err != nil {
      fmt.Println(err)
      continue
    }
    fmt.Println("Seat", seat, seat.number())
    seats = append(seats, seat)
  }
  return
}

type BySeat []Seat

func (a BySeat) Len() int           { return len(a) }
func (a BySeat) Swap(i, j int)      { a[i], a[j] = a[j], a[i] }
func (a BySeat) Less(i, j int) bool { return a[i].number() < a[j].number() }

func main() {
  r,_ := NewReader(os.Stdin)
  passes, _ := readSeats(r)

  var sortable []int

  sorted = sort.Sort(BySeat(passes))

  var last Seat
  for seat := range(sorted) {
    if last == nil {
      last = seat
      continue
    }
    if last.number() + 1 < seat.number() {
      fmt.Println("My seat is", last.number() + 1)
    }
  }
}
