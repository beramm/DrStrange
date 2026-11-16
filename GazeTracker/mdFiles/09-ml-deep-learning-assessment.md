# ML / Deep-Learning Gaze Assessment

Status: research complete; isolated physical-device spike recommended, no pretrained model adopted
Assessment date: 2026-11-09
Branch: `codex/ml-gaze-assessment`

## Decision

Do not replace the current selected-right ARKit mapper with a downloaded model
yet. The best candidate is WebEyeTrack's BlazeGaze, evaluated through a new,
isolated Core ML shadow pipeline. It is the only reviewed candidate that is
small, directly predicts a two-dimensional point of gaze, explicitly supports
few-shot calibration, and has a reproducible Apple-platform conversion path.

This is a **candidate selection**, not an accuracy result. No reviewed model has
been measured on the required 13-inch iPad Air (M2), in landscape, at 40–60 cm,
with one eye covered. The current raw Phase 3 result remains median 2.14 cm,
p90 6.26 cm, and worst 6.34 cm; the fixed p90 gate remains 4.0 cm.

No model binary or third-party runtime is added by this assessment. The live
tracker contract, ARKit path, privacy behavior, and game integration are
unchanged.

## Search result

The search covered current Hugging Face and GitHub gaze-estimation models,
their primary repositories/model cards, deployability, output type, and known
license constraints.

| Candidate | Useful facts | Fit for DrStrange | Decision |
| --- | --- | --- | --- |
| [WebEyeTrack / BlazeGaze](https://github.com/RedForestAI/WebEyeTrack) | MIT repository; 891 KB Keras checkpoint; 512×128 eye strip plus metric head pose; direct normalized 2D point; paper reports 2.32 cm on GazeCapture and 2.4 ms inference on iPhone 14 with few-shot personalization | Best architectural match; preprocessing and one-eye occlusion still unproved | **Run isolated spike** |
| [MacGaze Core ML conversion](https://github.com/AACTools/MacGaze) | Reproducible BlazeGaze-to-Core-ML conversion and native Swift runner; released compiled model is about 0.75 MB | Valuable conversion reference, but macOS-oriented preprocessing and evidence are not iPad evidence | Reuse ideas and conversion checks, not the package wholesale |
| [Qualcomm EyeGaze](https://huggingface.co/qualcomm/EyeGaze) | BSD-3-Clause model card; 2.58M parameters; 9.6 MB float / 3.3 MB quantized; consumes 96×160 grayscale eyes and returns pitch/yaw | Small, but no Core ML artifact, no direct screen point, and reported timings are Qualcomm NPU results | Backup only |
| [MobileGaze](https://github.com/yakhyo/gaze-estimation) | MIT code; MobileOne-S0 is 4.8 MB; ONNX weights; face crop to pitch/yaw | Published weights are Gaze360-only and report 12.58° MAE; still needs screen calibration and Core ML conversion | Reject for this spike |
| [LightGazeNet](https://eyelignai.github.io/lightgazenet/) | 3.48M parameters; reported 1.69 cm on GazeCapture; multimodal eye/face/head inputs | Promising research, but official code is still marked “coming soon” | Revisit when code and weights exist |
| [UniGaze](https://github.com/ut-vision/UniGaze) | Strong cross-dataset research models and published checkpoints | Large ViT family and non-commercial ModelGo license; not a mobile screen-point model | Reject |

Scene-gaze models such as PaGE and gaze-following models such as Gaze-LLE were
excluded because they identify what a person in an image is looking at; they do
not map the device user's eyes to this iPad's display coordinates.

## Why BlazeGaze is not a drop-in dependency

BlazeGaze's learned input contract is part of the model:

- `image`: float32 `[1, 128, 512, 3]`, an RGB two-eye strip normalized to
  `[0, 1]`;
- `head_vector`: float32 `[1, 3]`;
- `face_origin_3d`: float32 `[1, 3]` in metric space;
- output: float32 `[1, 2]` point of gaze.

The current runtime has a selected-eye ray, head direction, and face distance,
but does not compute the training-compatible two-eye crop. ARKit's face mesh
does not provide a documented semantic index contract suitable for copying the
MediaPipe homography. Adding an approximate crop and calling the result
“BlazeGaze” would test a different input distribution.

There are five additional blockers:

1. **Patched-eye distribution.** BlazeGaze consumes both eyes. Its public
   evidence does not establish behavior with an opaque patch covering either
   eye, which is a required DrStrange condition.
2. **Deployment target.** MacGaze's released compiled artifact declares iOS 18
   minimum and uses iOS 18 ML Program operations. DrStrange supports iPadOS 17.
   The Keras source must be converted specifically for the project's target and
   verified on the exact device.
3. **Personalization is absent from the conversion.** The released Core ML
   model is not updatable. WebEyeTrack's reported few-shot behavior adapts its
   gaze head with MAML in TensorFlow.js; loading the frozen Core ML model alone
   does not reproduce that behavior. A separately validated calibration layer
   is required.
4. **Coordinate convention needs proof.** The paper defines normalized output
   in `[-0.5, 0.5]` around screen center, while MacGaze's runner documents
   `[0, 1]`. The conversion must be compared against the Keras checkpoint on
   deterministic inputs before any screen mapping is trusted.
5. **Checkpoint rights need confirmation before product distribution.** The
   WebEyeTrack repository is MIT, but the inspected checkpoint is named
   `blazegaze_mpiifacegaze.keras` and the paper uses research gaze datasets.
   Repository code licensing alone does not conclusively grant product rights
   to every trained weight. Internal prototype evaluation is reasonable; a
   shipped medical-adjacent product needs checkpoint provenance and rights
   confirmed with the authors or counsel.

## Reproducibility record

Inspected source and artifacts:

- WebEyeTrack commit
  `75fbd2f5f784f2eb3a39675a8dcbf1b01c697f1c`;
- `blazegaze_mpiifacegaze.keras` SHA-256
  `5b011cfe82466896e27b1ac3e18130117cafbc02dbc964a1ad7315f62005cc05`;
- MacGaze commit
  `3884a8c5a9f6284aff4726db8f282f62661e9dd3`;
- MacGaze `v0.1.0-assets` Core ML zip SHA-256
  `95663b6961616968d72b253934efd2393b73c325a0385dcba2d32f3c376561ac`.

The released compiled model reports specification version 9, fixed input
shapes, a non-updatable model, and iOS 18 availability. A host-only synthetic
sanity test on Apple M5 / macOS 27.0.1 / Xcode 27.2 loaded the artifact and ran
20 warmed predictions with Core ML `.all` compute units: median 1.14 ms and p90
2.36 ms. This measures only the neural network on a development Mac. It is not
an end-to-end camera measurement, target-iPad benchmark, or accuracy result.

## Recommended isolated spike

**Implementation status (2026-11-10):** the gaze-owned demo now implements
steps 5–6 as a shadow path using Google's official iOS MediaPipe Swift package,
the exact `512×128` WebEyeTrack homography, the pinned MacGaze Core ML artifact,
metric face origin, and a volatile Gaussian RBF correction. The current target
iPad runs iPadOS 27, so the artifact's iOS 18 minimum is satisfied for this
internal spike. ARKit remains the control. Steps 7–8 and the pass/stop gate are
not yet satisfied; a successful build or visible cursor is not accuracy
evidence.

Keep the current ARKit path as the control and add BlazeGaze only as an
engineering-only shadow candidate. Do not expose a new public sample category
or allow the candidate to drive gameplay until it passes the gate.

1. Pin the WebEyeTrack source commit and checkpoint hash above.
2. Confirm checkpoint redistribution/product rights before committing a model
   binary. Keep the artifact outside the production target until then.
3. Convert the Keras model to Core ML for iPadOS 17. Prefer fixed-shape FP16 if
   numerical parity and accuracy remain acceptable. Do not reuse the released
   iOS 18 compiled artifact.
4. Compare Keras and Core ML output on deterministic tensors. Require maximum
   absolute output difference below `1e-3` and explicitly lock the coordinate
   transform.
5. In memory, derive a training-compatible eye strip and metric head pose from
   each `ARFrame`. Prefer an iOS-supported MediaPipe Face Landmarker path over
   undocumented ARKit mesh indices or an approximate Vision crop.
6. Run frozen BlazeGaze inference, then fit a small per-calibration correction
   from robust target aggregates. This correction is a separately evaluated
   substitute for WebEyeTrack's unavailable Core ML personalization, not a
   claim that MAML was ported.
7. Feed the candidate through the existing untouched held-out validation
   protocol. Keep all camera images, landmarks, model inputs, predictions, and
   calibration pairs in volatile memory only.
8. Compare the control and candidate on the same exact-device conditions,
   separately for each patch side. Randomize order when practical so fatigue
   and learning do not always favor one candidate.

## Pass / stop gate

Adopt the ML candidate only if the complete pipeline, not model inference
alone, satisfies all of the following on the target iPad:

- p90 held-out radial error at or below 4.0 cm for both consecutive
  same-calibration validations and modest head movement;
- at least 80% directional agreement in every required condition;
- both opaque-patch sides pass without swapping anatomical-eye meaning;
- at least 30 valid samples per second;
- end-to-end publication latency p90 at or below 50 ms and maximum at or below
  100 ms;
- availability, calibration duration/success, recovery, and privacy remain at
  least as strong as the existing contract;
- no camera frame, eye crop, landmark set, biometric geometry, calibration
  pair, or gaze path is persisted, logged, cached, or transmitted;
- checkpoint provenance and distribution rights are accepted for the intended
  product use.

Stop the candidate if exact preprocessing cannot sustain the latency gate, if
either patched-eye condition is out of distribution, or if held-out accuracy
does not beat the current p90 6.26 cm result. Do not compensate for a failed
raw model with a larger hit radius, smoothing, snapping, or dwell and report it
as model accuracy.

## 2026-11-10 face-isolation preprocessing assessment

The gaze-owned demo host now includes an engineering-only face-isolation
feasibility path. It uses Vision on a queue separate from the ARKit observation
delegate, limits work to 10 Hz, selects the largest face, adds 35% square
padding, and normalizes the volatile crop to `224×224`. The full camera preview
and square crop are displayed side by side. Whack-a-Mole, the production
seven-field output, calibration, and gaze mapping are unchanged.

The host records rolling, non-persisted aggregates for face-detection success,
crop-processing latency, source-pixel fraction retained, and gaze publication
latency/rate with isolation enabled versus disabled. This evaluates whether
face isolation is stable and whether its sidecar cost preserves the existing
latency/rate gates. It does not evaluate gaze accuracy and does not yet satisfy
BlazeGaze's required `512×128` two-eye input contract.

The initial square preview applied an additional EXIF mirror even though the
shared ARKit front-camera presentation was already mirrored. That made the
full preview and isolated crop show opposite screen sides. The crop now applies
rotation only for the active interface orientation, so the actual `224×224`
candidate input and ARKit preview have matching left/right presentation. This
display correction does not change the separately verified anatomical
`EyeAvailability` conversion or selected-right-eye gaze ray.

## Primary references

- [WebEyeTrack paper](https://arxiv.org/abs/2508.19544)
- [WebEyeTrack source and checkpoint](https://github.com/RedForestAI/WebEyeTrack)
- [MacGaze Core ML conversion](https://github.com/AACTools/MacGaze)
- [Qualcomm EyeGaze model card](https://huggingface.co/qualcomm/EyeGaze)
- [MobileGaze source and weights](https://github.com/yakhyo/gaze-estimation)
- [LightGazeNet project](https://eyelignai.github.io/lightgazenet/)
- [UniGaze source and license](https://github.com/ut-vision/UniGaze)
