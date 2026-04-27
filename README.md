# DSB Trade Document Extraction

LLM-powered OCR and structured data extraction for trade finance documents.

---

## Quick-Start with Docker (Recommended)

No source code required — everything runs from pre-built Docker images.

### 1. Prerequisites

| Requirement | Notes |
|---|---|
| [Docker Desktop](https://www.docker.com/products/docker-desktop/) 24+ | macOS / Windows / Linux |
| Docker Compose v2 | Bundled with Docker Desktop |

### 2. Create a working directory

```bash
mkdir dsb-poc && cd dsb-poc
```

### 3. Download the compose file and env template

```bash
# docker-compose.yml
curl -O https://raw.githubusercontent.com/hillman2000hk/dsb-poc/main/docker-compose.yml

# .env template
curl -O https://raw.githubusercontent.com/hillman2000hk/dsb-poc/main/.env.example
cp .env.example .env
```

> If you received these files directly, just place `docker-compose.yml` and `.env.example` in the same folder and run `cp .env.example .env`.

### 4. Configure the `.env` file

Open `.env` in any text editor and fill in the required values:

```dotenv
# ─── LLM API (omlx) ─────────────────────────────────────────────────────────
# omlx serves large text + vision models via an OpenAI-compatible API
LLM_BASE_URL=https://your-omlx-server/v1
LLM_API_KEY=your-omlx-api-key

# Model names — must match the model IDs listed in your omlx server
LLM_TEXT_MODEL=gpt-oss-120b-MXFP4-Q8          # text-only tasks
LLM_SMALL_VISION_MODEL=Qwen3.6-35B-A3B-4bit   # default vision (faster)
LLM_LARGE_VISION_MODEL=Qwen3.6-35B-A3B-4bit   # high-accuracy vision

# ─── Embedding / Reranker (LM Studio) ───────────────────────────────────────
# LM Studio serves the embedding/reranker model locally
EMBEDDING_BASE_URL=http://127.0.0.1:1234/v1   # default LM Studio port
EMBEDDING_API_KEY=not-needed
EMBEDDING_MODEL=text-embedding-bge-reranker-v2-m3

# ─── Ports (change only if there are conflicts) ────────────────────────────
PORT=7676            # Frontend
BACKEND_PORT=8043    # Backend API

# ─── Stamp recovery (0 = off, 1–2 = extra LLM passes for stamp/chop) ───────
STAMP_RECOVERY_PASSES=1
```

**Do not set `DATABASE_URL` or `REDIS_URL`** — the compose file connects them automatically via container names.

#### Setting up omlx (LLM — text + vision)

omlx exposes an OpenAI-compatible API. Once your omlx server is running:

1. Find the base URL (e.g. `https://your-server/v1`) and set it as `LLM_BASE_URL`
2. Set `LLM_API_KEY` to the access key configured on your omlx instance
3. Run `curl $LLM_BASE_URL/models -H "Authorization: Bearer $LLM_API_KEY"` to list available model IDs, then copy the exact names into `LLM_TEXT_MODEL`, `LLM_SMALL_VISION_MODEL`, `LLM_LARGE_VISION_MODEL`

**Required models on omlx:**

| Role | Model ID | Type | Notes |
|---|---|---|---|
| Text (reasoning) | `gpt-oss-120b-MXFP4-Q8` | Text | Large instruction model |
| Vision — default | `Qwen3.6-35B-A3B-4bit` | Vision | Faster, used for most pages |
| Vision — high accuracy | `Qwen3.6-35B-A3B-4bit` | Vision | Used when **Large Model** toggle is on |

> The small and large vision slots use the same model by default. To use a heavier model for difficult scans, load a larger vision model on your omlx server and update `LLM_LARGE_VISION_MODEL` in `.env`.

#### Setting up LM Studio (Embeddings / Reranker)

LM Studio runs locally and serves a local OpenAI-compatible API on port **1234** by default.

1. Download [LM Studio](https://lmstudio.ai/) and install it
2. Search for and download the embedding model: **`bge-reranker-v2-m3`** (or the full ID `text-embedding-bge-reranker-v2-m3`)
3. Go to **Local Server** tab → load the model → click **Start Server**
4. The default URL is `http://127.0.0.1:1234/v1` — set this as `EMBEDDING_BASE_URL`

**Required model in LM Studio:**

| Role | Model ID | Notes |
|---|---|---|
| Embedding / Reranker | `text-embedding-bge-reranker-v2-m3` | Search in LM Studio as `bge-reranker-v2-m3` |

> **Note for Docker on macOS / Windows**: the backend container cannot reach `127.0.0.1` on the host directly. Use `host.docker.internal` instead:
> ```dotenv
> EMBEDDING_BASE_URL=http://host.docker.internal:1234/v1
> ```
> On Linux add `extra_hosts: ["host.docker.internal:host-gateway"]` to the `backend` and `celery` services in `docker-compose.yml`.

### 5. Start all services

```bash
docker compose up -d
```

Docker will pull the images on first run (~1–2 GB total). Subsequent starts are instant.

To watch logs:
```bash
docker compose logs -f
```

### 6. Open the app

| Service | URL |
|---|---|
| **Frontend** | http://localhost:7676 |
| **Backend API** | http://localhost:8043 |
| **API Docs (Swagger)** | http://localhost:8043/docs |

### 7. Stop / remove

```bash
# Stop (keeps data)
docker compose down

# Stop and delete all data (DB, uploads)
docker compose down -v
```

---

## Updating to a newer image version

```bash
docker compose pull
docker compose up -d
```

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| Frontend shows "Cannot connect to backend" | Ensure `BACKEND_PORT` in `.env` matches the exposed port and the backend container is healthy (`docker compose ps`) |
| Extraction jobs stay Pending | Check the Celery worker logs: `docker compose logs celery` |
| LLM errors in job output | Verify `LLM_BASE_URL`, `LLM_API_KEY` and model names in `.env` match your server |
| Port already in use | Change `PORT` or `BACKEND_PORT` in `.env` and re-run `docker compose up -d` |
| DB connection refused | Run `docker compose ps` — the `postgres` service must be healthy before `backend` starts |

---

---

## Architecture

```
DSB-POC/
├── backend/          # Python FastAPI + Celery
│   ├── app/
│   │   ├── core/     # Config, DB connection
│   │   ├── models/   # SQLAlchemy ORM models
│   │   ├── schemas/  # Pydantic schemas
│   │   ├── api/      # REST API routes
│   │   └── services/ # PDF processor, LLM extractor, job worker
│   ├── celery_app.py
│   ├── tasks.py
│   └── requirements.txt
├── frontend/         # Next.js 14 (App Router)
│   ├── app/
│   │   ├── page.tsx          # Dashboard
│   │   ├── documents/        # Upload & manage documents
│   │   ├── jobs/             # Monitor extraction jobs
│   │   └── results/[id]/     # View structured extraction results
│   └── lib/api.ts            # Typed API client
├── docker-compose.yml        # PostgreSQL + Redis
├── start.sh                  # One-command startup
└── .env                      # LLM / DB / port config
```

## Stack

| Layer | Technology |
|---|---|
| Frontend | Next.js 14, TailwindCSS, shadcn/ui |
| Backend API | Python FastAPI |
| Job Queue | Celery + Redis |
| Database | PostgreSQL |
| OCR/Extraction | LLM Vision via OpenAI-compatible API |
| PDF→Image | pdf2image (poppler) — bundled in Docker image |

## Extraction Fields

For each trade document PDF, the system extracts:

### 1. Company Names
- Trading Companies, Issuing/Reimbursing Banks, Shipping Companies, Drawee/Drawer
- **Stamp detection**: `is_stamp: true` flag when name appears inside a chop/stamp image

### 2. Company Addresses
- Full address linked to each company entry

### 3. Shipping Information
- **Port of Loading** (name, city, country)
- **Port of Discharge** (name, city, country)
- **Via ports** (intermediate transshipment ports)
- **Vessel Name** — extracted separately from voyage number (e.g., `JAZAN` from `JAZAN / 1644`)
- **Voyage Number**
- **Shipping Mode** (SEA, AIR, etc.)

### 4. Goods Description
- Item description, quantity, unit

## Models

Configure in `.env`:
- `LLM_SMALL_VISION_MODEL` — Default (faster, lower cost)
- `LLM_LARGE_VISION_MODEL` — Optional for complex/degraded scans

Toggle per-job in the UI via the **Large Model** switch.

## Output Formats

- **UI Summary**: Structured, validated view per field type
- **JSON Download**: Full merged result + page-level details
- **CSV Download**: Flat table suitable for downstream systems

## Supported Document Types

Commercial Invoice · Packing List · Bill of Lading · Air Waybill · Insurance Policy/Certificate · Certificate of Origin · Letter of Credit · Customs Invoice · Purchase Order · Contract

Supports **English and Chinese** language documents.
