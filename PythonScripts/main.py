from fastapi import FastAPI, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pathlib import Path
import uuid

from sqlalchemy import create_engine, text

# ===== FastAPI =====
app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ===== MySQL =====
DATABASE_URL = "mysql+pymysql://flutter_user:root@localhost:3306/flutter_db"

engine = create_engine(
    DATABASE_URL,
    pool_pre_ping=True,
    echo=True,
)

# ===== Upload dir =====
UPLOAD_DIR = Path("uploads")
UPLOAD_DIR.mkdir(exist_ok=True)

app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

# ===== APIs =====

@app.get("/health")
def health():
    return {"status": "ok"}

@app.post("/upload")
async def upload_image(file: UploadFile = File(...)):
    suffix = Path(file.filename).suffix.lower()
    if suffix not in [".jpg", ".jpeg", ".png", ".webp"]:
        suffix = ".jpg"

    save_name = f"{uuid.uuid4().hex}{suffix}"
    save_path = UPLOAD_DIR / save_name

    data = await file.read()
    save_path.write_bytes(data)

    url = f"/uploads/{save_name}"

    # MySQL に保存
    with engine.begin() as conn:
        conn.execute(
            text(
                "INSERT INTO photos (filename, url) VALUES (:filename, :url)"
            ),
            {"filename": save_name, "url": url},
        )

        #　今の保存枚数を取得(件数を必ず取る)
        count = conn.execute(
            text("SELECT COUNT(*) AS count FROM photos")
        ).mappings().first()["count"]

    return {"ok": True, "filename": save_name, "url": url, "count": int(count)}

# 枚数取得API
@app.get("/photos/count")
def photos_count():
    with engine.connect() as conn:
        cnt = conn.execute(text("SELECT COUNT(*) AS cnt FROM photos")).mappings().first()["cnt"]
    return {"ok": True, "count": cnt}

from fastapi.staticfiles import StaticFiles

app.mount(
    "/",
    StaticFiles(
        directory="../WebApplication/flutter_client/build/web",
        html=True
    ),
    name="flutter"
)


