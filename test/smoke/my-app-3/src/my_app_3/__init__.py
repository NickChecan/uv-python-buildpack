import uvicorn

def main() -> None:
    uvicorn.run("my_app_3.main:app", host="0.0.0.0", port=8000, reload=True)