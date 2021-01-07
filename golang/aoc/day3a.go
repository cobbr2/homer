package main

import (
  "bufio"
  "fmt"
  "os"
  "io"
)

type Reader struct {
  scanner *bufio.Scanner
}

func NewReader(fd io.Reader) (r Reader, err error) {
  r.scanner = bufio.NewScanner(fd)
  return
}

type Topo struct {
  trees         [][]bool
}

func (t *Topo) getXY(row_ix, col_ix int) bool {
  col_ix = col_ix % len(t.trees[0])
  return t.trees[row_ix][col_ix]
}

func Readtopo(rdr Reader) (t Topo, err error) {
  row_ix := 0
  t.trees = make([][]bool,0)
  for rdr.scanner.Scan() {
    cols := make([]bool,0)
    for _, char := range(rdr.scanner.Text()) {
      value := false
      if char == '#' {
        value = true
      }
      cols = append(cols,value)
    }
    t.trees = append(t.trees,cols)
    row_ix++
  }
  return
}

func (topo *Topo) countTrees(row_iv, col_iv int) (trees int) {
  col_ix := 0
  for row_ix := 0; row_ix < len(topo.trees); row_ix += row_iv {
    if topo.getXY(row_ix,col_ix) {
      trees++
    }
    col_ix += col_iv
  }
  return
}

func main() {
  r,_ := NewReader(os.Stdin)
  topo,_ := Readtopo(r)

  a := [][]uint8{
    {0, 1, 2, 3},
    {4, 5, 6, 7},
  }

  slopes := [][]int{
    {1,1},
    {1,3},
    {1,5},
    {1,7},
    {2,1},
  }

  mult := 1
  for _,slope := range(slopes) {
    mult *= topo.countTrees(slope[0],slope[1])
  }

  fmt.Println(mult)
}
