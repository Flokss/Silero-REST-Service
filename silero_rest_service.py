from fastapi import FastAPI, HTTPException
from starlette.responses import Response
import uvicorn
import multiprocessing
import os
import torch
from ruaccent import RUAccent
from num2words import num2words
import re

version = "1.0"
model = None
accentizer = None

# Инициализация FastAPI приложения
app = FastAPI()


@app.on_event("startup")
async def startup_event():
    global model, accentizer
    modelurl = 'https://models.silero.ai/models/tts/ru/v4_ru.pt'

    device = torch.device('cpu')
    torch.set_num_threads(4)
    local_file = 'silero_model.pt'

    if not os.path.isfile(local_file):
        print("Downloading Silero TTS model...")
        torch.hub.download_url_to_file(modelurl, local_file)

    try:
        model = torch.package.PackageImporter(local_file).load_pickle("tts_models", "model")
        model.to(device)
        print("Model loaded successfully")
    except Exception as e:
        print(f"Failed to load model: {e}")
        model = None

    # Инициализация RUAccent
    accentizer = RUAccent()
    accentizer.load(omograph_model_size='turbo', use_dictionary=True)


@app.on_event("shutdown")
async def shutdown_event():
    global model
    model = None
    print("Model unloaded")


def replace_numbers_with_words(text):
    def convert(match):
        return num2words(int(match.group()), lang='ru')

    # Заменяем все числа в тексте на их словесное представление
    return re.sub(r'\d+', convert, text)


@app.get(
    "/getwav",
    responses={
        200: {
            "content": {"audio/wav": {}}
        }
    },
    response_class=Response
)
async def getwav(text_to_speech: str, speaker: str = "xenia", sample_rate: int = 24000, apply_accent: bool = False):
    """
    Возвращает WAV файл с синтезированным текстом
    """
    if model is None:
        raise HTTPException(status_code=500, detail="Model is not loaded")

    # Преобразуем числа в текст
    text_to_speech = replace_numbers_with_words(text_to_speech)

    if apply_accent:
        text_to_speech = accentizer.process_all(text_to_speech)

    path = model.save_wav(text=text_to_speech, speaker=speaker, sample_rate=sample_rate)

    with open(path, "rb") as in_file:
        data = in_file.read()

    return Response(content=data, media_type="audio/wav")


if __name__ == "__main__":
    multiprocessing.freeze_support()
    print(f"Running silero_rest_service server v{version}...")
    uvicorn.run("silero_rest_service:app", host="0.0.0.0", port=5010, log_level="info")
