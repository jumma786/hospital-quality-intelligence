"""
build_snapshots_from_archives.py
--------------------------------
Turns CMS *annual* archive ZIPs (each containing several dated release ZIPs,
each containing the raw hospital CSVs) into the per-period feature tables the
longitudinal pipeline consumes.

For every release it:
  1. extracts the 3 needed CSVs to a temp dir,
  2. runs build_features.assemble() to reduce them to one per-hospital row,
  3. writes data/snapshots/<release-date>/hospital_features.csv,
  4. deletes the bulky raw CSVs (keeps ~1 MB/period instead of ~170 MB).

Run:
    python scripts/build_snapshots_from_archives.py
"""

from __future__ import annotations
import io
import pathlib
import re
import sys
import tempfile
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "ml" / "src"))
from build_features import assemble  # noqa: E402

DATA = ROOT / "data"
SNAP = DATA / "snapshots"

TARGETS = {
    "hospital_general_information.csv": "Hospital_General_Information.csv",
    "timely_and_effective_care-hospital.csv": "Timely_and_Effective_Care-Hospital.csv",
    "hcahps-hospital.csv": "HCAHPS-Hospital.csv",
}
DATE_RE = re.compile(r"(\d{4}-\d{2}-\d{2})")


def _extract_targets(zf: zipfile.ZipFile, dest: pathlib.Path) -> int:
    """Extract the 3 target CSVs (matched by basename) into dest. Returns count found."""
    found = 0
    for member in zf.namelist():
        base = member.split("/")[-1].lower()
        if base in TARGETS:
            with zf.open(member) as src, open(dest / TARGETS[base], "wb") as out:
                out.write(src.read())
            found += 1
    return found


def process_release(release_zip_bytes: bytes, period: str) -> bool:
    with tempfile.TemporaryDirectory() as tmp:
        tmpd = pathlib.Path(tmp)
        with zipfile.ZipFile(io.BytesIO(release_zip_bytes)) as rz:
            n = _extract_targets(rz, tmpd)
        if n < 3:
            print(f"  [skip] {period}: found only {n}/3 target files")
            return False
        features = assemble(tmpd)
        out_dir = SNAP / period
        out_dir.mkdir(parents=True, exist_ok=True)
        features.to_csv(out_dir / "hospital_features.csv", index=False)
        print(f"  [ok]   {period}: {len(features)} hospitals")
        return True


def main():
    annual_zips = sorted(DATA.glob("hospitals_annual_*.zip"))
    if not annual_zips:
        raise SystemExit(f"No hospitals_annual_*.zip found in {DATA}")

    made = []
    for az in annual_zips:
        print(f"== {az.name} ==")
        with zipfile.ZipFile(az) as outer:
            release_members = [m for m in outer.namelist() if m.lower().endswith(".zip")]
            for m in sorted(release_members):
                date_match = DATE_RE.search(m)
                period = date_match.group(1) if date_match else pathlib.Path(m).stem
                if process_release(outer.read(m), period):
                    made.append(period)

    print(f"\nBuilt {len(made)} real period snapshots -> {SNAP}")
    print("Periods:", ", ".join(sorted(made)))
    print("Next: python ml/src/build_panel.py && python ml/src/trend_analysis.py")


if __name__ == "__main__":
    main()
