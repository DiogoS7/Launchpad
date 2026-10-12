"""Static checks for the Launchpad repo. Runs in GitHub Actions without a Salesforce org.

1. Every XML metadata file is well-formed.
2. Every custom field has a description and help text (BRD NFR-03).
3. Seed data files are valid JSON and every @reference resolves.
4. Every image the README links to exists.
"""
import json, re, sys
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
NS = "{http://soap.sforce.com/2006/04/metadata}"
errors = []

# 1. Well-formed XML
xml_files = sorted((ROOT / "force-app").rglob("*-meta.xml"))
for f in xml_files:
    try:
        ET.parse(f)
    except ET.ParseError as e:
        errors.append(f"Invalid XML: {f.relative_to(ROOT)}: {e}")

# 2. Field documentation (NFR-03)
fields = [f for f in xml_files if f.name.endswith(".field-meta.xml")]
for f in fields:
    try:
        root = ET.parse(f).getroot()
    except ET.ParseError:
        continue
    for tag in ("description", "inlineHelpText"):
        el = root.find(NS + tag)
        if el is None or not (el.text or "").strip():
            errors.append(f"NFR-03: {f.relative_to(ROOT)} has no {tag}")

# 3. Seed data
data_dir = ROOT / "data"
ref_ids = set()
for plan_file in sorted(data_dir.glob("*plan*.json")):
    try:
        plan = json.loads(plan_file.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        errors.append(f"Invalid JSON: {plan_file.name}: {e}")
        continue
    for step in plan:
        for name in step["files"]:
            p = data_dir / name
            if not p.exists():
                errors.append(f"{plan_file.name} references missing file {name}")
for data_file in sorted(data_dir.glob("*__c.json")):
    try:
        recs = json.loads(data_file.read_text(encoding="utf-8"))["records"]
    except (json.JSONDecodeError, KeyError) as e:
        errors.append(f"Invalid data file: {data_file.name}: {e}")
        continue
    ref_ids.update(r["attributes"]["referenceId"] for r in recs)
for data_file in sorted(data_dir.glob("*__c.json")):
    try:
        recs = json.loads(data_file.read_text(encoding="utf-8"))["records"]
    except Exception:
        continue
    for r in recs:
        for k, v in r.items():
            if isinstance(v, str) and v.startswith("@") and v[1:] not in ref_ids:
                errors.append(f"{data_file.name}: {r['attributes']['referenceId']}.{k} points to unknown {v}")

# 4. README images
readme = (ROOT / "README.md").read_text(encoding="utf-8")
images = re.findall(r'!\[[^\]]*\]\(([^)]+)\)', readme) + re.findall(r'<img[^>]+src="([^"]+)"', readme)
for src in images:
    if src.startswith("http"):
        continue
    if not (ROOT / src).exists():
        errors.append(f"README image not found: {src}")

print(f"Checked {len(xml_files)} metadata files, {len(fields)} fields, {len(ref_ids)} seed records, {len(images)} README images.")
if errors:
    print(f"\n{len(errors)} problem(s) found:")
    for e in errors:
        print(f"  - {e}")
    sys.exit(1)
print("All checks passed.")
