from fastapi import FastAPI, UploadFile, File, HTTPException, Response, Form
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import create_engine, text

print("### MY FASTAPI RUNNING ###")

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.options("/upload")
def options_upload():
    return Response(status_code=204)

DATABASE_URL = "mysql+pymysql://flutter_user:root@localhost:3306/flutter_db"

engine = create_engine(
    DATABASE_URL,
    pool_pre_ping=True,
    echo=True,
)

GOAL = 10                      # カウント対象の枚数
FREE_FIRST = 1                 # 最初の1枚はノーカウント
LIMIT_PER_TITLE = GOAL + FREE_FIRST  # DB保存上限（=26）

def calc_remaining(total_saved: int) -> int:
    # total_saved: DBに保存されている枚数（最初の1枚も含む）
    counted = max(0, total_saved - FREE_FIRST)  # 2枚目以降だけ数える
    return max(0, GOAL - counted)

@app.get("/health")
def health():
    return {"status": "ok"}

# 最初の写真を返す
@app.get("/photos/first")
def get_first_photo(title: str):
    with engine.begin() as conn:
        row = conn.execute(
            text("""
                SELECT image, content_type
                FROM photos
                WHERE page_title = :t
                ORDER BY id ASC
                LIMIT 1
            """),
            {"t": title},
        ).first()

    if not row:
        raise HTTPException(status_code=404, detail="no photo")

    image, content_type = row
    return Response(content=image, media_type=content_type)

# ★ titleごとの枚数と残りを返す
@app.get("/photos/count")
def photos_count(title: str):
    with engine.begin() as conn:
        cnt = conn.execute(
            text("SELECT COUNT(*) FROM photos WHERE page_title = :t"),
            {"t": title},
        ).scalar()

    total = int(cnt or 0)
    remaining = calc_remaining(total)
    return {"ok": True, "title": title, "count": total, "remaining": remaining}

# ★ titleごとに保存し、26枚で制限（=最初の1枚はノーカウント）
@app.post("/upload")
async def upload_image(
    title: str = Form(...),
    file: UploadFile = File(...),
):
    data = await file.read()
    if not data:
        raise HTTPException(status_code=400, detail="empty file")

    content_type = file.content_type or "application/octet-stream"

    with engine.begin() as conn:
        cnt = conn.execute(
            text("SELECT COUNT(*) FROM photos WHERE page_title = :t"),
            {"t": title},
        ).scalar()
        total = int(cnt or 0)

        if total >= LIMIT_PER_TITLE:
            raise HTTPException(status_code=409, detail=f"limit reached: {GOAL} (+1 free first)")

        conn.execute(
            text("INSERT INTO photos (page_title, image, content_type) VALUES (:t, :img, :ct)"),
            {"t": title, "img": data, "ct": content_type},
        )

        new_cnt = conn.execute(
            text("SELECT COUNT(*) FROM photos WHERE page_title = :t"),
            {"t": title},
        ).scalar()

    total2 = int(new_cnt or 0)
    remaining = calc_remaining(total2)
    return {"ok": True, "title": title, "count": total2, "remaining": remaining}

# テーブルの自動生成
@app.on_event("startup")
def init_db():
    with engine.begin() as conn:
                conn.execute(text("""
            CREATE TABLE IF NOT EXISTS site_state (
              id TINYINT UNSIGNED NOT NULL,
              page_title VARCHAR(255) NOT NULL,
              updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
                ON UPDATE CURRENT_TIMESTAMP,
              PRIMARY KEY (id)
            )
        """))

#写真ID一覧を返す
@app.get("/photos/ids")
def photo_ids(title: str):
    with engine.begin() as conn:
        rows = conn.execute(
            text("""
                SELECT id
                FROM photos
                WHERE page_title = :t
                ORDER BY id ASC
            """),
            {"t": title},
        ).fetchall()

    return {"ok": True, "title": title, "ids": [int(r[0]) for r in rows]}

from fastapi.responses import Response

#写真1枚を返す
@app.get("/photos/{photo_id}")
def get_photo(photo_id: int):
    with engine.begin() as conn:
        row = conn.execute(
            text("""
                SELECT image, content_type
                FROM photos
                WHERE id = :id
                LIMIT 1
            """),
            {"id": photo_id},
        ).first()

    if not row:
        raise HTTPException(status_code=404, detail="not found")

    image, content_type = row
    return Response(content=image, media_type=content_type)

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

