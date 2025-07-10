# Tak Perft

Implements [perft] for [Tak] in [Zig].

I made this to learn Zig and to practice low-level optimizations.

[perft]: https://www.chessprogramming.org/Perft
[Tak]: https://ustak.org/play-beautiful-game-tak/
[Zig]: https://ziglang.org/

## Building

1. Install Zig
2. Run `zig build --release=fast`
3. Enjoy the binary at `./zig-out/bin/tak_perft`

## Usage

- `tak_perft <depth:u8> [--tps <tps:str>]`
- If the tps is not provided, we run on the starting 6x6 position.
- You can also run `tak_perft --help` to see the help message.
- Make sure the tps string is provided as a single argument (i.e. surround it with quotes `"`).

## Examples

```sh
$ tak_perft 5
1253506520
$ tak_perft 5 --tps "x8/x8/x8/x8/x8/x8/x8/x8 1 1"
26642455192
$ tak_perft 6 --tps "x5/x5/2S,211C,2C,212S,x/x5/x5 1 7"
28289067995
$ tak_perft --help
=== Tak Perft ===
  -h, --help       Display this message and exit.
  -t, --tps <str>  Optional position given as TPS.
  <u8>             Specify the depth to search.
```

## TPS Parsing

The TPS parsing is a little bit lenient. If the player to
move is not provided, white is assumed. The move number
is also unnecessary since we determine whether it is the opening
based on the number of played stones.

The program only supports sizes 3 to 8 (inclusive).

