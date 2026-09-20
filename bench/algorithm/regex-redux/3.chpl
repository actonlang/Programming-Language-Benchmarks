/* The Computer Language Benchmarks Game
   https://salsa.debian.org/benchmarksgame-team/benchmarksgame/

   contributed by Engin Kayraklioglu
   derived from the converted regex-dna Chapel version by Ben Harshbarger
   which was derived from the GNU C++ RE2 version by Alexey Zolotov
   removed parallelization
*/

use IO, Regex;

config const n = "25000_in";

proc main(args: [] string) {
  var variants = [
    b"agggtaaa|tttaccct",
    b"[cgt]gggtaaa|tttaccc[acg]",
    b"a[act]ggtaaa|tttacc[agt]t",
    b"ag[act]gtaaa|tttac[agt]ct",
    b"agg[act]taaa|ttta[agt]cct",
    b"aggg[acg]aaa|ttt[cgt]ccct",
    b"agggt[cgt]aa|tt[acg]accct",
    b"agggta[cgt]a|t[acg]taccct",
    b"agggtaa[cgt]|[acg]ttaccct"
  ];

  var subst = [
    (b"tHa[Nt]", b"<4>"), (b"aND|caN|Ha[DS]|WaS", b"<3>"),
    (b"a[NSt]|BY", b"<2>"), (b"<[^>]*>", b"|"), (b"\\|[^|][^|]*\\|", b"-")
  ];

  var data: bytes;
  const file = open(n, ioMode.r),
    reader = file.reader(locking=false);
  reader.readAll(data);
  const initLen = data.size;

  // remove newlines
  data = data.replace(new regex(b">.*\n|\n"), b"");

  var results: [variants.domain] int;

  // count patterns
  for (pattern, result) in zip(variants, results) do
    for m in (new regex(pattern)).matches(data) do
      result += 1;

  // print results
  for (p,r) in zip(variants, results) do
    writeln(p, " ", r);
  writeln();

  writeln(initLen);
  writeln(data.size);
  for (f, r) in subst do
     data = data.replace(new regex(f), r);
  writeln(data.size);
}
