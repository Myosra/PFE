"""One tracking session = one video/camera source streamed to one client."""
from __future__ import annotations

import base64
import json
import logging
import threading
import time
from datetime import datetime

import cv2
import supervision as sv

from config import Settings
from detector import BaseDetector

log = logging.getLogger(__name__)

AMBER = (65, 180, 242)  # BGR


class TrackingSession:
    def __init__(self, sio, sid: str, source: str, mode: str,
                 conf: float, detector: BaseDetector, cfg: Settings):
        self.sio, self.sid, self.source, self.mode = sio, sid, source, mode
        self.conf, self.detector, self.cfg = conf, detector, cfg
        self._stop = threading.Event()
        self.started_at = datetime.now()
        self.stats = {}

    def start(self):
        self.sio.start_background_task(self._run)

    def stop(self):
        self._stop.set()

    def _emit(self, event: str, payload: dict):
        self.sio.emit(event, payload, to=self.sid)

    def _open(self) -> cv2.VideoCapture:
        src = int(self.source) if self.source.isdigit() else self.source
        cap = cv2.VideoCapture(src)
        if not cap.isOpened():
            raise IOError(f"Cannot open source: {self.source}")
        return cap

    def _draw(self, frame, det: sv.Detections, counted: set, total: int, visible: int):
        if det.tracker_id is None:
            det_boxes = []
        else:
            det_boxes = zip(det.xyxy.astype(int), det.tracker_id)
        for xyxy, tid in det_boxes:
            tid = int(tid)
            x1, y1, x2, y2 = xyxy
            color = AMBER if tid in counted else (200, 200, 200)
            cv2.rectangle(frame, (x1, y1), (x2, y2), color, 2)
            cv2.putText(frame, f"#{tid}", (x1, max(y1 - 6, 12)),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 1, cv2.LINE_AA)
        cv2.putText(frame, f"total {total}  visible {visible}", (12, 28),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255, 255, 255), 2, cv2.LINE_AA)

    def _encode(self, frame) -> str:
        h, w = frame.shape[:2]
        if w > self.cfg.stream_max_width:
            s = self.cfg.stream_max_width / w
            frame = cv2.resize(frame, (self.cfg.stream_max_width, int(h * s)))
        ok, buf = cv2.imencode(".jpg", frame, [cv2.IMWRITE_JPEG_QUALITY, self.cfg.jpeg_quality])
        return base64.b64encode(buf).decode("ascii")

    def _run(self):
        try:
            cap = self._open()
        except Exception as e:  
            self._emit("error", {"message": str(e)})
            return

        src_fps = cap.get(cv2.CAP_PROP_FPS) or 25
        fps_cap = min(src_fps, self.cfg.target_fps)
        frame_period = 1.0 / fps_cap
        tracker = sv.ByteTrack(frame_rate=int(src_fps))

        hits: dict[int, int] = {}     
        counted: set[int] = set()     
        peak, frame_idx = 0, 0
        t0 = last_fps_t = time.time()
        fps = 0.0
        self._emit("status", {"state": "running", "started_at": self.started_at.isoformat()})

        try:
            while not self._stop.is_set():
                loop_t = time.time()
                ok, frame = cap.read()
                if not ok:
                    break
                frame_idx += 1

                det = self.detector(frame, self.conf)
                det = tracker.update_with_detections(det)

                visible_ids = set()
                if det.tracker_id is not None:
                    for tid in det.tracker_id:
                        tid = int(tid)
                        hits[tid] = hits.get(tid, 0) + 1
                        if hits[tid] >= self.cfg.min_track_frames:
                            counted.add(tid)
                        visible_ids.add(tid)
                    visible = len(visible_ids & counted)
                else:
                    visible = 0
                peak = max(peak, visible)
                total = len(counted)

                now = time.time()
                fps = 0.9 * fps + 0.1 / max(now - last_fps_t, 1e-6)
                last_fps_t = now

                self._draw(frame, det, counted, total, visible)

                self.stats = {
                    "total_pellets": total,
                    "visible_pellets": visible,
                    "peak_visible": peak,
                    "uneaten_ratio": round(visible / total, 3) if total else 0.0,
                    "fps": round(fps, 1),
                    "elapsed_s": round(now - t0, 1),
                    "started_at": self.started_at.isoformat(),
                }
                self._emit("frame", {"frame": self._encode(frame), "stats": self.stats})
                sleep = frame_period - (time.time() - loop_t)
                if sleep > 0:
                    self.sio.sleep(sleep)
                else:
                    self.sio.sleep(0)
        except Exception as e:  
            log.exception("Session crashed")
            self._emit("error", {"message": f"Detection failed: {e}"})
        finally:
            cap.release()
            summary = {**self.stats, "source": self.source, "mode": self.mode,
                       "finished": not self._stop.is_set()}
            self._save(summary)
            self._emit("status", {"state": "finished", "summary": summary})

    def _save(self, summary: dict):
        if not summary.get("total_pellets") and not summary.get("elapsed_s"):
            return
        self.cfg.sessions_dir.mkdir(exist_ok=True)
        name = self.started_at.strftime("%Y%m%d_%H%M%S") + ".json"
        (self.cfg.sessions_dir / name).write_text(json.dumps(summary, indent=2))

