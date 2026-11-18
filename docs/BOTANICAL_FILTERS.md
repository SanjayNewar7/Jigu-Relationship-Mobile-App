# Moment camera filters

Camera capture opens the botanical filter step before text, stickers, drawing,
and cropping. Original plus 12 looks are available offline. Swipe the photo or
tap a swatch; the intensity slider starts at 85%.

The Flutter fragment shader samples one decoded image. A horizontal wipe chooses
the current or adjacent grade for each pixel. A swipe commits at 35% travel or
500 logical pixels/second in the swipe direction; otherwise it settles back.
The list wraps in both directions. Caption gestures remain in the next editing
step and cannot accidentally change filters.

The supplied botanical grading brief is implemented as procedural exposure,
contrast, tonal masks, hue-selective adjustments, and split toning. Its arbitrary
slider units are mapped to normalized shader parameters; this is not a calibrated
Lightroom preset or a supplied .cube LUT. Cool looks attenuate chroma adjustments
around skin hues. Local clarity/sharpening is not applied. There are no downloaded
LUTs or per-filter photo copies.

Preview and export run the same shader. Export uses an independent shader instance
to prevent preview uniforms from changing the output during rendering. Decoding
retains aspect ratio and caps the long edge at 2560px, matching the existing moment
editor. Export produces PNG input for the text editor, whose existing final output
is JPEG at quality 95. Original camera files are never overwritten.

Validation: botanical_filter_test checks all 12 distinct exports, intensity-zero
identity, both directions of the split preview, dimensions, and discard choices.
Existing caption tests cover tap versus drag/pinch and rich text serialization.
No physical-device frame-rate claim is made from these tests.

References:
- https://docs.flutter.dev/ui/design/graphics/fragment-shaders
- https://pub.dev/packages/pro_image_editor/versions/12.1.0
