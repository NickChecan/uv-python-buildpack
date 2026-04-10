import os

from fastapi import FastAPI
import uvicorn

app = FastAPI()


@app.get("/")
def hello_world():
    return {"message": "Hello, World!"}

if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8000"))
    uvicorn.run("my_app_manifest.main:app", host="0.0.0.0", port=port, reload=False)
