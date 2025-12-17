import os
import time
import uuid
from pathlib import Path

from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from fastapi.staticfiles import StaticFiles

from sqlalchemy import create_engine, text
from fastapi.responses import FileResponse
import os


print("### MY FASTAPI RUNNING ###")

# =========================
# FastAPI
# =========================
app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# =========================
# Database
# =========================
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "mysql+pymysql://flutter_user:root@localhost:3306/flutter_db",
)

engine = create_engine(
    DATABASE_URL,
    pool_pre_ping=True,
    echo=True,
)

# =========================
# Upload directory
# =========================
UPLOAD_DIR = Path("uploads")
UPLOAD_DIR.mkdir(exist_ok=True)

app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

# =========================
# Startup: init DB (retry)
# =========================
@app.on_event("startup")
def init_db():
    last_err = None

    # MySQL が ready になるまで最大20秒待つ
    for _ in range(20):
        try:
            with engine.begin() as conn:
                # photos テーブル
                conn.execute(text("""
                    CREATE TABLE IF NOT EXISTS photos (
                      id INT UNSIGNED NOT NULL AUTO_INCREMENT,
                      page_title VARCHAR(255) NOT NULL,
                      image LONGBLOB NOT NULL,
                      content_type VARCHAR(255) NOT NULL,
                      comment TEXT NULL,
                      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                      PRIMARY KEY (id),
                      INDEX idx_photos_title (page_title)
                    )
                """))

                # site_state テーブル
                conn.execute(text("""
                    CREATE TABLE IF NOT EXISTS site_state (
                      id TINYINT UNSIGNED NOT NULL,
                      page_title VARCHAR(255) NOT NULL,
                      updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
                        ON UPDATE CURRENT_TIMESTAMP,
                      PRIMARY KEY (id)
                    )
                """))

            print("### DB READY ###")
            return

        except Exception as e:
            last_err = e
            time.sleep(1)

    raise RuntimeError(f"DB not ready: {last_err}")

# =========================
# Health check
# =========================
@app.get("/health")
def health():
    return {"status": "ok"}

# =========================
# Upload image
# =========================
@app.post("/upload")
async def upload_image(
    title: str,
    file: UploadFile = File(...),
):
    data = await file.read()

    with engine.begin() as conn:
        conn.execute(
            text("""
                INSERT INTO photos (page_title, image, content_type)
                VALUES (:title, :image, :ctype)
            """),
            {
                "title": title,
                "image": data,
                "ctype": file.content_type,
            }
        )

    return {"result": "ok"}

# =========================
# Get image
# =========================
@app.get("/photos/{photo_id}")
def get_photo(photo_id: int):
    with engine.begin() as conn:
        row = conn.execute(
            text("""
                SELECT image, content_type
                FROM photos
                WHERE id = :id
            """),
            {"id": photo_id}
        ).fetchone()

    if not row:
        raise HTTPException(status_code=404, detail="Photo not found")

    image, content_type = row
    return FastAPIResponse(content=image, media_type=content_type)

# コメントだけ後から更新したい場合（任意）
@app.post("/photos/{photo_id}/comment")
def set_photo_comment(photo_id: int, comment: str = Form("")):
    comment = (comment or "").strip()
    with engine.begin() as conn:
        updated = conn.execute(
            text("UPDATE photos SET comment = :cmt WHERE id = :id"),
            {"cmt": comment, "id": photo_id},
        ).rowcount

    if not updated:
        raise HTTPException(status_code=404, detail="not found")

    return {"ok": True, "photo_id": photo_id, "comment": comment}

# 現在のタイトルを返す
@app.get("/site/title")
def get_site_title():
    with engine.begin() as conn:
        row = conn.execute(
            text("SELECT page_title FROM site_state WHERE id = 1")
        ).first()

    if not row:
        return {"exists": False}

    return {"exists": True, "title": row[0]}

# タイトルを保存する
@app.post("/site/title")
def set_site_title(title: str = Form(...)):
    title = title.strip()
    if not title:
        raise HTTPException(status_code=400, detail="empty title")

    with engine.begin() as conn:
        conn.execute(
            text("""
                INSERT INTO site_state (id, page_title)
                VALUES (1, :t)
                ON DUPLICATE KEY UPDATE page_title = :t
            """),
            {"t": title},
        )

    return {"ok": True, "title": title}

# テーブルの自動生成（起動時）
@app.on_event("startup")
def init_db():
    with engine.begin() as conn:
        # photos
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS photos (
              id INT UNSIGNED NOT NULL AUTO_INCREMENT,
              page_title VARCHAR(255) NOT NULL,
              image LONGBLOB NOT NULL,
              content_type VARCHAR(255) NOT NULL,
              comment TEXT NULL,
              created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
              PRIMARY KEY (id),
              INDEX idx_photos_title (page_title)
            )
        """))

        # site_state ← ★これが足りなかった
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS site_state (
              id INT NOT NULL,
              page_title VARCHAR(255) NOT NULL,
              PRIMARY KEY (id)
            )
        """))


from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse

# Flutter Web のビルドディレクトリ
WEB_DIR = "../WebApplication/flutter_client/build/web"

# Flutter の static ファイルを /static にマウント
app.mount(
    "/static",
    StaticFiles(directory=WEB_DIR),
    name="static"
)

# / にアクセスしたら index.html を返す
@app.get("/")
def root():
    return FileResponse(os.path.join(WEB_DIR, "index.html"))


