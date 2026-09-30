"""Detector backends. Every backend returns a `supervision.Detections`,
so tracking and counting stay identical whatever model is used.

To add another backend (e.g. FastSAM), subclass `BaseDetector`
and register it in `build_detector`.
"""
from __future__ import annotations

import logging
from abc import ABC, abstractmethod

import numpy as np
import supervision as sv

from config import Settings

log = logging.getLogger(__name__)


class BaseDetector(ABC):
    @abstractmethod
    def __call__(self, frame_bgr: np.ndarray, conf: float) -> sv.Detections: ...


class YoloDetector(BaseDetector):
    """Plain YOLO inference on the full frame (fastest)."""

    def __init__(self, cfg: Settings):
        from ultralytics import YOLO

        self.model = YOLO(str(cfg.weights_path))
        self.imgsz = cfg.img_size
        self.device = cfg.device

    def __call__(self, frame_bgr, conf):
        result = self.model.predict(
            frame_bgr, conf=conf, imgsz=self.imgsz, device=self.device, verbose=False
        )[0]
        return sv.Detections.from_ultralytics(result)


class SahiDetector(BaseDetector):
    """YOLO + SAHI sliced inference. Slower, but much better on tiny objects
    such as pellets seen from far away."""

    def __init__(self, cfg: Settings):
        from sahi import AutoDetectionModel

        self.cfg = cfg
        self.model = AutoDetectionModel.from_pretrained(
            model_type="ultralytics",
            model_path=str(cfg.weights_path),
            confidence_threshold=cfg.conf_threshold,
            device=cfg.device,
        )

    def __call__(self, frame_bgr, conf):
        from sahi.predict import get_sliced_prediction

        self.model.confidence_threshold = conf
        size, overlap = self.cfg.sahi_slice_size, self.cfg.sahi_overlap
        pred = get_sliced_prediction(
            frame_bgr[:, :, ::-1], 
            self.model,
            slice_height=size,
            slice_width=size,
            overlap_height_ratio=overlap,
            overlap_width_ratio=overlap,
            verbose=0,
        )
        items = pred.object_prediction_list
        if not items:
            return sv.Detections.empty()
        return sv.Detections(
            xyxy=np.array([p.bbox.to_xyxy() for p in items], dtype=np.float32),
            confidence=np.array([p.score.value for p in items], dtype=np.float32),
            class_id=np.array([p.category.id for p in items], dtype=int),
        )


_CACHE: dict[str, BaseDetector] = {}


def build_detector(mode: str, cfg: Settings) -> BaseDetector:
    """Models are loaded once and reused across sessions."""
    if mode not in ("yolo", "sahi"):
        raise ValueError(f"Unknown mode '{mode}' (use 'yolo' or 'sahi')")
    if not cfg.weights_path.exists():
        raise FileNotFoundError(
            f"Weights not found at {cfg.weights_path}. Put your best.pt there or set WEIGHTS_PATH."
        )
    if mode not in _CACHE:
        log.info("Loading %s detector from %s", mode, cfg.weights_path)
        _CACHE[mode] = YoloDetector(cfg) if mode == "yolo" else SahiDetector(cfg)
    return _CACHE[mode]
