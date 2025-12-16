from fastapi import FastAPI, UploadFile, File, HTTPException, Response, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response as FastAPIResponse
from sqlalchemy import create_engine, text

print("### MY FASTAPI RUNNING ###")

app = FastAPI()

# Flutter Web（localhost/127.0.0.1）からのアクセスを許可
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$",
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# プリフライト(OPTIONS)を明示的に通す
@app.options("/upload")
def options_upload():
    return Response(status_code=204)

# ===== MySQL =====
DATABASE_URL = "mysql+pymysql://flutter_user:root@localhost:3306/flutter_db"

engine = create_engine(
    DATABASE_URL,
    pool_pre_ping=True,
    echo=True,
)

GOAL = 25

# ===== DB init =====
@app.on_event("startup")
def init_db():
    with engine.begin() as conn:
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS photos (
              id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
              image LONGBLOB NOT NULL,
              content_type VARCHAR(64) NOT NULL,
              title TEXT NULL,
              created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
              PRIMARY KEY (id)
            )
        """))

        # 既存DBに title が無い場合に備えて追加を試す
        try:
            conn.execute(text("ALTER TABLE photos ADD COLUMN title TEXT NULL"))
        except Exception:
            pass

# ===== APIs =====

@app.get("/health")
def health():
    return {"status": "ok"}

@app.get("/photos/count")
def photos_count():
    with engine.begin() as conn:
        cnt = conn.execute(text("SELECT COUNT(*) FROM photos")).scalar()
    return {"ok": True, "count": int(cnt or 0)}

@app.post("/upload")
async def upload_image(
    file: UploadFile = File(...),
    title: str = Form(""),  # ← Flutterから同梱される文字
):
    data = await file.read()
    if not data:
        raise HTTPException(status_code=400, detail="empty file")

    content_type = file.content_type or "application/octet-stream"

    with engine.begin() as conn:
        cnt = int(conn.execute(text("SELECT COUNT(*) FROM photos")).scalar() or 0)
        if cnt >= GOAL:
            # 25枚到達時は 409 を返す（Flutter側で準備中へ）
            raise HTTPException(status_code=409, detail=f"limit reached: {GOAL}")

        conn.execute(
            text("INSERT INTO photos (image, content_type, title) VALUES (:img, :ct, :title)"),
            {"img": data, "ct": content_type, "title": title},
        )

        new_cnt = int(conn.execute(text("SELECT COUNT(*) FROM photos")).scalar() or 0)

    return {"ok": True, "count": new_cnt}

@app.get("/photos")
def list_photos(limit: int = 20, offset: int = 0):
    # 画像は返さず、メタ情報だけ返す（安全＆軽い）
    with engine.begin() as conn:
        rows = conn.execute(
            text("""
                SELECT id, title, created_at
                FROM photos
                ORDER BY id DESC
                LIMIT :limit OFFSET :offset
            """),
            {"limit": limit, "offset": offset},
        ).fetchall()

    return {
        "ok": True,
        "items": [
            {
                "id": int(r.id),
                "title": r.title,
                "created_at": r.created_at.isoformat() if r.created_at else None,
            }
            for r in rows
        ],
    }

@app.get("/photos/{photo_id}")
def get_photo(photo_id: int):
    # 画像本体を返す（ブラウザで確認用）
    with engine.begin() as conn:
        row = conn.execute(
            text("""
                SELECT image, content_type
                FROM photos
                WHERE id = :id
            """),
            {"id": photo_id},
        ).fetchone()

    if not row:
        raise HTTPException(status_code=404, detail="not found")

    return FastAPIResponse(content=row.image, media_type=row.content_type)
