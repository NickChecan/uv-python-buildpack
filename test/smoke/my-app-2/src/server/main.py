from fastapi import FastAPI
import uvicorn

app = FastAPI()


@app.get("/")
def hello_world():
    return {"message": "Hello, World!"}


def start():
    uvicorn.run("server.main:app", host="0.0.0.0", port=8000, reload=True)