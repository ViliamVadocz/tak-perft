import re
from pathlib import Path

import pandas as pd
import matplotlib.pyplot as plt

TWO_WHITESPACE_PATTERN = re.compile(r"\s\s+")

def get_paths(directory: Path) -> list[Path]:
    return sorted(directory.rglob("*.bench"))

def parse_bench_file(path: Path) -> pd.DataFrame:
    with open(path, "r") as f:
        lines = filter(lambda x: x, (line.strip() for line in f.readlines()))
    header = next(lines)
    cols = re.split(TWO_WHITESPACE_PATTERN, header)
    _ = next(lines) # separator line

    records = []
    for line in lines:
        parts = re.split(TWO_WHITESPACE_PATTERN, line)
        assert len(parts) == len(cols)
        rec = dict(zip(cols, parts))
        records.append(rec)

    return convert_df(pd.DataFrame(records))

def convert_df(df: pd.DataFrame) -> pd.DataFrame:
    df = df.rename(columns={
        'runs': 'runs',
        'total time': 'total_time_s',
        'time/run (avg ± σ)': 'time_per_run',
        'p75': 'p75',
        'p99': 'p99',
        'p995': 'p995',
    })
    df['benchmark'] = df['benchmark'].str.strip()
    df['runs'] = df['runs'].astype(int)
    df['total_time_s']      = df['total_time_s'].apply(parse_time)
    df['time_per_run_s']    = df['time_per_run'].str.split('±').str[0].apply(parse_time)
    df['p75_s']             = df['p75'].apply(parse_time)
    df['p99_s']             = df['p99'].apply(parse_time)
    df['p995_s']            = df['p995'].apply(parse_time)
    return df[['benchmark','runs','total_time_s','time_per_run_s','p75_s','p99_s','p995_s']]

TIME_UNITS = {
    "s":  1.0,
    "ms": 1e-3,
    "us": 1e-6,
    "ns": 1e-9,
}

TIME_PATTERN = r"(?:(\d+)m)?(\d+(?:\.\d+)?)([mun]?s)"

def parse_time(s: str) -> float:
    """
    Turn a string like '35ns', '1.047ms', '4.488s' or '1m35.334s' into seconds (float).
    If no unit suffix, assume seconds.
    """
    m = re.match(TIME_PATTERN, s.strip())
    assert m
    mins, val, unit = m.groups()
    total = float(val) * TIME_UNITS[unit]
    if mins: total += int(mins) * 60.0
    return total

def plot_times(wide: pd.DataFrame):
    """
    Plot raw average time per benchmark over commits.
    """
    plt.figure(figsize=(10,6))
    for bench in wide.index:
        plt.plot(wide.columns, wide.loc[bench], marker='o', label=bench)
    plt.xlabel('Commit')
    plt.ylabel('Avg time/run (s)')
    plt.title('Benchmark times over commits')
    plt.xticks(rotation=45, ha='right')
    plt.legend(fontsize='small', loc='best')
    plt.tight_layout()
    plt.savefig("times.png")

def plot_improvements(wide: pd.DataFrame):
    """
    Compute percent change between successive columns and plot.
    """
    # pct change: (new - old) / old * 100
    pct = wide.pct_change(axis=1) * 100
    plt.figure(figsize=(10,6))
    for bench in pct.index:
        plt.plot(pct.columns[1:], pct.loc[bench].iloc[1:], marker='o', label=bench)
    plt.axhline(0, color='gray', linestyle='--')
    plt.xlabel('Commit')
    plt.ylabel('Pct improvement relative to previous (%)')
    plt.title('Benchmark improvements per commit')
    plt.xticks(rotation=45, ha='right')
    plt.legend(fontsize='small', loc='best')
    plt.tight_layout()
    plt.savefig("improvements.png")


if __name__ == "__main__":
    paths = get_paths(Path("./benches/"))
    all_data = []
    for path in paths:
        df = parse_bench_file(path)
        df = df.set_index("benchmark")
        s = df["time_per_run_s"].rename(path.stem)
        all_data.append(s)
    wide = pd.concat(all_data, axis=1)

    plot_times(wide)
    plot_improvements(wide)
