# WonderMath voice clips

The renderer uses Chatterbox Multilingual v3 and keeps its Perth watermark enabled. Set up the CPU environment and render from the core-generated line manifest:

```bash
python3 -m venv ~/venvs/chatterbox
source ~/venvs/chatterbox/bin/activate
pip install torch==2.6.0 torchaudio==2.6.0 --index-url https://download.pytorch.org/whl/cpu
pip install -e ~/repos/chatterboxYC
pip install -r apps/WonderMath/tools/voice/requirements.txt
swift run --package-path apps/WonderMath/WonderMathCore WonderMathVoiceLines > /tmp/lines.json
python apps/WonderMath/tools/voice/render_clips.py --lines /tmp/lines.json
```

Use `--only key1,key2` to regenerate selected lines. `--seed 2000` changes the base seed; each line uses that value plus its position in the sorted `(key, language)` list (default base seed: `1234`). A partial render keeps existing manifest records and their seeds for non-selected clips.

A permitted custom speaker recording can be supplied with `--voice my_clip.wav`; the renderer records its filename in the voice manifest.
