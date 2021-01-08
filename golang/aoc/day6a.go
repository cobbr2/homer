package main

import (
  "bufio"
  "fmt"
  "os"
  "io"
)

type reader struct {
  scanner *bufio.Scanner
}

func NewReader(fd io.Reader) (r reader, err error) {
  r.scanner = bufio.NewScanner(fd)
  return
}

type AnswerSet struct {
  kv map[rune]bool
}

func NewAnswerSet() (a AnswerSet) {
  a.kv = make(map[rune]bool)
  return
}

func (a *AnswerSet)count() (c int) {
  return len(a.kv)
}

func (a *AnswerSet)add(v rune) {
  a.kv[v] = true
  return
}

type Group struct {
  people []AnswerSet
  merged_answers AnswerSet
  is_merged bool
}

func (g *Group)merged() (*AnswerSet) {
  if !g.is_merged {
    g.merged_answers = NewAnswerSet()
    for _,a := range(g.people) {
      for k,v := range(a.kv) {
        g.merged_answers.kv[k] = v
      }
    }
  }
  return &(g.merged_answers)
}

func (g *Group)push(a AnswerSet) {
  g.is_merged = false
  g.people = append(g.people,a)
}

func (g *Group)count() (int) {
  return g.merged().count()
}

func (g *Group)len() (l int) {
  return len(g.people)
}

func readLine(line string) (a AnswerSet) {
  a = NewAnswerSet()
  for _, letter := range(line) {
    a.add(letter)
  }
  return
}

func append_group(groups []Group, group Group) ([]Group, Group) {
  if group.len() > 0 {
    groups = append(groups,group)
    group = Group{}
  }

  return groups, group
}

func readGroups(rdr reader) (groups []Group, err error) {
  var group Group
  for rdr.scanner.Scan() {
    line := rdr.scanner.Text()

    if len(line) == 0 {
      groups,group = append_group(groups,group)
      continue
    }
    answerSet := readLine(line)
    group.push(answerSet)
  }
  groups,group = append_group(groups,group)
  return
}

func main() {

  r,_ := NewReader(os.Stdin)
  groups, _ := readGroups(r)

  var yes int
  for _, group := range(groups) {
    yes += group.count()
  }
  fmt.Println(yes)
}
