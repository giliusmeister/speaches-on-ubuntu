# Speaches on Ubuntu

This repository is a native Ubuntu 24.04 LAN deployment kit for:

- running [speaches-ai/speaches](https://github.com/speaches-ai/speaches)
- checking its OpenAI-compatible STT endpoint
- checking its OpenAI-compatible TTS endpoint
- exposing an `OpenLingo`-style `/api/stt` route without deploying `OpenLingo` here
- keeping a simple `faster-whisper` fallback if `Speaches` is inconvenient

`OpenLingo` is assumed to be deployed elsewhere and to remain nearly vanilla except for its OpenAI call replacements. This repo only covers the external STT side and now follows the same local-only plus nginx pattern as `piper-on-ubuntu`.

## What is included

- [scripts/install-ubuntu24-native.sh](C:\Users\iparshikov\projects\speaches-on-ubuntu\scripts\install-ubuntu24-native.sh): native Ubuntu install helper for upstream `Speaches`
- [deploy/speaches.service](C:\Users\iparshikov\projects\speaches-on-ubuntu\deploy\speaches.service): `systemd` unit for `Speaches`
- [services/openlingo-stt-adapter/app.py](C:\Users\iparshikov\projects\speaches-on-ubuntu\services\openlingo-stt-adapter\app.py): thin `/api/stt -> /v1/audio/transcriptions` adapter
- [services/openlingo-stt-adapter/run.sh](C:\Users\iparshikov\projects\speaches-on-ubuntu\services\openlingo-stt-adapter\run.sh): native runner for the adapter
- [deploy/openlingo-stt-adapter.service](C:\Users\iparshikov\projects\speaches-on-ubuntu\deploy\openlingo-stt-adapter.service): `systemd` unit for the adapter
- [services/faster-whisper-api/app.py](C:\Users\iparshikov\projects\speaches-on-ubuntu\services\faster-whisper-api\app.py): fallback STT API
- [services/faster-whisper-api/run.sh](C:\Users\iparshikov\projects\speaches-on-ubuntu\services\faster-whisper-api\run.sh): native runner for the fallback
- [systemd/faster-whisper-api.service](C:\Users\iparshikov\projects\speaches-on-ubuntu\systemd\faster-whisper-api.service): `systemd` unit for the fallback
- [scripts/verify-speaches-stt.sh](C:\Users\iparshikov\projects\speaches-on-ubuntu\scripts\verify-speaches-stt.sh): direct STT verification
- [scripts/check-speaches-health.sh](C:\Users\iparshikov\projects\speaches-on-ubuntu\scripts\check-speaches-health.sh): health probe
- [scripts/download-speaches-stt-model.sh](C:\Users\iparshikov\projects\speaches-on-ubuntu\scripts\download-speaches-stt-model.sh): explicit STT model predownload
- [scripts/curl-openlingo-stt.sh](C:\Users\iparshikov\projects\speaches-on-ubuntu\scripts\curl-openlingo-stt.sh): adapter verification
- [scripts/verify-speaches-tts.sh](C:\Users\iparshikov\projects\speaches-on-ubuntu\scripts\verify-speaches-tts.sh): direct TTS verification
- [scripts/benchmark-tts.sh](C:\Users\iparshikov\projects\speaches-on-ubuntu\scripts\benchmark-tts.sh): quick latency comparison for `Speaches` vs `Piper`
- [deploy/nginx-speaches-api.locations.conf](C:\Users\iparshikov\projects\speaches-on-ubuntu\deploy\nginx-speaches-api.locations.conf): nginx snippet template for API routes
- [deploy/nginx-speaches-api.site.conf](C:\Users\iparshikov\projects\speaches-on-ubuntu\deploy\nginx-speaches-api.site.conf): standalone nginx site template
- [scripts/install_ubuntu.sh](C:\Users\iparshikov\projects\speaches-on-ubuntu\scripts\install_ubuntu.sh): one-step Ubuntu install matching the `piper` project style

## Recommended architecture

Preferred path:

1. Run `Speaches` on the Ubuntu LAN host.
2. Expose `Speaches` through the same nginx entry style you already use for `piper`.
3. Point `OpenLingo` to `http://SERVER_IP[:PORT]/v1`.

Compatibility path:

1. Run `Speaches` on the Ubuntu LAN host.
2. Run the adapter from this repo on the same host.
3. Point `OpenLingo` to `http://SERVER_IP:8102/api/stt` if it expects its own upload route.

Only use the fallback `faster-whisper` service if `Speaches` proves awkward in practice.

## Known Working LAN Profile

This is the tested shape used alongside `piper-on-ubuntu`:

```text
Speaches internal:       http://127.0.0.1:8101
Speaches nginx/API:      http://192.168.11.11:8102
OpenLingo STT adapter:   http://127.0.0.1:8103
Fallback faster-whisper: http://127.0.0.1:8104
Piper TTS nginx:         http://192.168.11.11:8100
```

OpenLingo should only use the nginx-facing URLs:

```env
STT_PROVIDER=speaches
STT_URL=http://192.168.11.11:8102/api/stt
```

or the OpenAI-compatible STT endpoint:

```env
STT_PROVIDER=openai-compatible
STT_BASE_URL=http://192.168.11.11:8102/v1
STT_API_KEY=not-empty
STT_MODEL=Systran/faster-distil-whisper-small.en
```

Keep the internal ports on `127.0.0.1`; do not point OpenLingo at `127.0.0.1:8101` unless OpenLingo runs on the same host and namespace.

## Step 1. Prepare the Ubuntu 24.04 host

Clone this repo onto the LAN server and create the local config:

```bash
git clone <this-repo> /opt/speaches-on-ubuntu
cd /opt/speaches-on-ubuntu
cp .env.example .env
```

Set the values you care about in [.env.example](C:\Users\iparshikov\projects\speaches-on-ubuntu\.env.example), especially:

- `APP_PORT`
- `NGINX_HTTP_PORT`
- `NGINX_API_PORT`
- `LAN_HOST`
- `SPEACHES_PORT`
- `SPEACHES_MODEL`
- `SPEACHES_TTS_MODEL`
- `SPEACHES_TTS_VOICE`
- `OPENLINGO_STT_ADAPTER_PORT`
- `FASTER_WHISPER_PORT`

By default, internal services now bind only to `127.0.0.1`, like `piper-on-ubuntu`.

Suggested shape when many ports are already occupied on the server:

- app port: internal only, for example `APP_PORT=18000`
- app entry via `nginx`: `NGINX_HTTP_PORT=18080`
- API entry via `nginx`: `NGINX_API_PORT=8102`
- `Speaches` internal listen: `SPEACHES_PORT=8101`
- adapter internal listen: `OPENLINGO_STT_ADAPTER_PORT=8103`
- fallback internal listen: `FASTER_WHISPER_PORT=8104`

Make sure the adapter base URL follows the real Speaches port:

```env
SPEACHES_BASE_URL=http://127.0.0.1:8101/v1
```

If you change `SPEACHES_PORT`, update `SPEACHES_BASE_URL` too.

Because the provided `speaches.service` runs as root, Hugging Face models are cached under root's home. Create the cache directory before model downloads:

```bash
sudo mkdir -p /root/.cache/huggingface/hub
```

The installer does this automatically.

## Step 2. Install Speaches natively

Install everything in the same style as `piper-on-ubuntu`:

```bash
cd /opt/speaches-on-ubuntu
bash scripts/install_ubuntu.sh
```

This installer:

1. Installs Ubuntu packages including `nginx`, `ffmpeg`, `git`, and `gettext-base`.
2. Copies this app to `/opt/speaches-on-ubuntu`.
3. Clones upstream `speaches-ai/speaches` into `/opt/speaches`.
4. Prepares the upstream `uv` environment.
5. Installs `speaches.service` and `openlingo-stt-adapter.service`.
6. Writes the nginx snippet at `/etc/nginx/snippets/speaches-api.locations.conf`.

If you want a standalone nginx test port, use:

```bash
CONFIGURE_NGINX=site bash scripts/install_ubuntu.sh
```

## Step 3. Run Speaches under systemd

Install or update the services manually if needed:

```bash
sudo cp deploy/speaches.service /etc/systemd/system/speaches.service
sudo cp deploy/openlingo-stt-adapter.service /etc/systemd/system/openlingo-stt-adapter.service
sudo systemctl daemon-reload
sudo systemctl enable --now speaches openlingo-stt-adapter
sudo systemctl status speaches
```

Logs:

```bash
journalctl -u speaches -f
```

The local endpoint should now be reachable on:

```text
http://127.0.0.1:8101
```

Health check:

```bash
./scripts/check-speaches-health.sh "http://127.0.0.1:8101"
curl -i "http://127.0.0.1:8102/health"
```

## Step 4. Download Models

Speaches model download uses `POST /v1/models/{model_id}`. A bare `POST /v1/models` returns `404`.

Download the TTS model:

```bash
curl -X POST "http://127.0.0.1:8101/v1/models/speaches-ai/Kokoro-82M-v1.0-ONNX"
```

Download the STT model:

```bash
curl -X POST "http://127.0.0.1:8101/v1/models/Systran/faster-distil-whisper-small.en"
```

You can also use the CLI:

```bash
cd /opt/speaches
source .venv/bin/activate
export SPEACHES_BASE_URL="http://127.0.0.1:8101"
uvx speaches-cli model download speaches-ai/Kokoro-82M-v1.0-ONNX
uvx speaches-cli model download Systran/faster-distil-whisper-small.en
uvx speaches-cli model ls
```

## Step 5. Verify the OpenAI-compatible STT endpoint

If you want to avoid first-request model download latency, predownload the STT model:

```bash
./scripts/download-speaches-stt-model.sh /opt/speaches "Systran/faster-distil-whisper-small.en" "http://127.0.0.1:8101"
```

Quick check:

```bash
./scripts/verify-speaches-stt.sh "http://127.0.0.1:8102" ./audio.wav
```

Equivalent raw request:

```bash
curl -s "http://127.0.0.1:8102/v1/audio/transcriptions" \
  -F "file=@audio.wav" \
  -F "model=Systran/faster-distil-whisper-small.en"
```

If your `OpenLingo` code uses an OpenAI SDK-style client, the desired target is:

```bash
OPENAI_BASE_URL=http://192.168.11.11:8102/v1
OPENAI_API_KEY=not-empty
```

## Step 5a. Verify the OpenAI-compatible TTS endpoint

`Speaches` also supports TTS. Quick check:

```bash
./scripts/verify-speaches-tts.sh "http://127.0.0.1:8102" /tmp/speaches.wav
```

You can also choose text, model, and voice explicitly:

```bash
./scripts/verify-speaches-tts.sh \
  "http://127.0.0.1:8102" \
  /tmp/speaches.wav \
  "Hello from the LAN server" \
  "speaches-ai/Kokoro-82M-v1.0-ONNX" \
  "af_heart"
```

Verify that the result is real audio:

```bash
file /tmp/speaches.wav
ls -lh /tmp/speaches.wav
```

Expected:

```text
RIFF (little-endian) data, WAVE audio, Microsoft PCM, 16 bit, mono 24000 Hz
```

## Step 6. If needed, expose OpenLingo-style /api/stt

If your `OpenLingo` branch expects `POST /api/stt` rather than an OpenAI base URL, use the adapter from this repo.

Manual start:

```bash
cd /opt/speaches-on-ubuntu
./services/openlingo-stt-adapter/run.sh
```

Systemd install:

```bash
sudo cp systemd/openlingo-stt-adapter.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now openlingo-stt-adapter
sudo systemctl status openlingo-stt-adapter
```

Local adapter endpoint:

```text
http://127.0.0.1:8103/api/stt
```

Adapter test:

```bash
./scripts/curl-openlingo-stt.sh "http://127.0.0.1:8103" ./audio.wav
curl -s "http://127.0.0.1:8102/api/stt" -F "file=@/tmp/speaches.wav"
```

Returned shape:

```json
{
  "text": "transcribed text",
  "provider": "speaches",
  "model": "Systran/faster-distil-whisper-small.en",
  "raw": {}
}
```

## Step 7. Fallback: own faster-whisper API

If `Speaches` turns out to be the wrong fit, run the fallback service instead.

Manual start:

```bash
cd /opt/speaches-on-ubuntu
./services/faster-whisper-api/run.sh
```

Systemd install:

```bash
sudo cp systemd/faster-whisper-api.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now faster-whisper-api
sudo systemctl status faster-whisper-api
```

Fallback endpoint:

```text
POST http://SERVER_IP:8104/api/stt
```

This response includes `text`, `segments`, language, and duration.

## Step 8. Put nginx in front with explicit ports

If the server already has many occupied ports, keep the internal services on their own ports and expose only two entry points with `nginx`:

- app entry: `NGINX_HTTP_PORT`
- API entry: `NGINX_API_PORT`

The main flow now mirrors `piper-on-ubuntu`: internal services stay on localhost and nginx exposes the routes you need.

Add this line inside an existing nginx `server { ... }` block:

```nginx
include /etc/nginx/snippets/speaches-api.locations.conf;
```

Then reload nginx:

```bash
sudo nginx -t
sudo systemctl reload nginx
```

Routing shape:

- `http://SERVER_IP:${NGINX_API_PORT}/v1/` -> `Speaches`
- `http://SERVER_IP:${NGINX_API_PORT}/api/stt` -> adapter
- `http://SERVER_IP:${NGINX_API_PORT}/api/fallback-stt` -> fallback `faster-whisper`

If you want a standalone nginx test port instead:

```bash
CONFIGURE_NGINX=site bash scripts/install_ubuntu.sh
```

That creates a dedicated site on `NGINX_API_PORT`.

## Step 9. Use Speaches as a second TTS engine

Yes, `Speaches` can be used for TTS as well as STT. That makes it a good second option next to your existing `Piper` path.

Practical split:

1. Keep your current `Piper` implementation as the known-good baseline.
2. Add `Speaches` TTS as variant 2.
3. Prefer `Kokoro` inside `Speaches` for the second voice stack, because it gives you a meaningfully different engine rather than duplicating `Piper` twice.

That gives you a two-way voice loop with interchangeable pieces:

- STT: `Speaches` or fallback `faster-whisper`
- TTS: existing `Piper` path or `Speaches` TTS

## Step 10. Compare quality and speed of Speaches vs Piper

For a quick latency check:

1. Save one representative text sample to a file, for example `sample.txt`.
2. Run:

```bash
./scripts/benchmark-tts.sh \
  "http://SERVER_IP:8102" \
  "http://SERVER_IP:8100/v1/audio/speech" \
  ./sample.txt \
  ./bench-out
```

This saves:

- `bench-out/speaches.wav`
- `bench-out/piper.wav`
- `bench-out/results.csv`

I would compare them on three axes:

1. Time to first usable result.
2. Total generation time for short and medium phrases.
3. Subjective quality: naturalness, intelligibility, prosody, fatigue on long listening.

For a fair test, use the same:

- phrase set
- host machine
- CPU/GPU mode
- output format
- number of warmup runs

Best lightweight methodology:

1. Prepare 10 short UI phrases, 10 medium assistant phrases, and 3 long paragraphs.
2. Run each engine once as warmup.
3. Run each phrase 3 times and compare median `time_total`.
4. Listen blind to paired outputs and score from 1 to 5 for naturalness and clarity.
5. Keep separate notes for Russian and English if you use both.

## LAN notes

If Ubuntu firewall is enabled:

```bash
sudo ufw allow ${NGINX_HTTP_PORT}/tcp
sudo ufw allow ${NGINX_API_PORT}/tcp
sudo ufw allow 8102/tcp
```

If only `nginx` should be public, open `NGINX_API_PORT` and keep `8101`, `8103`, and `8104` bound to `127.0.0.1` or firewalled.

## Docker

`compose.yaml` and `compose.gpu.yaml` are still present as an optional backup path, but native Ubuntu deployment is now the primary route for this project.
