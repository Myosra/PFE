# Fish feeding tracker

Real-time pellet **detection, tracking and counting** for fish feeding videos.
A Flutter desktop/mobile app shows the annotated live stream and statistics; a Flask + Socket.IO backend runs YOLO (optionally with SAHI sliced inference) and ByteTrack.

<!-- Add your demo GIF here: ![demo](docs/demo.gif) -->

## How it works

```
Flutter app  <-- Socket.IO (frames + stats) -->  Flask backend
                                                   |- detector.py  YOLO or YOLO+SAHI  -> detections
                                                   |- session.py   ByteTrack -> unique pellet IDs -> stats
                                                   `- sessions/    JSON summary of every run
```

- **Counting:** a pellet is counted once its track ID has been seen in `MIN_TRACK_FRAMES` frames, which filters one-frame false positives.
- **Visible now / peak:** pellets currently tracked in the frame.
- **Uneaten estimate:** visible pellets / total counted. This is a heuristic, not a measured waste weight.
- **YOLO + SAHI:** slices each frame for better recall on tiny pellets, at lower FPS.

## Run it

### 1. Backend (Python 3.10+)
```bash
cd backend
python -m venv .venv && source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env                                # Windows: copy .env.example .env
# put your trained weights at backend/weights/best.pt  (or set WEIGHTS_PATH)
python app.py
```
Check `http://127.0.0.1:4002/health`. Use `DEVICE=cuda:0` in `.env` if you have a GPU.

### 2. Frontend (Flutter 3.16+)
```bash
cd frontend
flutter create . --project-name fish_feeding_tracker   # generates platform folders once
flutter pub get
flutter run -d windows                                  # or macos / linux / chrome
```
In the app: type a video path (or `0` for a webcam), pick a mode, press **Start tracking**.
Android emulator: set the backend address to `http://10.0.2.2:4002` (gear icon). Physical phone: use your computer's LAN IP.

## API

| Event (client to server) | Payload |
|---|---|
| `start_detection` | `{source, mode: "yolo"\|"sahi", conf}` |
| `stop_detection` | none |

| Event (server to client) | Payload |
|---|---|
| `frame` | `{frame: base64 JPEG, stats}` |
| `status` | `{state: "running"\|"finished", summary?}` |
| `error` | `{message}` |

`GET /health` and `GET /api/sessions` (past run summaries) are also available.

## Configuration
See `backend/.env.example` (confidence, image size, slice size, JPEG quality, FPS cap...).

## Roadmap
- FastSAM backend (implement `BaseDetector` in `detector.py`)
- Real waste estimation (e.g. pellets reaching a bottom zone)
- Session history screen backed by `/api/sessions`
