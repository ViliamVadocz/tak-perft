# Tak Perft

Implements [perft] for [Tak] in [Zig] (version 0.14).

I made this to learn Zig and to practice low-level optimizations.

[perft]: https://www.chessprogramming.org/Perft
[Tak]: https://ustak.org/play-beautiful-game-tak/
[Zig]: https://ziglang.org/

## Building

1. Install Zig
2. Run `zig build --release=fast`
3. Enjoy the binary at `./zig-out/bin/tak-perft`

## Usage

- `tak-perft <depth:u8> [--tps <tps:str>] [--split]`
- If the tps is not provided, we run on the starting 6x6 position.
- You can also run `tak-perft --help` to see the help message.
- Make sure the tps string is provided as a single argument (i.e. surround it with quotes `"`).
- `--split` prints out the number of positions per move.

## Examples

```sh
$ tak-perft 5
1253506520
$ tak-perft 5 --tps "x8/x8/x8/x8/x8/x8/x8/x8 1 1"
26642455192
$ tak-perft 6 --tps "x5/x5/2S,211C,2C,212S,x/x5/x5 1 7"
28289067995
$ tak-perft --help
=== Tak Perft ===
  -h, --help       Display this message and exit.
  -t, --tps <str>  Optional position given as TPS.
  -s, --split      Print positions per action.
  <u8>             Specify the depth to search.
$ tak-perft --tps "2S,1S,2S,1S,2S,1S,2S,1S/1S,2S,1S,2S,1S,2S,1S,2S/2S,1S,2S,1S,2S,1S,2S,1S/1S,2S,1S,111222111C,x,2S,1S,2S/2S,1S,2S,x,222111222C,1S,2
S,1S/1S,2S,1S,2S,1S,2S,1S,2S/2S,1S,2S,1S,2S,1S,2S,1S/1S,2S,1S,2S,1S,2S,1S,2S 2 40" 6 --split
e5       : 2304218
Se5      : 65349
d4       : 2304218
Sd4      : 65349
Ce5      : 117959
Cd4      : 117959
e6-      : 3481715
f5<      : 3524313
c4>      : 3481715
8e4<     : 896009
7e4<     : 857030
6e4<     : 809486
5e4<     : 849725
4e4<     : 794712
3e4<     : 734923
2e4<     : 571153
e4<      : 564462
8e4+     : 896009
7e4+     : 857030
6e4+     : 809486
5e4+     : 849725
4e4+     : 794712
3e4+     : 734923
2e4+     : 571153
e4+      : 564462
d3+      : 3524313
e4>*     : 9582631
e4-*     : 9582631
8e4<71*  : 4608114
7e4<61*  : 4869269
6e4<51*  : 5108974
5e4<41*  : 6145020
4e4<31*  : 6531275
3e4<21*  : 6919726
2e4<11*  : 6232986
8e4+71*  : 4608114
7e4+61*  : 4869269
6e4+51*  : 5108974
5e4+41*  : 6145020
4e4+31*  : 6531275
3e4+21*  : 6919726
2e4+11*  : 6232986
131138098
```

## TPS Parsing

The TPS parsing is a little bit lenient. If the player to
move is not provided, white is assumed. The move number
is also unnecessary since we determine whether it is the opening
based on the number of played stones.

The program only supports sizes 3 to 8 (inclusive).

