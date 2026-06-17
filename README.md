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
curl -O https://raw.githubusercontent.com/vansonhkoct/dsb-poc/main/docker-compose.yml

# .env template
curl -O https://raw.githubusercontent.com/vansonhkoct/dsb-poc/main/.env.example
cp .env.example .env
```

> If you received these files directly, just place `docker-compose.yml` and `.env.example` in the same folder and run `cp .env.example .env`.

### 4. Configure the `.env` file

Open `.env` in any text editor and fill in the required values:

```dotenv
# LLM API for text-only tasks
LLM_BASE_URL=https://your-omlx-server/v1
LLM_API_KEY=your-omlx-api-key
LLM_TEXT_MODEL=gpt-oss-120b-MXFP4-Q8

# Vision model API. This may be the same server as LLM_BASE_URL or a separate
# OpenAI-compatible vision server. If LLM_VISION_API_KEY is blank, LLM_API_KEY is reused.
LLM_VISION_BASE_URL=https://your-vision-server/v1
LLM_VISION_API_KEY=
LLM_VISION_MODEL=qwen/qwen3.5-9b

# Embedding / reranker API. For Docker on macOS / Windows, use host.docker.internal
# when the model server is running on the host machine.
EMBEDDING_BASE_URL=http://host.docker.internal:1234/v1
EMBEDDING_API_KEY=not-needed
EMBEDDING_MODEL=text-embedding-bge-reranker-v2-m3

# Local non-Docker defaults. Docker Compose overrides these inside containers.
DATABASE_URL=postgresql://hillmantam@localhost:5432/pprfs_vetting
REDIS_URL=redis://localhost:6379/0

# Host ports
FRONTEND_PORT=7676
BACKEND_PORT=8043

# Results page annotation mode:
# disabled | number_annotated | number_and_region_annotated
NEXT_PUBLIC_PAGE_ANNOTATION_MODE=disabled

# Stamp/chop recovery passes. 0=off, 1 or 2=extra LLM passes per page.
STAMP_RECOVERY_PASSES=1
```

When using Docker Compose, leave `DATABASE_URL` and `REDIS_URL` as-is; `docker-compose.yml` overrides them inside the backend and Celery containers so they connect to the `postgres` and `redis` services.

#### Setting up LLM endpoints

The backend uses OpenAI-compatible APIs for both text and vision calls:

1. Set `LLM_BASE_URL` and `LLM_API_KEY` for the text model server.
2. Set `LLM_TEXT_MODEL` to the exact text model ID listed by that server.
3. Set `LLM_VISION_BASE_URL` for the vision model server. This may be the same server as `LLM_BASE_URL`, or a separate server such as LM Studio.
4. Set `LLM_VISION_API_KEY` only when the vision server needs a different key. If it is blank, the backend reuses `LLM_API_KEY`.
5. Set `LLM_VISION_MODEL` to the exact vision model ID listed by the vision server.

Useful checks:

```bash
curl "$LLM_BASE_URL/models" -H "Authorization: Bearer $LLM_API_KEY"
curl "$LLM_VISION_BASE_URL/models" -H "Authorization: Bearer ${LLM_VISION_API_KEY:-$LLM_API_KEY}"
```

**Required models:**

| Role | Model ID | Notes |
|---|---|---|
| Text reasoning | `gpt-oss-120b-MXFP4-Q8` | Used for text-only reasoning tasks |
| Vision extraction | `qwen/qwen3.5-9b` | Used for page classification, extraction, and stamp recovery |
| Embedding / reranker | `text-embedding-bge-reranker-v2-m3` | Search in LM Studio as `bge-reranker-v2-m3` |

The current deployment uses one vision model only. The previous `LLM_SMALL_VISION_MODEL`, `LLM_LARGE_VISION_MODEL`, and per-job **Large Model** switch have been removed. Legacy API fields such as `use_large_model` may still be accepted by the backend for compatibility, but extraction always uses `LLM_VISION_MODEL`.

#### Setting up LM Studio (Embeddings / Reranker)

LM Studio runs locally and serves a local OpenAI-compatible API on port **1234** by default.

1. Download [LM Studio](https://lmstudio.ai/) and install it.
2. Search for and download the embedding model: **`bge-reranker-v2-m3`**.
3. Go to **Local Server** tab, load the model, then click **Start Server**.
4. For Docker on macOS / Windows, set `EMBEDDING_BASE_URL=http://host.docker.internal:1234/v1`.

On Linux, add this to the `backend` and `celery` services in `docker-compose.yml` if the containers need to reach a host-side model server:

```yaml
extra_hosts:
  - "host.docker.internal:host-gateway"
```

### 5. Start all services

```bash
docker compose up -d
```

Docker pulls the pre-built images on first run. To watch logs:

```bash
docker compose logs -f
```

### 6. Open the app

| Service | URL |
|---|---|
| **Frontend** | http://localhost:7676 |
| **Backend API** | http://localhost:8043 |
| **API Docs (Swagger)** | http://localhost:8043/docs |

If you changed `FRONTEND_PORT` or `BACKEND_PORT`, use those host ports in the URLs above.

If users access the app from another machine, the frontend image must be built with an upload API URL that their browser can reach, or the deployment must place the frontend and backend behind a same-origin reverse proxy. A browser on another machine cannot use `http://localhost:8043/api` to reach the Docker host. Because this is a Next.js production image, `NEXT_PUBLIC_UPLOAD_API_URL` and `NEXT_PUBLIC_PAGE_ANNOTATION_MODE` are build-time values for the frontend image.

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

## Publishing Docker Images

From the source repository root, run:

```bash
./build-and-push.sh
```

The script defaults to:

| Setting | Default |
|---|---|
| Docker Hub user | `vansonhk` |
| Image tag | `3rd-round` |
| Platforms | `linux/amd64,linux/arm64` |
| Frontend upload API URL | `http://localhost:8043/api` |
| Page annotation mode | `disabled` |

To publish a different tag or frontend upload URL:

```bash
NEXT_PUBLIC_UPLOAD_API_URL=https://your-dsb-host.example.com/api ./build-and-push.sh 3rd-round
```

Published images:

```bash
docker pull vansonhk/dsb-backend:3rd-round
docker pull vansonhk/dsb-frontend:3rd-round
```

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| Frontend shows "Cannot connect to backend" | Ensure `BACKEND_PORT` in `.env` matches the exposed port and the backend container is healthy with `docker compose ps`. |
| Extraction jobs stay Pending | Check the Celery worker logs with `docker compose logs celery`. |
| LLM errors in job output | Verify `LLM_BASE_URL`, `LLM_API_KEY`, `LLM_VISION_BASE_URL`, `LLM_VISION_API_KEY`, and model names in `.env`. |
| Port already in use | Change `FRONTEND_PORT`, `BACKEND_PORT`, `POSTGRES_PORT`, or `REDIS_PORT` in `.env` and re-run `docker compose up -d`. |
| DB connection refused | Run `docker compose ps`; the `postgres` service must be healthy before backend starts. |

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
├── docker-compose.yml        # PostgreSQL, Redis, backend, Celery, frontend
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
| PDF to Image | pdf2image (poppler) bundled in Docker image |

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
- **Vessel Name** — extracted separately from voyage number, for example `JAZAN` from `JAZAN / 1644`
- **Voyage Number**
- **Shipping Mode** (SEA, AIR, etc.)

### 4. Goods Description
- Item description, quantity, unit

## Models

Configure in `.env`:

- `LLM_VISION_MODEL` — single vision extraction model, default `qwen/qwen3.5-9b`

All jobs use this one configured vision model.

## Output Formats

- **UI Summary**: Structured, validated view per field type
- **JSON Download**: Full merged result plus page-level details
- **CSV Download**: Flat table suitable for downstream systems

## Supported Document Types

Commercial Invoice · Packing List · Bill of Lading · Air Waybill · Insurance Policy/Certificate · Certificate of Origin · Letter of Credit · Customs Invoice · Purchase Order · Contract

Supports **English and Chinese** language documents.
