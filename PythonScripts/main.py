from fastapi import FastAPI, UploadFile, File, HTTPException, Response, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response as FastAPIResponse
from sqlalchemy import create_engine, text

print("### MY FASTAPI RUNNING ###")

# ===== FastAPI =====
app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$",
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

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

# ===== business rules =====
GOAL = 10                      # カウント対象の枚数
FREE_FIRST = 1                 # 最初の1枚はノーカウント
LIMIT_PER_TITLE = GOAL + FREE_FIRST  # DB保存上限（=11）

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
    return FastAPIResponse(content=image, media_type=content_type)

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

# ★ titleごとに保存（comment も一緒に保存）
@app.post("/upload")
async def upload_image(
    title: str = Form(...),
    comment: str = Form(""),
    file: UploadFile = File(...),
):
    data = await file.read()
    if not data:
        raise HTTPException(status_code=400, detail="empty file")

    content_type = file.content_type or "application/octet-stream"
    comment = (comment or "").strip()

    with engine.begin() as conn:
        cnt = conn.execute(
            text("SELECT COUNT(*) FROM photos WHERE page_title = :t"),
            {"t": title},
        ).scalar()
        total = int(cnt or 0)

        if total >= LIMIT_PER_TITLE:
            raise HTTPException(status_code=409, detail=f"limit reached: {GOAL} (+1 free first)")

        result = conn.execute(
            text("""
                INSERT INTO photos (page_title, image, content_type, comment)
                VALUES (:t, :img, :ct, :cmt)
            """),
            {"t": title, "img": data, "ct": content_type, "cmt": comment},
        )
        new_id = int(result.lastrowid)

        new_cnt = conn.execute(
            text("SELECT COUNT(*) FROM photos WHERE page_title = :t"),
            {"t": title},
        ).scalar()

    total2 = int(new_cnt or 0)
    remaining = calc_remaining(total2)
    return {"ok": True, "title": title, "photo_id": new_id, "count": total2, "remaining": remaining}

# 写真ID一覧（互換用）
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

# ★ アルバム表示用：id と comment をまとめて返す
@app.get("/photos/list")
def photo_list(title: str):
    with engine.begin() as conn:
        rows = conn.execute(
            text("""
                SELECT id, COALESCE(comment, '') AS comment
                FROM photos
                WHERE page_title = :t
                ORDER BY id ASC
            """),
            {"t": title},
        ).fetchall()

    photos = [{"id": int(r[0]), "comment": (r[1] or "")} for r in rows]
    return {"ok": True, "title": title, "photos": photos}

# 写真1枚を返す
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
    return FastAPIResponse(content=image, media_type=content_type)

# ★ コメントだけ後から更新したい場合（任意）
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

        # 既存テーブルが古くて comment 列が無い場合に備えて追加（失敗しても無視）
        try:
            conn.execute(text("ALTER TABLE photos ADD COLUMN comment TEXT NULL"))
        except Exception:
            pass

        # site_state
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS site_state (
              id TINYINT UNSIGNED NOT NULL,
              page_title VARCHAR(255) NOT NULL,
              updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
                ON UPDATE CURRENT_TIMESTAMP,
              PRIMARY KEY (id)
            )
        """))
