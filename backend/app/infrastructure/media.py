"""Where local media lives (bolt `041-local-audio-storage`).

`backend/media` holds recorded lesson audio for local development: the
Audio Lab clips (`seed_local_audio.py`) and anything uploaded through the
local audio store. Since bolt `050-image-choice-service` it also holds
pictures for picture questions, under `images/`. Git-ignored, so absent
when deployed -- production media is hosted elsewhere and referenced by
full URL.
"""

from __future__ import annotations

from pathlib import Path

MEDIA_DIR = Path(__file__).resolve().parents[2] / "media"
AUDIO_DIR = MEDIA_DIR / "audio"
IMAGES_DIR = MEDIA_DIR / "images"

# The URL path `main.py` serves MEDIA_DIR under, and so where AUDIO_DIR's
# and IMAGES_DIR's files are loaded from.
MEDIA_URL_PREFIX = "/media"
AUDIO_URL_PREFIX = f"{MEDIA_URL_PREFIX}/audio"
IMAGES_URL_PREFIX = f"{MEDIA_URL_PREFIX}/images"
