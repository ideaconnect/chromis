"""Convert the MI-GAN PyTorch checkpoint to the ONNX the app bundles.

Reproducible, offline pipeline that turns `migan_512_places2.pt` (this dir) into
`assets/models/migan.onnx` - the optional generative fill tier that
`InpaintEngine` runs ahead of the always-available `ContentFillEngine`.

    pip install torch onnx onnxruntime onnxscript
    python model_conversion/convert_migan.py

## Why we export this ourselves rather than downloading the published ONNX

Upstream publishes two ONNX files on Hugging Face (`migan.onnx`,
`migan_pipeline_v2.onnx`). BOTH are *pipeline* exports: they take `uint8` image
and mask tensors and do their own crop/resize internally. The app's
`inpaint_engine.dart` builds the RAW signature instead - one 4-channel float32
tensor - because it does its own windowing and compositing against the
full-resolution photo. Dropping a pipeline export at `assets/models/migan.onnx`
would throw at load, and `InpaintEngine.inpaint` catches broadly, so it would
fall through to content-aware fill with nothing to show for it. Export the raw
`Generator` and the two halves match.

This also keeps the vendored NVIDIA `dnnlib/` and `torch_utils/` from the
upstream repo out of the process entirely: `migan_arch.py` imports only numpy
and torch, so nothing NVIDIA-licensed is anywhere near the shipped artifact.

## The tensor contract, which must not drift from the Dart side

Upstream's own `scripts/export_inference_model.py` builds the input as

    img  = (ToTensor()(img) - 0.5) * 2          # rgb -> [-1, 1]
    x    = torch.cat([mask - 0.5, img * mask])  # mask: 1 = KEEP, 0 = hole

and decodes the result with `* 127.5 + 127.5`. `_preprocess` in
`inpaint_engine.dart` builds `keep - 0.5` and `(rgb / 127.5 - 1) * keep`, and
`_postprocess` decodes `(v + 1) * 127.5`. Those are the same arithmetic. If you
change one, change the other - the mismatch is silent, and it looks like a bad
model rather than a bad tensor.
"""

import hashlib
import os
import sys
import warnings

warnings.filterwarnings("ignore")

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)

import numpy as np  # noqa: E402
import torch  # noqa: E402
from migan_arch import Generator  # noqa: E402  (official MIT architecture)

CKPT = os.path.join(HERE, "migan_512_places2.pt")
OUT = os.path.join(ROOT, "assets", "models", "migan.onnx")
RESOLUTION = 512


def main():
    if not os.path.exists(CKPT):
        sys.exit(
            f"missing {CKPT}\n"
            "Fetch migan_512_places2.pt per model_conversion/README.md.\n"
            "Do NOT substitute migan_256_ffhq.pt - FFHQ is CC BY-NC-SA."
        )
    print(f"loading {CKPT} ({os.path.getsize(CKPT)} bytes)")
    net = Generator(resolution=RESOLUTION)
    state = torch.load(CKPT, map_location="cpu")
    # strict: the inference Generator and this checkpoint must agree exactly.
    # A silently partial load exports a model that runs and produces noise.
    net.load_state_dict(state)
    net.eval()

    dummy = torch.randn(1, 4, RESOLUTION, RESOLUTION)
    with torch.no_grad():
        torch.onnx.export(
            net,
            dummy,
            OUT,
            input_names=["input"],
            output_names=["output"],
            opset_version=17,
            do_constant_folding=True,
            dynamo=False,
        )
    print(f"wrote {OUT} ({os.path.getsize(OUT)} bytes)")
    verify()


def verify():
    """Prove the artifact before it ships: signature, ops, and numerics.

    The signature check is the one that matters - it is exactly what a pipeline
    export would fail, and the app cannot tell the difference at runtime.
    """
    import onnx
    import onnxruntime as ort

    model = onnx.load(OUT)
    onnx.checker.check_model(model)
    ops = sorted({n.op_type for n in model.graph.node})
    print(f"ops ({len(ops)}): {', '.join(ops)}")

    sess = ort.InferenceSession(OUT, providers=["CPUExecutionProvider"])
    (inp,) = sess.get_inputs()
    (out,) = sess.get_outputs()
    print(f"input  {inp.name} {inp.shape} {inp.type}")
    print(f"output {out.name} {out.shape} {out.type}")
    assert inp.name == "input" and out.name == "output", "names must match the Dart side"
    assert list(inp.shape) == [1, 4, RESOLUTION, RESOLUTION], f"bad input {inp.shape}"
    assert list(out.shape) == [1, 3, RESOLUTION, RESOLUTION], f"bad output {out.shape}"

    # A synthetic fill: a flat mid-grey photo with a square hole punched in it.
    # A working model returns something close to the surrounding grey inside the
    # hole; a mis-wired one returns noise or saturates. This is a smoke test for
    # the tensor contract, not a quality measure.
    keep = np.ones((1, 1, RESOLUTION, RESOLUTION), np.float32)
    keep[:, :, 200:312, 200:312] = 0.0
    rgb = np.zeros((1, 3, RESOLUTION, RESOLUTION), np.float32)  # 0.0 == mid grey
    x = np.concatenate([keep - 0.5, rgb * keep], axis=1)
    y = sess.run(["output"], {"input": x})[0]
    hole = y[0, :, 200:312, 200:312]
    known = y[0, :, 0:100, 0:100]
    print(
        f"synthetic fill: hole mean {hole.mean():+.3f} std {hole.std():.3f}, "
        f"known-region mean {known.mean():+.3f}"
    )
    assert np.isfinite(y).all(), "output contains NaN/Inf"
    assert abs(hole.mean()) < 0.35, (
        f"hole mean {hole.mean():+.3f} is far from the surrounding grey - "
        "the input channel order or normalisation is probably wrong"
    )

    digest = hashlib.sha256(open(OUT, "rb").read()).hexdigest()
    print(f"sha256 {digest}")


if __name__ == "__main__":
    main()
