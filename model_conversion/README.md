# Model conversion → ONNX

This workspace turns PyTorch checkpoints into the ONNX files the app ships. It
is **build tooling, not part of the app** - nothing here is bundled.

| Script | Produces | Licence |
|---|---|---|
| `convert_u2netp.py` | `assets/models/u2netp.onnx` | Apache-2.0 |
| `convert_mobile_sam.py` | `assets/models/mobile_sam_{encoder,decoder}.onnx` | Apache-2.0 |
| `convert_migan.py` | `assets/models/migan.onnx` | **MIT** |

## MI-GAN (generative fill)

- **Architecture:** `migan_arch.py` - verbatim from
  <https://github.com/Picsart-AI-Research/MI-GAN> (`lib/model_zoo/migan_inference.py`),
  **MIT**, © 2024 Picsart AI Research. It imports only numpy and torch, so the
  vendored NVIDIA `dnnlib/` and `torch_utils/` in that repo never enter the
  pipeline and nothing NVIDIA-licensed goes near the APK.
- **Weights:** `migan_512_places2.pt` (28 MB), from the repo's Google Drive
  link. **sha256** `1d6087eee0aac8923ad2606be5d8caeb4824d3e4de331995e420c74e124a466a`.

  **Use the `places2` checkpoint and only that.** Do **not** substitute
  `migan_256_ffhq.pt`: FFHQ is CC BY-NC-SA 4.0, and it is the checkpoint a
  search for "person removal" surfaces first, which makes it the single most
  likely way to get this wrong.
- **Output:** `assets/models/migan.onnx` (26.7 MB)
  - opset **17**, fp32, input `input` `[1,4,512,512]`, output `output` `[1,3,512,512]`.
  - ops: Add, Cast, Clip, Concat, Constant, ConstantOfShape, Conv, Identity,
    LeakyRelu, Mul, Pad, Reshape, Resize, Slice, Transpose - no FFT, no custom
    domain, all supported by ONNX Runtime Mobile.
  - **sha256** `1aa7b86193afae0215a372ad24bd22c2ed489cb3123218fcef6a101ec45e36cf`

**Do not download the published ONNX instead.** Upstream's `migan.onnx` and
`migan_pipeline_v2.onnx` on Hugging Face are *pipeline* exports taking uint8
image + mask and cropping internally. `inpaint_engine.dart` builds the raw
4-channel float signature because it does its own compositing, so a pipeline
export throws at load - and `InpaintEngine` catches broadly, so it would fall
through to content-aware fill silently. `convert_migan.py` asserts the
signature for exactly this reason.

## Why U²-Netp (not U²-Net full)

Both checkpoints were evaluated. **U²-Netp** (the "portable" small variant) is the
right model for a mobile app:

| Model      | Params | Checkpoint | ONNX bundled | Mask quality            | Verdict |
|------------|--------|------------|--------------|-------------------------|---------|
| U²-Netp    | 1.1 M  | 4.7 MB     | **4.4 MB**   | Excellent for the job   | **Ship** |
| U²-Net full| 44 M   | 176 MB     | ~168 MB      | Marginally sharper      | Too heavy |

U²-Net full would inflate the APK ~40×, need far more RAM, and run several times
slower on-device - for a background cut-out that is then feathered and hand-refined
in the Erase tool, the quality delta doesn't justify any of that. The bundled
engine's `ModelConfig` (input `[1,3,320,320]`, ImageNet mean/std) matches U²-Netp.

## Provenance

- **Architecture:** `u2net_arch.py` - verbatim from
  <https://github.com/xuebinqin/U-2-Net> (`model/u2net.py`), **Apache-2.0**.
- **Weights:** `u2netp.pth` - the standard `u2netp` salient-object checkpoint,
  **Apache-2.0**. Do **not** substitute `u2net_portrait` (non-commercial) or
  BRIA RMBG (CC BY-NC) - this is a paid app.
- **Output:** `assets/models/u2netp.onnx`
  - opset **17**, fp32, input `input` `[1,3,320,320]` NCHW, output `output`
    `[1,1,320,320]` sigmoid.
  - ops: Add, Concat, Constant, Conv, MaxPool, Relu, Resize, Shape, Sigmoid,
    Slice - all supported by ONNX Runtime Mobile.
  - **sha256** `698d9836dbe72f30ad947fe33ce676a88f7c5fb01d0ec6ed069f157b27b8c0ed`

## Reproduce

The `.pth` checkpoints are git-ignored (too large). Re-fetch them into this
directory, then:

```
pip install torch onnx onnxruntime onnxscript
python model_conversion/convert_u2netp.py
```

The script exports d0 (the fused main map) as a single output, verifies the
shape/sigmoid range under onnxruntime, and prints the sha256 above.
