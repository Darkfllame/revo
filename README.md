<div align="center">
<h1>revo</h1>

![written in Zig](https://img.shields.io/badges/written%20in-Zig-orange)

[homepage & docs](https://gills.pages.dev/revo)
| [github](https://github.com/if-not-nil/revo)
| [learn](https://gills.pages.dev/revo/basics)

</div>

**revo** is an expressive, dynamically-typed language that is made to balance semantic freedom and readability.

check out the [homepage](https://gills.pages.dev/revo),
the [basics guide](https://gills.pages.dev/revo/basics/),
and the [blog](https://gills.pages.dev/revo/blog/apples/)

# sections

- [installation](#installing)
- [cli reference](#cli-reference)
  - [development](#development)
  - [credits](#credits)
- [license](#license)

# installing

you will need [zig `0.16.0`](https://ziglang.org/download) to build revo

```bash
git clone https://github.com/if-not-nil/revo && cd revo
zig build -Doptimize=ReleaseFast
cp ./zig-out/bin/revo ~/.local/bin/revo
revo -h
```

binary releases are not yet available

# usage

```bash
usage: revo [options] [script [args...]]

options:
  -e code          run code
  -i               enter interactive mode after executing
  -d               output the last value the program evaluated
  -b               compile script to bytecode (.rvo)
  -o path          output path for -b (default: input with .rvo extension)
  --test           run test blocks
  --bench[n]       run with performance counters ([n] iterations, 1 if not specified)
  --dis            show bytecode disassembly instead of running
  -h, --help       show this help message
  --version        show version

examples:
  revo                           start interactive REPL
  revo script.rv                 run script
  revo -e "1 + 2"                run inline code
  revo -e "1 + 2" -i             run inline code and enter REPL
  revo -b script.rv              compile script to bytecode
  revo -b -o output.rvo script   compile script with custom output path
  revo --bench script.rv         run with performance counters
  revo --dis script.rv           show bytecode disassembly
```

## development

### building

```bash
zig build # debug build
zig build run # debug run (repl implementation is hardcoded to a very simple one)
zig build -Doptimize=ReleaseFast # release build
zig build -Drepl=none # custom repl backend (bestline, readline, libedit, none)
# build C library + auto-generated header
# check zig-out/include/, zig-out/lib/
zig build lib 
```

the default repl backend is the vendored bestline, linked statically. read [build.zig](./build.zig)

**note:** the C library and header are only built with `zig build lib`.
the auto-generated header is always in sync with exported functions, marked with `callconv("c")`

### running tests

```bash
zig build test --summary all -Dtest_filter="some test name filter"
```

### contributing

recommending to a friend is always greatly appreciated. any contributions are welcome!

see [CONTRIBUTING.md](./CONTRIBUTING.md) for more details

## credits

- [bestline](https://github.com/jart/bestline) by Justine Tunney - MIT

**optional repl backends, not vendored but linked dynamically**
- [libedit](https://thrysoee.dk/editline/) - BSD
- [GNU readline](https://tiswww.case.edu/php/chet/readline/rltop.html) - GPLv3

# license

revo is licensed under [MIT.](https://mit-license.org/) see the [LICENSE.txt](./LICENSE.txt) file for details
