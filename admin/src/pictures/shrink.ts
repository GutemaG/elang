// Shrinking a picture before it is uploaded (bolt 052, story 001).
//
// Admins pick any photo or drawing; the site makes it at most 512 px on its
// longest side and at most 300 KB, as WebP where the browser can encode it,
// otherwise JPEG. The browser's own steps (decode, draw, encode) come in as
// one small object, so every rule here can be tested without a canvas,
// which jsdom does not have.

import { formatSize } from '../audio/formats'

export const MAX_PICTURE_SIDE = 512
export const MAX_PICTURE_BYTES = 300 * 1024
/** The largest file an admin may pick, before shrinking. */
export const MAX_SOURCE_BYTES = 10 * 1024 * 1024
export const SOURCE_TYPES = ['image/jpeg', 'image/png', 'image/webp'] as const
/** Tried in turn until the picture fits in MAX_PICTURE_BYTES. */
export const QUALITY_STEPS = [0.85, 0.75, 0.65, 0.55, 0.45, 0.35] as const

/** A refusal whose message is shown to the admin as it is. */
export class PictureProblem extends Error {
  constructor(message: string) {
    super(message)
    this.name = 'PictureProblem'
  }
}

export interface Decoded {
  width: number
  height: number
  close?: () => void
}

/** The browser's part. `render` draws the whole picture at the given size,
 * on `background` first when one is given; `encode` answers null when the
 * browser could not encode at all. */
export interface PictureBrowser<D extends Decoded = Decoded, C = unknown> {
  decode(file: Blob): Promise<D>
  render(picture: D, width: number, height: number, background: string | null): C
  encode(canvas: C, type: string, quality: number): Promise<Blob | null>
}

export interface ShrunkPicture {
  blob: Blob
  /** `image/webp` or `image/jpeg`: what the upload link is asked for. */
  type: string
  width: number
  height: number
}

/** The size to draw at: the longest side at most `max`, never enlarged,
 * rounded to whole pixels and never below 1. */
export function fitWithin(width: number, height: number, max = MAX_PICTURE_SIDE): { width: number; height: number } {
  const scale = Math.min(1, max / Math.max(width, height))
  return {
    width: Math.max(1, Math.round(width * scale)),
    height: Math.max(1, Math.round(height * scale)),
  }
}

/** Whether a picked file may be shrunk at all: its type and size. */
export function checkPicture(file: Blob): string | null {
  if (!(SOURCE_TYPES as readonly string[]).includes(file.type)) {
    return 'This file isn’t a JPEG, PNG or WebP picture. Choose one of those.'
  }
  if (file.size === 0) return 'This file is empty. Choose another picture.'
  if (file.size > MAX_SOURCE_BYTES) {
    return `The picture is ${formatSize(file.size)}; pictures can be 10 MB at most. Choose a smaller one.`
  }
  return null
}

// Whether this browser encodes WebP: learnt from the first picture shrunk,
// then kept for the rest of the page's life.
let webpEncodes: boolean | undefined

/** For tests: forget what was learnt about WebP. */
export function forgetWebpCheck(): void {
  webpEncodes = undefined
}

const TOO_BIG = 'This picture is still over 300 KB at the lowest quality. Choose a simpler picture.'

async function encodeWithin<D extends Decoded, C>(
  browser: PictureBrowser<D, C>,
  picture: D,
  width: number,
  height: number,
): Promise<Blob> {
  if (webpEncodes !== false) {
    const canvas = browser.render(picture, width, height, null)
    for (const quality of QUALITY_STEPS) {
      const blob = await browser.encode(canvas, 'image/webp', quality)
      // A browser that can't encode WebP hands back a PNG instead.
      if (!blob || blob.type !== 'image/webp') {
        webpEncodes = false
        break
      }
      webpEncodes = true
      if (blob.size <= MAX_PICTURE_BYTES) return blob
    }
    if (webpEncodes) throw new PictureProblem(TOO_BIG)
  }
  // JPEG has no transparency: without white underneath, clear parts of a
  // PNG would turn black.
  const canvas = browser.render(picture, width, height, '#ffffff')
  for (const quality of QUALITY_STEPS) {
    const blob = await browser.encode(canvas, 'image/jpeg', quality)
    if (!blob) throw new PictureProblem('This browser could not save the picture. Try another browser.')
    if (blob.size <= MAX_PICTURE_BYTES) return blob
  }
  throw new PictureProblem(TOO_BIG)
}

/** Checks, decodes, scales and encodes one picked file. Throws a
 * PictureProblem, whose message is for the admin, when it can't. */
export async function shrinkPicture<D extends Decoded, C>(
  file: Blob,
  browser: PictureBrowser<D, C>,
): Promise<ShrunkPicture> {
  const problem = checkPicture(file)
  if (problem) throw new PictureProblem(problem)

  let picture: D
  try {
    picture = await browser.decode(file)
  } catch {
    throw new PictureProblem('This picture couldn’t be read. It may be damaged; choose another.')
  }
  try {
    const { width, height } = fitWithin(picture.width, picture.height)
    const blob = await encodeWithin(browser, picture, width, height)
    return { blob, type: blob.type, width, height }
  } finally {
    picture.close?.()
  }
}

/** The real browser: `createImageBitmap` turned upright by the photo's
 * EXIF orientation, drawn on a canvas and encoded with `toBlob`. */
export const canvasBrowser: PictureBrowser<ImageBitmap, HTMLCanvasElement> = {
  decode: (file) => createImageBitmap(file, { imageOrientation: 'from-image' }),
  render(picture, width, height, background) {
    const canvas = document.createElement('canvas')
    canvas.width = width
    canvas.height = height
    const context = canvas.getContext('2d')
    if (!context) throw new PictureProblem('This browser could not draw the picture. Try another browser.')
    if (background) {
      context.fillStyle = background
      context.fillRect(0, 0, width, height)
    }
    context.imageSmoothingQuality = 'high'
    context.drawImage(picture, 0, 0, width, height)
    return canvas
  },
  encode: (canvas, type, quality) => new Promise((resolve) => canvas.toBlob(resolve, type, quality)),
}
