from fastapi import FastAPI, UploadFile, File, HTTPException, Response
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import create_engine, text

print("### MY FASTAPI RUNNING ###")  # 起動ログに出るか必ず確認

app = FastAPI()

# ★ localhost と 127.0.0.1 の「どっちのOriginでも」許可する（Flutter Web対策）
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$",
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ★ プリフライト(OPTIONS)を明示的に通す
@app.options("/upload")
def options_upload():
    return Response(status_code=204)

DATABASE_URL = "mysql+pymysql://flutter_user:root@localhost:3306/flutter_db"

engine = create_engine(
    DATABASE_URL,
    pool_pre_ping=True,
    echo=True,
)

GOAL = 25

@app.get("/health")
def health():
    return {"status": "ok"}

@app.get("/photos/count")
def photos_count():
    with engine.begin() as conn:
        cnt = conn.execute(text("SELECT COUNT(*) FROM photos")).scalar()
    return {"ok": True, "count": int(cnt or 0)}

@app.post("/upload")
async def upload_image(file: UploadFile = File(...)):
    data = await file.read()
    if not data:
        raise HTTPException(status_code=400, detail="empty file")

    content_type = file.content_type or "application/octet-stream"

    with engine.begin() as conn:
        cnt = int(conn.execute(text("SELECT COUNT(*) FROM photos")).scalar() or 0)
        if cnt >= GOAL:
            raise HTTPException(status_code=409, detail=f"limit reached: {GOAL}")

        conn.execute(
            text("INSERT INTO photos (image, content_type) VALUES (:img, :ct)"),
            {"img": data, "ct": content_type},
        )

        new_cnt = int(conn.execute(text("SELECT COUNT(*) FROM photos")).scalar() or 0)

    return {"ok": True, "count": new_cnt}

@app.on_event("startup")
def init_db():
    with engine.begin() as conn:
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS photos (
              id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
              image LONGBLOB NOT NULL,
              content_type VARCHAR(64) NOT NULL,
              created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
              PRIMARY KEY (id)
            )
        """))
