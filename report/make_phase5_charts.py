"""Phase 5 team charts. Edit DATA and rerun:
    python3 make_phase5_charts.py
None = not reported. 'extrap' marks drain times that were calculated, not observed."""
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

WORKERS = [1, 5, 20, 100]

# Per teammate: peak queue depth, drain time after load end (s), extrapolated flags, CPU max (%), memory max (%)
DATA = {
    "Ikwo (us-east-1)": {
        "peak": [3490, 3465, 3128, 1435],
        "drain_s": [10440, 2125, 479, 57],
        "extrap": [True, True, False, False],
        "cpu": [0.38, 0.66, 3.80, 14.08],
        "mem": [1.37, 1.56, 1.76, 1.95],
    },
    "Gengyuan (us-west-2)": {
        "peak": [3557, 3521, 3162, 1549],
        "drain_s": [11220, 2220, 485, 52],
        "extrap": [True, True, False, False],
        "cpu": [0.37, 1.52, 5.42, 26.66],
        "mem": [1.37, 1.56, 1.56, 1.76],
    },
    "Weihang": {
        "peak": [3530, 3443, 3010, 1488],
        "drain_s": [10620, 2100, 480, 60],
        "extrap": [True, False, False, False],
        "cpu": [None, 1.2, 3.0, 16.0],
        "mem": [None, 1.5, 1.5, 1.5],
    },
    "Kunal (us-west-2)": {
        # 20 and 100 workers not run; 180 workers reported in the text (no 180 column here)
        "peak": [2870, 2769, None, None],
        "drain_s": [8697, 1668, None, None],
        "extrap": [True, True, False, False],
        "cpu": [2.2, 3.17, None, None],
        "mem": [1.56, 1.37, None, None],
    },
}

names = list(DATA)
x = np.arange(len(WORKERS))
w = 0.8 / len(names)
fig, axes = plt.subplots(1, 3, figsize=(17, 5))

ax = axes[0]
for i, n in enumerate(names):
    peak = [np.nan if v is None else v for v in DATA[n]["peak"]]
    ax.bar(x + i * w - 0.4 + w / 2, peak, w, label=n)
ax.set_xticks(x, [f"{k} worker" + ("" if k == 1 else "s") for k in WORKERS])
ax.set_ylabel("Peak queue depth (messages)")
ax.set_title("Peak queue depth during the 60 s flash sale")
ax.legend(fontsize=8)

ax = axes[1]
for i, n in enumerate(names):
    for j, (v, e) in enumerate(zip(DATA[n]["drain_s"], DATA[n]["extrap"])):
        if v is None:
            continue
        ax.bar(x[j] + i * w - 0.4 + w / 2, v, w, color=f"C{i}",
               hatch="//" if e else None, edgecolor="white" if e else None,
               label=n if j == 0 else None)
ax.set_yscale("log")
ax.set_xticks(x, [f"{k} worker" + ("" if k == 1 else "s") for k in WORKERS])
ax.set_ylabel("Seconds after load ended (log scale)")
ax.set_title("Time for the queue to return to zero\n(hatched = calculated, not observed)")
ax.legend(fontsize=8)

ax = axes[2]
for i, n in enumerate(names):
    cpu = [np.nan if v is None else v for v in DATA[n]["cpu"]]
    mem = [np.nan if v is None else v for v in DATA[n]["mem"]]
    ax.plot(WORKERS, cpu, marker="o", color=f"C{i}", label=f"{n} CPU")
    ax.plot(WORKERS, mem, marker="x", linestyle="--", color=f"C{i}", alpha=0.6, label=f"{n} memory")
ax.set_xscale("log")
ax.set_xticks(WORKERS, [str(k) for k in WORKERS])
ax.set_xlabel("Workers (log scale)")
ax.set_ylabel("Max % of task (0.25 vCPU / 512 MB)")
ax.set_title("Processor CPU and memory (per-minute max)")
ax.legend(fontsize=7)

fig.tight_layout()
fig.savefig("screenshots/team/phase5_team_comparison.png", dpi=130)
print("saved screenshots/team/phase5_team_comparison.png")
