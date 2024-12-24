from fastapi import FastAPI, HTTPException
from starlette.responses import Response
import uvicorn
import torch
from ruaccent import RUAccent
import os
from num2words import num2words  # Библиотека для преобразования чисел в слова

app = FastAPI()

version = "1.0"
model = None
accentizer = None


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
        print("TTS Model loaded successfully")
    except Exception as e:
        print(f"Failed to load TTS model: {e}")
        model = None

    try:
        accentizer = RUAccent()
        accentizer.load(omograph_model_size='turbo', use_dictionary=True)
        print("RUAccent model loaded successfully")
    except Exception as e:
        print(f"Failed to load RUAccent model: {e}")


def preprocess_text(text):
    """Преобразует цифры в текстовый формат."""
    words = text.split()
    processed_words = []
    for word in words:
        if word.isdigit():
            try:
                word = num2words(int(word), lang='ru')
            except Exception as e:
                print(f"Failed to convert number {word} to words: {e}")
        processed_words.append(word)
    return " ".join(processed_words)


@app.get(
    "/getwav",
    responses={200: {"content": {"audio/wav": {}}}},
    response_class=Response
)
async def getwav(text_to_speech: str, speaker: str = "xenia", sample_rate: int = 24000):
    if model is None:
        raise HTTPException(status_code=500, detail="TTS model is not loaded")
    
    preprocessed_text = preprocess_text(text_to_speech)
    accented_text = accentizer.process_all(preprocessed_text) if accentizer else preprocessed_text
    print(f"Text after accent processing: {accented_text}")
    
    wavfile = "temp.wav"
    path = model.save_wav(text=accented_text, speaker=speaker, sample_rate=sample_rate)
    
    with open(path, "rb") as in_file:
        data = in_file.read()
    
    return Response(content=data, media_type="audio/wav")

if __name__ == "__main__":
    uvicorn.run("silero_rest_service:app", host="0.0.0.0", port=5010, log_level="info")
