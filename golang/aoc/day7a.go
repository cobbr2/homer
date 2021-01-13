package main

import (
  "bufio"
  "fmt"
  "os"
  "io"
  "regexp"
  "strconv"
  basicgraph "github.com/yourbasic/graph"
)

type reader struct {
  scanner *bufio.Scanner
}

func NewReader(fd io.Reader) (r reader, err error) {
  r.scanner = bufio.NewScanner(fd)
  return
}

type Constraint struct {
  container      string
  vertex         int
  requires       map[string]int
}

func makeConstraint(name string, requirements ...string) (constraint Constraint) {
  constraint.container = name
  constraint.requires = make(map[string]int)

  for ix := 0; ix < len(requirements); ix += 2 {
    bag := requirements[ix + 1]
    number,_ := strconv.ParseInt(requirements[ix],10,32)
    constraint.requires[bag] = int(number)
  }
  return
}

/*
light red bags contain 1 bright white bag, 2 muted yellow bags.
dark orange bags contain 3 bright white bags, 4 muted yellow bags.
bright white bags contain 1 shiny gold bag.
muted yellow bags contain 2 shiny gold bags, 9 faded blue bags.
shiny gold bags contain 1 dark olive bag, 2 vibrant plum bags.
dark olive bags contain 3 faded blue bags, 4 dotted black bags.
vibrant plum bags contain 5 faded blue bags, 6 dotted black bags.
faded blue bags contain no other bags.
dotted black bags contain no other bags.
*/

var terminalRegexp = regexp.MustCompile("(?P<outside>.*) bags contain no other bags.")
var containerRegexp = regexp.MustCompile("(?P<outside>.*?) bags contain ")
var insideRegexp = regexp.MustCompile(" *(?P<number>[[:digit:]]+) (?P<inside>.*?) bags{0,1}[,.]")

func parseConstraints(descriptor string) (constraint Constraint, err error) {
  result := terminalRegexp.FindStringSubmatch(descriptor)
  if result != nil {
    constraint = makeConstraint(result[1])
    return
  }
  result = containerRegexp.FindStringSubmatch(descriptor)
  if result == nil {
    err = fmt.Errorf("Unrecognized line: %s", descriptor)
    return
  }

  container := result[1]

  remainder := descriptor[len(result[0]):]

  //fmt.Printf("container %s, rest: %v\n", container, remainder)

  requires := make([]string,0)

  results := insideRegexp.FindStringSubmatch(remainder)
  for results != nil {
    requires = append(requires,results[1], results[2])
    remainder = remainder[len(results[0]):]
    results = insideRegexp.FindStringSubmatch(remainder)
  }

  //fmt.Printf("container %s, requires %d: %v\n", container, len(requires), requires)

  constraint = makeConstraint(container, requires...)

  return
}

func readConstraints(rdr reader) (constraints []Constraint, err error) {
  constraints = make([]Constraint,0)

  for rdr.scanner.Scan() {
    line := rdr.scanner.Text()

    constraint, _ := parseConstraints(line)
    constraints = append(constraints,constraint)
  }
  return
}

// basiggraph doesn't work by label, so we use the Constraints as
// our map from name to vertex, and build our own array in the opposite diretion
type GoBags struct {
  name        []string  // indexed by vertex #
  node        map[string]int
  graph       *basicgraph.Immutable
}

// Building graph in contained -> contains order so BFS works nicely.
func GraphFromConstraints(constraints []Constraint) (g GoBags) {
  g.name = make([]string,len(constraints))
  g.node = make(map[string]int,len(constraints))

  for ix, constraint := range(constraints) {
    g.node[constraint.container] = ix
    g.name[ix] = constraint.container
  }

  graph := basicgraph.New(len(constraints))
  for to_vertex, constraint := range(constraints) {
    for required_bag,_ := range(constraint.requires) {
      from_vertex := g.node[required_bag]
      graph.Add(from_vertex, to_vertex)
    }
  }
  //fmt.Println("Built graph: ", graph)

  g.graph = basicgraph.Sort(graph)
  return
}


func main() {
  r,_ := NewReader(os.Stdin)
  constraints, _ := readConstraints(r)

  //fmt.Printf("Read %d constraints:\n %v\n",len(constraints),constraints)

  gobag := GraphFromConstraints(constraints)

  //fmt.Printf("Constructed cost-free immutable graph: %v\n",gobag.graph)

  allowed := make([]string,0)

  basicgraph.BFS(gobag.graph, gobag.node["shiny gold"], func (from, to int, _ int64) {
    fmt.Printf("From %d to %d (%s to %s)\n", from, to, gobag.name[from], gobag.name[to])
    allowed = append(allowed,gobag.name[to])
  })

  fmt.Println("Allowed Bags:", allowed)
  fmt.Println("Count:", len(allowed))
}
