#!/usr/bin/env python3
"""Render the fixed WonderMath voice lines with Chatterbox Multilingual v3."""

from __future__ import annotations

import argparse
import json
import logging
import math
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import Any

import numpy as np
import pyloudnorm as pyln
import soundfile as sf
import torch
from chatterbox.mtl_tts import ChatterboxMultilingualTTS


GENERATOR = "Chatterbox Multilingual v3 (Resemble AI, MIT)"
CHATTERBOX_COMMIT = "5de7a54"
LANGUAGE_IDS = {"en": "en", "de": "de"}
DEFAULT_OUTPUT_DIR = (
    Path(__file__).resolve().parents[2] / "WonderMath/Resources/Voice"
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--lines",
        type=Path,
        help="JSON manifest from WonderMathVoiceLines; reads stdin when omitted",
    )
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument(
        "--only",
        help="comma-separated line keys to render; preserves other existing clips",
    )
    parser.add_argument("--voice", type=Path, help="optional permitted speaker WAV")
    parser.add_argument(
        "--device",
        choices=("cpu", "cuda", "mps", "auto"),
        default="cpu",
        help="inference device (default: cpu; auto prefers CUDA, then MPS)",
    )
    parser.add_argument("--exaggeration", type=float, default=0.5)
    parser.add_argument("--cfg-weight", type=float, default=0.5)
    return parser.parse_args()


def read_lines(path: Path | None) -> list[dict[str, str]]:
    if path:
        with path.open("r", encoding="utf-8") as source:
            lines = json.load(source)
    else:
        lines = json.load(sys.stdin)

    if not isinstance(lines, list):
        raise ValueError("the lines input must be a JSON array")

    validated = []
    seen: set[tuple[str, str]] = set()
    for line in lines:
        if not isinstance(line, dict):
            raise ValueError("each line must be a JSON object")
        key, language, text = line.get("key"), line.get("language"), line.get("text")
        if not all(isinstance(value, str) and value for value in (key, language, text)):
            raise ValueError("each line must have non-empty key, language, and text")
        if language not in LANGUAGE_IDS:
            raise ValueError(f"unsupported language {language!r} for {key!r}")
        pair = (key, language)
        if pair in seen:
            raise ValueError(f"duplicate line {key!r} for language {language!r}")
        seen.add(pair)
        validated.append({"key": key, "language": language, "text": text})

    return sorted(validated, key=lambda line: (line["key"], line["language"]))


def resolve_device(requested: str) -> str:
    if requested == "auto":
        if torch.cuda.is_available():
            return "cuda"
        if getattr(torch.backends, "mps", None) and torch.backends.mps.is_available():
            return "mps"
        return "cpu"
    if requested == "cuda" and not torch.cuda.is_available():
        raise RuntimeError("CUDA was requested but is not available")
    if requested == "mps" and not (
        getattr(torch.backends, "mps", None) and torch.backends.mps.is_available()
    ):
        raise RuntimeError("MPS was requested but is not available")
    return requested


def audio_to_mono(audio: Any) -> np.ndarray:
    if hasattr(audio, "detach"):
        audio = audio.detach().cpu().numpy()
    samples = np.asarray(audio, dtype=np.float32).squeeze()
    if samples.ndim != 1 or samples.size == 0:
        raise ValueError(f"expected non-empty mono audio, got shape {samples.shape}")
    if not np.isfinite(samples).all():
        raise ValueError("generated audio contains non-finite samples")
    return samples


def trim_silence(samples: np.ndarray, sample_rate: int) -> np.ndarray:
    frame_size = max(1, int(sample_rate * 0.01))
    frame_count = math.ceil(samples.size / frame_size)
    padded = np.pad(samples, (0, frame_count * frame_size - samples.size))
    frames = padded.reshape(frame_count, frame_size)
    rms = np.sqrt(np.mean(np.square(frames), axis=1))
    peak = float(np.max(rms))
    if peak == 0:
        return samples

    active = np.flatnonzero(rms >= max(peak * 10 ** (-40 / 20), 1e-5))
    if active.size == 0:
        return samples

    margin = int(sample_rate * 0.02)
    start = max(0, int(active[0]) * frame_size - margin)
    end = min(samples.size, (int(active[-1]) + 1) * frame_size + margin)
    return samples[start:end]


def normalize_and_lead_in(samples: np.ndarray, sample_rate: int) -> np.ndarray:
    meter = pyln.Meter(sample_rate)
    loudness = meter.integrated_loudness(samples.astype(np.float64))
    if not math.isfinite(loudness):
        raise ValueError("could not measure generated clip loudness")
    normalized = pyln.normalize.loudness(samples, loudness, -18.0).astype(np.float32)
    peak = float(np.max(np.abs(normalized)))
    if peak > 0.98:
        normalized *= 0.98 / peak
    lead_in = np.zeros(int(sample_rate * 0.1), dtype=np.float32)
    return np.concatenate((lead_in, normalized))


def encode_clip(samples: np.ndarray, sample_rate: int, destination: Path) -> float:
    ffmpeg = shutil.which("ffmpeg")
    ffprobe = shutil.which("ffprobe")
    if not ffmpeg or not ffprobe:
        raise RuntimeError("ffmpeg and ffprobe must be installed")

    with tempfile.TemporaryDirectory(prefix="wondermath-voice-") as temporary:
        wav_path = Path(temporary) / "clip.wav"
        sf.write(wav_path, samples, sample_rate, subtype="PCM_16")
        subprocess.run(
            [
                ffmpeg,
                "-y",
                "-v",
                "error",
                "-i",
                str(wav_path),
                "-ac",
                "1",
                "-ar",
                "24000",
                "-c:a",
                "aac",
                "-b:a",
                "64k",
                "-movflags",
                "+faststart",
                str(destination),
            ],
            check=True,
        )
        probe = subprocess.run(
            [
                ffprobe,
                "-v",
                "error",
                "-show_entries",
                "format=duration",
                "-of",
                "json",
                str(destination),
            ],
            check=True,
            capture_output=True,
            text=True,
        )
        return float(json.loads(probe.stdout)["format"]["duration"])


def existing_clips(output_dir: Path) -> dict[tuple[str, str], dict[str, Any]]:
    manifest_path = output_dir / "manifest.json"
    if not manifest_path.exists():
        return {}
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        return {
            (clip["key"], clip["language"]): clip
            for clip in manifest["clips"]
            if (output_dir / clip["file"]).is_file()
        }
    except (KeyError, TypeError, json.JSONDecodeError):
        logging.warning("Ignoring invalid existing voice manifest: %s", manifest_path)
        return {}


def render(args: argparse.Namespace) -> None:
    lines = read_lines(args.lines)
    if not lines:
        raise ValueError("no voice lines were supplied")

    only = {key.strip() for key in args.only.split(",") if key.strip()} if args.only else None
    unknown_keys = only - {line["key"] for line in lines} if only else set()
    if unknown_keys:
        raise ValueError(f"unknown keys requested with --only: {', '.join(sorted(unknown_keys))}")
    selected = [line for line in lines if only is None or line["key"] in only]
    if not selected:
        raise ValueError("no lines matched --only")

    voice = args.voice.expanduser().resolve() if args.voice else None
    if voice and not voice.is_file():
        raise FileNotFoundError(f"speaker WAV does not exist: {voice}")
    device = resolve_device(args.device)
    args.output_dir.mkdir(parents=True, exist_ok=True)
    clip_records = existing_clips(args.output_dir) if only else {}

    logging.info("Loading Chatterbox Multilingual v3 on %s", device)
    model = ChatterboxMultilingualTTS.from_pretrained(device=device, t3_model="v3")
    sample_rate = int(model.sr)
    started = time.monotonic()

    selected_pairs = {(line["key"], line["language"]) for line in selected}
    for index, line in enumerate(lines):
        pair = (line["key"], line["language"])
        if pair not in selected_pairs:
            continue

        clip_started = time.monotonic()
        seed = 1234 + index
        torch.manual_seed(seed)
        if device == "cuda":
            torch.cuda.manual_seed_all(seed)

        logging.info(
            "Rendering %d/%d %s/%s (seed %d)",
            index + 1,
            len(lines),
            line["language"],
            line["key"],
            seed,
        )
        generation_options: dict[str, Any] = {
            "language_id": LANGUAGE_IDS[line["language"]],
            "exaggeration": args.exaggeration,
            "cfg_weight": args.cfg_weight,
        }
        if voice:
            generation_options["audio_prompt_path"] = str(voice)
        samples = audio_to_mono(model.generate(line["text"], **generation_options))
        samples = trim_silence(samples, sample_rate)
        samples = normalize_and_lead_in(samples, sample_rate)

        relative_path = Path(line["language"]) / f"{line['key']}.m4a"
        destination = args.output_dir / relative_path
        destination.parent.mkdir(parents=True, exist_ok=True)
        duration = encode_clip(samples, sample_rate, destination)
        clip_records[pair] = {
            "key": line["key"],
            "language": line["language"],
            "text": line["text"],
            "file": relative_path.as_posix(),
            "durationSeconds": duration,
        }
        logging.info(
            "Rendered %s/%s in %.1fs (clip %.2fs)",
            line["language"],
            line["key"],
            time.monotonic() - clip_started,
            duration,
        )

    ordered_records = sorted(
        clip_records.values(), key=lambda clip: (clip["key"], clip["language"])
    )
    manifest = {
        "generator": GENERATOR,
        "voice": voice.name if voice else "default",
        "chatterboxCommit": CHATTERBOX_COMMIT,
        "clips": ordered_records,
    }
    manifest_path = args.output_dir / "manifest.json"
    temporary_manifest = args.output_dir / "manifest.json.tmp"
    temporary_manifest.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    temporary_manifest.replace(manifest_path)
    logging.info(
        "Rendered %d selected clips in %.1fs; manifest: %s",
        len(selected),
        time.monotonic() - started,
        manifest_path,
    )


def main() -> int:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
        stream=sys.stderr,
    )
    try:
        render(parse_args())
    except Exception:
        logging.exception("Voice rendering failed")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
