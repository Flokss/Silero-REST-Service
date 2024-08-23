from fastapi import FastAPI, HTTPException
from starlette.responses import Response
import uvicorn
import torch
from rupo.stress.predictor import StressPredictor
from ruaccent import RUAccent

app = FastAPI()

version = "1.0"
model = None
accentizer = None
stress_predictor = None

@app.on_event("startup")
async def startup_event():
    global model, accentizer, stress_predictor
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

    try:
        stress_predictor = StressPredictor()
        stress_predictor.load()
        print("Rupo Stress Predictor loaded successfully")
    except Exception as e:
        print(f"Failed to load Rupo Stress Predictor: {e}")

@app.get(
    "/getwav",
    responses={200: {"content": {"audio/wav": {}}}},
    response_class=Response
)
async def getwav(text_to_speech: str, speaker: str = "xenia", sample_rate: int = 24000):
    if model is None:
        raise HTTPException(status_code=500, detail="TTS model is not loaded")
    
    accented_text = accentizer.process_all(text_to_speech) if accentizer else text_to_speech
    print(f"Text after accent processing: {accented_text}")
    
    wavfile = "temp.wav"
    path = model.save_wav(text=accented_text, speaker=speaker, sample_rate=sample_rate)
    
    with open(path, "rb") as in_file:
        data = in_file.read()
    
    return Response(content=data, media_type="audio/wav")

if __name__ == "__main__":
    uvicorn.run("silero_rest_service:app", host="0.0.0.0", port=8000, log_level="info")
