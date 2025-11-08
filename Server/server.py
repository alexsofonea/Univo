import os
import base64
import tempfile
import json
import traceback
from typing import Any, Dict, Optional, List, Tuple

import httpx
from fastapi import FastAPI, Request, HTTPException
import argparse

# =========================
# Config
# =========================

VLLM_URL = os.environ.get("VLLM_URL", "http://localhost:6162/v1/chat/completions")

ASR_MODEL_ID = os.environ.get("ASR_MODEL_ID", "openai/whisper-large-v3-turbo")

# Default TTS = Kokoro (hexgrad/Kokoro-82M)
# We treat any TTS_MODEL_ID containing "kokoro" as "use Kokoro backend".
TTS_MODEL_ID = os.environ.get("TTS_MODEL_ID", "hexgrad/Kokoro-82M")

# Kokoro options
KOKORO_LANG = os.environ.get("KOKORO_LANG", "a")           # 'a' American English (see Kokoro docs for others)
KOKORO_VOICE = os.environ.get("KOKORO_VOICE", "af_heart")  # must exist in Kokoro VOICES list

# =========================
# Globals
# =========================

ASR_PIPELINE = None
ASR_STATUS: Dict[str, Any] = {"state": "not_loaded", "message": "not started"}

# _TTS_MODEL: (backend, model_obj, model_id_or_desc)
# backend: "kokoro" or "hf"
_TTS_MODEL: Optional[Tuple[str, Any, str]] = None
_TTS_STATUS: Dict[str, Any] = {"state": "not_loaded", "message": "not started"}

app = FastAPI(title="VLLM Orchestrator (ASR+TTS)")


# =========================
# Helpers
# =========================

def decode_base64_to_file(b64: str, suffix: str = ".wav") -> str:
    if b64.startswith("data:audio") and ";base64," in b64:
        b64 = b64.split(",", 1)[1]
    data = base64.b64decode(b64)
    tmp = tempfile.NamedTemporaryFile(delete=False, suffix=suffix)
    tmp.write(data)
    tmp.flush()
    tmp.close()
    return tmp.name


def encode_file_to_base64(path: str) -> str:
    with open(path, "rb") as f:
        data = f.read()
    return base64.b64encode(data).decode("ascii")


def _is_base64_audio_string(s: str) -> bool:
    """Heuristic: does this string look like base64-encoded audio."""
    if not isinstance(s, str):
        return False

    # data URI support
    if s.startswith("data:audio") and ";base64," in s:
        s = s.split(",", 1)[1]

    if len(s) < 64:
        return False

    try:
        raw = base64.b64decode(s, validate=True)
    except Exception:
        return False

    if len(raw) < 256:
        return False

    sig4 = raw[:4]
    sig8 = raw[:8]

    # WAV
    if sig4 == b"RIFF":
        return True
    # OGG
    if sig4 == b"OggS":
        return True
    # MP3 (ID3 header)
    if raw[:3] == b"ID3":
        return True
    # FLAC
    if sig4 == b"fLaC":
        return True
    # MP4/M4A/ISO BMFF
    if sig8[4:8] == b"ftyp":
        return True

    # Fallback: big opaque blob → likely audio
    return len(raw) > 2000


# =========================
# ASR (Whisper)
# =========================

def get_asr_pipeline():
    global ASR_PIPELINE, ASR_STATUS

    if ASR_PIPELINE is not None:
        return ASR_PIPELINE

    try:
        import torch
        from transformers import AutoModelForSpeechSeq2Seq, AutoProcessor, pipeline
    except Exception as e:
        ASR_STATUS.update({"state": "error", "message": f"missing ASR deps: {e}"})
        raise RuntimeError(f"missing ASR dependencies: {e}")

    device = 0 if torch.cuda.is_available() else -1
    torch_dtype = torch.float16 if torch.cuda.is_available() else None

    print(f"[ASR] Loading model {ASR_MODEL_ID} on device {device}")
    ASR_STATUS.update({"state": "loading", "message": f"loading {ASR_MODEL_ID}"})

    try:
        model = AutoModelForSpeechSeq2Seq.from_pretrained(
            ASR_MODEL_ID,
            torch_dtype=torch_dtype,
            low_cpu_mem_usage=True,
        )
        processor = AutoProcessor.from_pretrained(ASR_MODEL_ID)
        ASR_PIPELINE = pipeline(
            "automatic-speech-recognition",
            model=model,
            tokenizer=processor.tokenizer,
            feature_extractor=processor.feature_extractor,
            device=device,
        )
        ASR_STATUS.update({"state": "ready", "message": f"ready on device {device}"})
    except Exception as e:
        ASR_STATUS.update({"state": "error", "message": str(e)})
        traceback.print_exc()
        raise

    return ASR_PIPELINE


def preload_asr_model(model_id: Optional[str] = None):
    global ASR_MODEL_ID
    if model_id:
        ASR_MODEL_ID = model_id
    get_asr_pipeline()


def transcribe_file_with_asr(path: str) -> str:
    pipe = get_asr_pipeline()
    out = pipe(path)
    if isinstance(out, dict) and "text" in out:
        text = out["text"]
    elif isinstance(out, list) and out and isinstance(out[0], dict) and "text" in out[0]:
        text = out[0]["text"]
    else:
        text = str(out)
    print(f"[ASR] Transcription: {text}")
    return text


# =========================
# TTS Backends
# =========================

def _load_kokoro_tts():
    """
    Load Kokoro via KPipeline.

    Uses hexgrad/Kokoro-82M under the hood (managed by kokoro lib).
    """
    from kokoro import KPipeline

    print(f"[TTS] Loading Kokoro (lang={KOKORO_LANG}, voice={KOKORO_VOICE})")
    # KPipeline chooses device internally; no need to pass device explicitly.
    pipe = KPipeline(lang_code=KOKORO_LANG)
    return pipe, KOKORO_VOICE


def _load_hf_tts(model_id: str):
    """
    Generic Hugging Face text-to-speech pipeline as fallback.
    """
    import torch
    from transformers import pipeline

    device = 0 if torch.cuda.is_available() else -1
    print(f"[TTS] Loading HF TTS pipeline {model_id} on device {device}")
    return pipeline(
        "text-to-speech",
        model=model_id,
        device=device,
        trust_remote_code=True,
    )


def preload_tts_model(model_id: Optional[str] = None):
    """
    Initialize TTS backend based on TTS_MODEL_ID.

    - If TTS_MODEL_ID contains "kokoro" → use Kokoro
    - Else → use HF TTS pipeline
    """
    global _TTS_MODEL, _TTS_STATUS, TTS_MODEL_ID

    if model_id:
        TTS_MODEL_ID = model_id

    mid = (TTS_MODEL_ID or "").lower()
    _TTS_STATUS.update({"state": "loading", "message": f"loading {TTS_MODEL_ID}"})

    try:
        if "kokoro" in mid:
            pipe, voice = _load_kokoro_tts()
            _TTS_MODEL = ("kokoro", (pipe, voice), TTS_MODEL_ID)
            _TTS_STATUS.update({"state": "ready", "message": f"Kokoro ready ({TTS_MODEL_ID})"})
        else:
            tts_pipe = _load_hf_tts(TTS_MODEL_ID)
            _TTS_MODEL = ("hf", tts_pipe, TTS_MODEL_ID)
            _TTS_STATUS.update({"state": "ready", "message": f"HF TTS ready ({TTS_MODEL_ID})"})

        return _TTS_MODEL

    except Exception as e:
        _TTS_MODEL = None
        msg = f"TTS failed: {e}"
        print("[TTS]", msg)
        traceback.print_exc()
        _TTS_STATUS.update({"state": "error", "message": msg})
        return None


def get_tts_model():
    global _TTS_MODEL
    if _TTS_MODEL is not None:
        return _TTS_MODEL
    return preload_tts_model()


def _write_wav_base64_from_np(audio_np, sr: int = 24000) -> Optional[str]:
    import numpy as np
    import wave

    if audio_np is None:
        return None

    audio_np = np.asarray(audio_np)

    # mono
    if audio_np.ndim > 1:
        audio_np = audio_np.mean(axis=-1)

    if audio_np.size == 0:
        print("[TTS] empty audio array")
        return None

    # normalize to [-1, 1]
    audio_float = audio_np.astype("float32")
    max_abs = float(np.max(np.abs(audio_float)))
    if max_abs == 0:
        print("[TTS] silent audio")
        return None
    if max_abs > 1.0:
        audio_float /= max_abs

    audio_int16 = (audio_float * 32767.0).clip(-32768, 32767).astype("int16")

    tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".wav")
    tmp_path = tmp.name
    tmp.close()

    try:
        with wave.open(tmp_path, "wb") as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)  # 16-bit
            wf.setframerate(sr)
            wf.writeframes(audio_int16.tobytes())
        return encode_file_to_base64(tmp_path)
    finally:
        try:
            os.remove(tmp_path)
        except Exception:
            pass


def synthesize_text_to_base64(text: str) -> Optional[str]:
    if not text or not text.strip():
        return None

    tts_info = get_tts_model()
    if not tts_info:
        print("[TTS] No TTS backend available")
        return None

    backend, model, used_id = tts_info

    try:
        # =====================
        # Kokoro backend
        # =====================
        if backend == "kokoro":
            import numpy as np

            pipe, voice = model
            print(f"[TTS][Kokoro] Synthesizing: {text!r} (voice={voice})")

            # Official pattern: generator yields (global_scores, partial_scores, audio)
            gen = pipe(text, voice=voice)  # you can add speed=1.0, split_pattern=... if needed

            chunks: List[np.ndarray] = []
            for i, (gs, ps, audio) in enumerate(gen):
                # audio is np.ndarray, 1D float32 in [-1, 1]
                if audio is not None and len(audio) > 0:
                    chunks.append(audio)

            if not chunks:
                print("[TTS][Kokoro] No audio chunks produced (check kokoro/espeak install & voice/lang).")
                return None

            audio_np = np.concatenate(chunks, axis=0)
            return _write_wav_base64_from_np(audio_np, sr=24000)

        # =====================
        # HF backend
        # =====================
        if backend == "hf":
            import numpy as np

            print(f"[TTS][HF] Synthesizing with {used_id}: {text!r}")
            out = model(text, forward_params={"do_sample": False})

            audio = None
            sr = 24000

            if isinstance(out, dict):
                audio = out.get("audio") or out.get("audio_values")
                sr = out.get("sampling_rate", sr)
            else:
                audio = out

            if audio is None:
                print("[TTS][HF] No audio field in output")
                return None

            try:
                sr = int(sr)
            except Exception:
                sr = 24000
            if sr <= 0 or sr > 192000:
                sr = 24000

            audio_np = np.asarray(audio)
            return _write_wav_base64_from_np(audio_np, sr=sr)

        print(f"[TTS] Unexpected backend={backend}, skipping")
        return None

    except Exception as e:
        print(f"[TTS] synthesis failed: {e}")
        traceback.print_exc()
        return None


# =========================
# vLLM Forward
# =========================

async def forward_to_vllm(payload: Dict[str, Any]) -> Dict[str, Any]:
    async with httpx.AsyncClient(timeout=120.0) as client:
        resp = await client.post(VLLM_URL, json=payload)
        try:
            return resp.json()
        except Exception:
            raise HTTPException(status_code=502, detail=f"vLLM returned non-JSON: {resp.text}")


# =========================
# API
# =========================

@app.get("/health")
async def health():
    return {"status": "ok"}


@app.get("/models/whisper/status")
async def whisper_status():
    return ASR_STATUS


@app.get("/models/tts/status")
async def tts_status():
    return _TTS_STATUS


@app.post("/v1/chat/completions")
async def chat_completions(request: Request):
    payload = await request.json()
    print("\n📥 [REQ] keys:", list(payload.keys()))

    forwarding = dict(payload)
    messages = forwarding.get("messages") or []

    # --- 1) Only touch the LAST user message (ASR on audio) ---
    if isinstance(messages, list) and messages:
        messages = list(messages)

        for idx in range(len(messages) - 1, -1, -1):
            m = messages[idx]
            if not isinstance(m, dict) or m.get("role") != "user":
                continue

            content = m.get("content")

            # Case A: plain string that is base64 audio
            if isinstance(content, str) and _is_base64_audio_string(content):
                print(f"[ASR] Detected base64 audio in messages[{idx}] (string)")
                tmp = decode_base64_to_file(content)
                try:
                    text = transcribe_file_with_asr(tmp)
                    messages[idx]["content"] = text
                    print(f"🎤 [ASR] messages[{idx}] -> {text!r}")
                finally:
                    try:
                        os.remove(tmp)
                    except Exception:
                        pass
                break

            # Case B: multimodal-style array of parts
            if isinstance(content, list):
                new_parts: List[Dict[str, Any]] = []

                for part_idx, part in enumerate(content):
                    if not isinstance(part, dict):
                        new_parts.append(part)
                        continue

                    p_type = part.get("type")

                    # Pass images through unchanged
                    if p_type == "image_url":
                        new_parts.append(part)
                        continue

                    # Text: could be base64 audio or real text
                    if p_type == "text" and isinstance(part.get("text"), str):
                        txt = part["text"]
                        if _is_base64_audio_string(txt):
                            print(f"[ASR] Detected base64 audio in messages[{idx}] text-part")
                            tmp = decode_base64_to_file(txt)
                            try:
                                t = transcribe_file_with_asr(tmp)
                                print(f"🎤 [ASR] messages[{idx}] part[{part_idx}] -> {t!r}")
                                new_parts.append({"type": "text", "text": t})
                            finally:
                                try:
                                    os.remove(tmp)
                                except Exception:
                                    pass
                        else:
                            new_parts.append(part)
                        continue

                    # Explicit audio attributes
                    candidate = None
                    if isinstance(part.get("audio"), str):
                        candidate = part["audio"]
                    elif isinstance(part.get("audio_url"), str):
                        au = part["audio_url"]
                        if au.startswith("data:audio") and ";base64," in au:
                            candidate = au.split(",", 1)[1]
                    elif isinstance(part.get("data"), str):
                        candidate = part["data"]

                    if candidate and _is_base64_audio_string(candidate):
                        print(f"[ASR] Detected base64 audio in messages[{idx}] part[{part_idx}]")
                        tmp = decode_base64_to_file(candidate)
                        try:
                            t = transcribe_file_with_asr(tmp)
                            print(f"🎤 [ASR] messages[{idx}] part[{part_idx}] audio -> {t!r}")
                            new_parts.append({"type": "text", "text": t})
                        finally:
                            try:
                                os.remove(tmp)
                            except Exception:
                                pass
                    else:
                        new_parts.append(part)

                messages[idx]["content"] = new_parts
                break

        forwarding["messages"] = messages

    # --- 2) Log what goes to vLLM ---
    print("\n➡️  [vLLM] Forwarding messages summary:")
    for i, m in enumerate(forwarding.get("messages") or []):
        if not isinstance(m, dict):
            continue
        c = m.get("content")
        if isinstance(c, str):
            prev = (c[:140] + "...") if len(c) > 140 else c
            print(f"   - [{i}] {m.get('role')}: {prev!r}")
        else:
            print(f"   - [{i}] {m.get('role')}: <{type(c)}>")

    # --- 3) Forward to vLLM ---
    vllm_result = await forward_to_vllm(forwarding)

    print("\n🧠 [vLLM] raw response (truncated):")
    try:
        print(json.dumps(vllm_result, indent=2)[:1500], "...\n")
    except Exception:
        print(str(vllm_result)[:1500], "...\n")

    # --- 4) TTS: if message.content is JSON with "speech": "<text>", attach base64 audio ---
    try:
        choices = vllm_result.get("choices")
        if isinstance(choices, list):
            for idx, choice in enumerate(choices):
                msg = choice.get("message") if isinstance(choice, dict) else None
                if not isinstance(msg, dict):
                    continue

                c = msg.get("content")
                if not isinstance(c, str):
                    continue

                try:
                    parsed = json.loads(c)
                except Exception:
                    continue

                speech_text = parsed.get("speech")
                if not isinstance(speech_text, str) or not speech_text.strip():
                    continue

                print(f"🔊 [TTS] choice[{idx}] speech text: {speech_text!r}")
                audio_b64 = synthesize_text_to_base64(speech_text)
                if not audio_b64:
                    print(f"❌ [TTS] choice[{idx}] TTS failed, keeping text-only")
                    continue

                parsed["speech"] = audio_b64
                msg["audio"] = audio_b64
                msg["content"] = json.dumps(parsed, ensure_ascii=False)
                print(f"✅ [TTS] choice[{idx}] audio attached")
    except Exception as e:
        print("[TTS] post-processing error:", e)
        traceback.print_exc()

    return vllm_result


# =========================
# Main
# =========================

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--preload-asr", action="store_true")
    parser.add_argument("--preload-tts", action="store_true")
    parser.add_argument("--asr-model", type=str, default=None)
    parser.add_argument("--tts-model", type=str, default=None)
    parser.add_argument("--port", type=int, default=int(os.environ.get("ORCH_PORT", 6161)))
    args = parser.parse_args()

    if args.asr_model:
        ASR_MODEL_ID = args.asr_model
    if args.tts_model:
        TTS_MODEL_ID = args.tts_model

    if args.preload_asr or os.environ.get("PRELOAD_ASR", "0") == "1":
        try:
            preload_asr_model()
        except Exception as e:
            print("[ASR] Preload failed:", e)

    if args.preload_tts or os.environ.get("PRELOAD_TTS", "0") == "1":
        try:
            preload_tts_model()
        except Exception as e:
            print("[TTS] Preload failed:", e)

    import uvicorn
    uvicorn.run("server:app", host="0.0.0.0", port=args.port, log_level="info")
