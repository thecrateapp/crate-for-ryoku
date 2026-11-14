import type { Camera } from "./camera";

interface Size {
  width: number;
  height: number;
}

/**
 * Where to draw the take (pixels) so the camera's centre sits in the middle of the
 * output frame, the take covers the frame at scale 1 (16:10 into 16:9 trims top and
 * bottom), and no empty edge ever shows.
 */
export function framing(camera: Camera, source: Size, out: Size) {
  const cover = Math.max(out.width / source.width, out.height / source.height);
  const width = source.width * cover * camera.scale;
  const height = source.height * cover * camera.scale;
  const clamp = (value: number, min: number) => Math.min(0, Math.max(min, value));
  return {
    width,
    height,
    left: clamp(out.width / 2 - camera.x * width, out.width - width),
    top: clamp(out.height / 2 - camera.y * height, out.height - height),
  };
}
