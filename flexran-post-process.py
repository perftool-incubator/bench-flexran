#!/usr/bin/env python3
# -*- mode: python; indent-tabs-mode: nil; python-indent-level: 4 -*-
# vim: autoindent tabstop=4 shiftwidth=4 expandtab softtabstop=4 filetype=python

import argparse
import json
import os
import re
import sys
from pathlib import Path

TOOLBOX_HOME = os.environ.get("TOOLBOX_HOME")
if TOOLBOX_HOME:
    sys.path.append(str(Path(TOOLBOX_HOME) / "python"))

from toolbox.cdm_metrics import CDMMetrics
from toolbox.fileio import open_read_text_file


def main():
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--test-file", default="")
    parser.add_argument("--fec-mode", default=None)
    parser.add_argument("--usr1", default=None)
    parser.add_argument("--usr2", default=None)
    parser.add_argument("--usr3", default=None)
    parser.add_argument("--usr4", default=None)
    parser.add_argument("--usr5", default=None)
    parser.add_argument("--log-test", default=None)
    args, _ = parser.parse_known_args()

    log_test = args.log_test

    times = {}
    for name in ("begin", "end"):
        with open(f"{name}.txt") as f:
            times[name] = int(float(f.read().strip()) * 1000)

    primary_metric = "GNB_DL_FEC_LINK-AVG"

    ul_min_desc = {"source": "flexran", "class": "count", "type": "GNB_UL_FEC_LINK-MIN"}
    ul_avg_desc = {"source": "flexran", "class": "count", "type": "GNB_UL_FEC_LINK-AVG"}
    ul_max_desc = {"source": "flexran", "class": "count", "type": "GNB_UL_FEC_LINK-MAX"}

    dl_min_desc = {"source": "flexran", "class": "count", "type": "GNB_DL_FEC_LINK-MIN"}
    dl_avg_desc = {"source": "flexran", "class": "count", "type": "GNB_DL_FEC_LINK-AVG"}
    dl_max_desc = {"source": "flexran", "class": "count", "type": "GNB_DL_FEC_LINK-MAX"}

    low_name = {"type": "low latency"}
    avg_name = {"type": "avg latency"}
    high_name = {"type": "high latency"}

    result_file = "l1_mlog_stats.txt"

    try:
        fh, _ = open_read_text_file(result_file)
    except (FileNotFoundError, Exception):
        print(f"flexran-post-process(): could not open {result_file}")
        print("Is the current directory for a flexran server (no result file)?")
        return

    metrics = CDMMetrics()
    num_sample = 0
    match = False

    for line in fh:
        if not match:
            if log_test and log_test in line:
                match = True
                print(f"Capture: {line}", end="")
            continue

        if "GNB_DL_FEC_LINK" in line and "AVG" in line or \
           "GNB_UL_FEC_LINK" in line and "AVG" in line:
            latencies = line.split()

            if "GNB_UL_FEC_LINK" in line:
                print(f"UL log: {line}", end="")
                desc_min = ul_min_desc
                desc_avg = ul_avg_desc
                desc_max = ul_max_desc
            else:
                print(f"DL log: {line}", end="")
                desc_min = dl_min_desc
                desc_avg = dl_avg_desc
                desc_max = dl_max_desc

            s_low = {"begin": times["begin"], "end": times["end"], "value": float(latencies[7])}
            s_avg = {"begin": times["begin"], "end": times["end"], "value": float(latencies[8])}
            s_high = {"begin": times["begin"], "end": times["end"], "value": float(latencies[9])}

            metrics.log_sample("flexran", desc_min, low_name, s_low)
            metrics.log_sample("flexran", desc_avg, avg_name, s_avg)
            metrics.log_sample("flexran", desc_max, high_name, s_high)

            num_sample += 1

        if "Test:" in line:
            match = False
            log_test = "EINVAL"

    fh.close()

    print("finishing_samples")
    metric_data_name = metrics.finish_samples()

    if num_sample > 0:
        sample_data = {
            "rickshaw-bench-metric": {"schema": {"version": "2021.04.12"}},
            "benchmark": "flexran",
            "primary-period": "measurement",
            "primary-metric": primary_metric,
            "periods": [
                {
                    "name": "measurement",
                    "metric-files": [metric_data_name],
                }
            ],
        }

        with open("postprocess/post-process-data.json", "w") as f:
            json.dump(sample_data, f)


if __name__ == "__main__":
    main()
