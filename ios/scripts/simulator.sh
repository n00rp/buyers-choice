#!/bin/bash
# Skriver ut id för en tillgänglig iPhone-simulator med senaste iOS.
set -euo pipefail
xcrun simctl list devices available -j | python3 -c '
import json, sys, re
d = json.load(sys.stdin)["devices"]
best = None
for rt, devs in d.items():
    m = re.search(r"iOS-(\d+)-(\d+)", rt)
    if not m:
        continue
    v = (int(m.group(1)), int(m.group(2)))
    for x in devs:
        if x["name"].startswith("iPhone") and "Pro Max" not in x["name"] and "SE" not in x["name"]:
            if best is None or v > best[0] or (v == best[0] and x["name"] < best[1]):
                best = (v, x["name"], x["udid"])
if not best:
    sys.exit("Ingen iPhone-simulator hittades")
print(best[2])
print("Simulator:", best[1], "iOS %d.%d" % best[0], file=sys.stderr)
'
