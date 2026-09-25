"""Builds the sample pictures for the Picture Lab (bolt `051-image-choice-samples`).

Downloads each picture from a pinned OpenMoji release, shrinks it to at
most 512 px, saves it as WebP in `backend/sample_pictures/`, and rewrites
`credits.json` beside it with each picture's author, source and licence.
The output is committed; `seed_local_pictures.py` copies it into
`backend/media/images/samples/` for the local backend to serve.

Pillow is needed only here, so it is not a backend dependency. From
`backend/`:

    uv run --with pillow python scripts/build_sample_pictures.py

To add a picture: add a line to `PICTURES`, re-run, and commit the new
file and `credits.json`. The app lists every entry of `credits.json`
(bolt 054), so nothing else needs changing to credit it.
"""

from __future__ import annotations

import io
import json
import sys
import urllib.request
from pathlib import Path

from PIL import Image

BACKEND = Path(__file__).resolve().parents[1]
OUT = BACKEND / "sample_pictures"

# Pinned, so re-running gives the same pictures and credits.
OPENMOJI_RELEASE = "17.0.0"
_RAW = f"https://raw.githubusercontent.com/hfg-gmuend/openmoji/{OPENMOJI_RELEASE}"
PNG_URL = _RAW + "/color/618x618/{hexcode}.png"
DATA_URL = _RAW + "/data/openmoji.json"
PAGE_URL = "https://openmoji.org/library/emoji-{hexcode}/"

LICENCE = "CC BY-SA 4.0"
LICENCE_URL = "https://creativecommons.org/licenses/by-sa/4.0/"

MAX_SIDE = 512
WEBP_QUALITY = 80
MAX_BYTES = 300 * 1024

# (file written, OpenMoji hexcode, what it shows)
PICTURES: list[tuple[str, str, str]] = [
    ("water.webp", "1F4A7", "Water"),
    ("dog.webp", "1F415", "Dog"),
    ("house.webp", "1F3E0", "House"),
    ("cat.webp", "1F408", "Cat"),
    ("sun.webp", "2600", "Sun"),
    ("number-1.webp", "0031-FE0F-20E3", "The number 1"),
    ("number-2.webp", "0032-FE0F-20E3", "The number 2"),
    ("number-5.webp", "0035-FE0F-20E3", "The number 5"),
    ("number-10.webp", "1F51F", "The number 10"),
]


def _get(url: str) -> bytes:
    with urllib.request.urlopen(url, timeout=30) as response:  # noqa: S310 -- fixed https URLs
        data: bytes = response.read()
    return data


def _shrink(png: bytes) -> bytes:
    image = Image.open(io.BytesIO(png)).convert("RGBA")
    image.thumbnail((MAX_SIDE, MAX_SIDE), Image.Resampling.LANCZOS)
    out = io.BytesIO()
    image.save(out, "WEBP", quality=WEBP_QUALITY, method=6)
    data = out.getvalue()
    if len(data) > MAX_BYTES:
        raise SystemExit(f"a picture came out at {len(data)} bytes, over {MAX_BYTES}")
    return data


def main() -> None:
    authors = {entry["hexcode"]: entry["openmoji_author"] for entry in json.loads(_get(DATA_URL))}
    OUT.mkdir(exist_ok=True)
    credits = []
    for file, hexcode, subject in PICTURES:
        (OUT / file).write_bytes(_shrink(_get(PNG_URL.format(hexcode=hexcode))))
        credits.append(
            {
                "file": file,
                "subject": subject,
                "author": authors[hexcode],
                "source": "OpenMoji",
                "source_url": PAGE_URL.format(hexcode=hexcode),
                "licence": LICENCE,
                "licence_url": LICENCE_URL,
                "changes": f"Resized to {MAX_SIDE} px and converted to WebP",
            }
        )
    (OUT / "credits.json").write_text(
        json.dumps({"pictures": credits}, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    print(f"Wrote {len(PICTURES)} pictures and credits.json to {OUT}")  # noqa: T201


if __name__ == "__main__":
    sys.exit(main())
