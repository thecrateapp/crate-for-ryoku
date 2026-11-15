import type { Camera } from "./camera";

interface Size {
  width: number;
  height: number;
}

/**
 * Where to draw the take (pixels) so the camera's centre sits in the middle of the
 * output frame. At scale 1 the take covers the frame (16:10 into 16:9 trims top and
 * bottom); zoomed in, no empty edge ever shows; below full size (the 3D opening and
 * closing) the screen floats centred.
 */
export function framing(camera: Pick<Camera, "scale" | "x" | "y">, source: Size, out: Size) {
  const cover = Math.max(out.width / source.width, out.height / source.height);
  const width = source.width * cover * camera.scale;
  const height = source.height * cover * camera.scale;
  const place = (size: number, frame: number, centre: number) =>
    size <= frame ? (frame - size) / 2 : Math.min(0, Math.max(frame - size, frame / 2 - centre * size));
  return {
    width,
    height,
    left: place(width, out.width, camera.x),
    top: place(height, out.height, camera.y),
  };
}
