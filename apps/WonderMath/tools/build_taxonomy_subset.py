#!/usr/bin/env python3
"""Build the curated taxonomy subset bundled into the WonderMath app.

Reads the full Marble Skill Taxonomy from the repository's `data/` folder and
writes a filtered copy into `WonderMath/Resources/Taxonomy/`.

Filter rules (all deterministic, no record is edited):
  * topics:      subject in {Mathematics, Computing} AND the topic's age range
                 overlaps the 7-12 band (ageRangeStart <= 12 and ageRangeEnd >= 7)
  * dependencies: only edges whose topicId AND prerequisiteId are both kept
  * teaching-research: only records whose topicId is kept; records are copied
                 verbatim. `coverage` is recomputed for the subset so the
                 app can detect topics without research.

The output keeps the upstream top-level shape of each file and adds a
`subset` object describing the filter and the SHA-256 of each source file.
The result is a derivative database of the Marble Skill Taxonomy and stays
under ODbL 1.0 (database) / CC BY-SA 4.0 (content), see LICENSE-NOTICE.md.

Usage:  python3 tools/build_taxonomy_subset.py [--source ../../data] [--out WonderMath/Resources/Taxonomy]
"""
import argparse
import hashlib
import json
import os
import sys

SUBJECTS = ("Mathematics", "Computing")
AGE_MIN, AGE_MAX = 7, 12

HERE = os.path.dirname(os.path.abspath(__file__))
APP_ROOT = os.path.dirname(HERE)


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def dump(obj, path):
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(obj, f, ensure_ascii=False, separators=(",", ":"))
        f.write("\n")


def in_band(topic):
    return topic["ageRangeStart"] <= AGE_MAX and topic["ageRangeEnd"] >= AGE_MIN


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", default=os.path.join(APP_ROOT, "..", "..", "data"))
    ap.add_argument("--out", default=os.path.join(APP_ROOT, "WonderMath", "Resources", "Taxonomy"))
    args = ap.parse_args()

    src = os.path.abspath(args.source)
    out = os.path.abspath(args.out)
    os.makedirs(out, exist_ok=True)
    paths = {name: os.path.join(src, name + ".json") for name in ("topics", "dependencies", "teaching-research")}

    topics_file = load(paths["topics"])
    deps_file = load(paths["dependencies"])
    research_file = load(paths["teaching-research"])

    subset_meta = {
        "description": "Curated WonderMath subset of the Marble Skill Taxonomy (derivative database, ODbL 1.0).",
        "filter": {"subjects": list(SUBJECTS), "ageBand": [AGE_MIN, AGE_MAX], "ageRule": "ageRangeStart <= 12 and ageRangeEnd >= 7"},
        "script": "apps/WonderMath/tools/build_taxonomy_subset.py",
        "sourceSha256": {name + ".json": sha256(p) for name, p in paths.items()},
        "attribution": "Marble Skill Taxonomy (v1) · © Generative Spark, Inc. (Marble) · https://withmarble.com · licensed under ODbL 1.0 (database) and CC BY-SA 4.0 (content).",
    }

    topics = [t for t in topics_file["topics"] if t["subject"] in SUBJECTS and in_band(t)]
    kept = {t["id"] for t in topics}
    deps = [d for d in deps_file["dependencies"] if d["topicId"] in kept and d["prerequisiteId"] in kept]
    records = [r for r in research_file["records"] if r["topicId"] in kept]
    with_research = {r["topicId"] for r in records}

    by_subject = {}
    for t in topics:
        s = by_subject.setdefault(t["subject"], {"topics": 0, "withResearch": 0, "withoutResearch": 0})
        s["topics"] += 1
        s["withResearch" if t["id"] in with_research else "withoutResearch"] += 1

    dump({"version": topics_file["version"], "topicCount": len(topics), "subset": subset_meta, "topics": topics},
         os.path.join(out, "topics.json"))
    dump({"version": deps_file["version"], "note": deps_file.get("note", ""), "edgeCount": len(deps), "subset": subset_meta,
          "dependencies": deps}, os.path.join(out, "dependencies.json"))
    dump({
        "schemaVersion": research_file["schemaVersion"],
        "version": research_file["version"],
        "exportedAt": research_file["exportedAt"],
        "topicFileSha256": research_file["topicFileSha256"],
        "recordCount": len(records),
        "coverage": {
            "topicCount": len(topics),
            "withResearch": len(with_research),
            "withoutResearch": len(topics) - len(with_research),
            "bySubject": by_subject,
            "missingTopicIds": sorted(t["id"] for t in topics if t["id"] not in with_research),
        },
        "notes": research_file.get("notes", []),
        "subset": subset_meta,
        "records": records,
    }, os.path.join(out, "teaching-research.json"))

    print(f"topics: {len(topics)}  dependencies: {len(deps)}  research records: {len(records)}")
    for subject, c in sorted(by_subject.items()):
        print(f"  {subject}: {c['topics']} topics, {c['withResearch']} with research, {c['withoutResearch']} without")
    for subject in SUBJECTS:
        domains = sorted({t['domain'] for t in topics if t['subject'] == subject})
        print(f"  {subject} domains: {domains}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
