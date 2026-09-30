import os
from dataclasses import dataclass
from pathlib import Path

from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent
load_dotenv(BASE_DIR / ".env")


def _f(name: str, default: str) -> str:
    return os.getenv(name, default).split("#")[0].strip()


@dataclass(frozen=True)
class Settings:
    host: str = _f("HOST", "0.0.0.0")
    port: int = int(_f("PORT", "4002"))
    weights_path: Path = BASE_DIR / _f("WEIGHTS_PATH", "weights/best23.pt")
    device: str = _f("DEVICE", "cpu")
    conf_threshold: float = float(_f("CONF_THRESHOLD", "0.3"))
    img_size: int = int(_f("IMG_SIZE", "640"))
    sahi_slice_size: int = int(_f("SAHI_SLICE_SIZE", "125"))
    sahi_overlap: float = float(_f("SAHI_OVERLAP", "0.5"))
    min_track_frames: int = int(_f("MIN_TRACK_FRAMES", "3"))
    stream_max_width: int = int(_f("STREAM_MAX_WIDTH", "960"))
    jpeg_quality: int = int(_f("JPEG_QUALITY", "70"))
    target_fps: int = int(_f("TARGET_FPS", "25"))
    sessions_dir: Path = BASE_DIR / "sessions"


settings = Settings()
