import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import {
  MAX_PICTURE_BYTES,
  MAX_SOURCE_BYTES,
  PictureProblem,
  QUALITY_STEPS,
  canvasBrowser,
  checkPicture,
  fitWithin,
  forgetWebpCheck,
  shrinkPicture,
  type Decoded,
  type PictureBrowser,
} from './shrink'

// --- a browser, faked --------------------------------------------------------

interface Drawn {
  width: number
  height: number
  background: string | null
}

interface Options {
  width?: number
  height?: number
  /** Whether `toBlob('image/webp')` really makes WebP. */
  webp?: boolean
  /** Bytes an encoding comes out at, by type and quality. */
  sizeOf?: (type: string, quality: number) => number
  decodeFails?: boolean
  encodeFails?: boolean
}

function fakeBrowser(options: Options = {}) {
  const { width = 4000, height = 3000, webp = true, decodeFails = false, encodeFails = false } = options
  const sizeOf = options.sizeOf ?? (() => 40_000)
  const close = vi.fn()
  const browser = {
    decode: vi.fn(async (): Promise<Decoded> => {
      if (decodeFails) throw new DOMException('bad', 'InvalidStateError')
      return { width, height, close }
    }),
    render: vi.fn((_: Decoded, w: number, h: number, background: string | null): Drawn => ({
      width: w,
      height: h,
      background,
    })),
    encode: vi.fn(async (_: Drawn, type: string, quality: number): Promise<Blob | null> => {
      if (encodeFails) return null
      // Without WebP, browsers hand back a PNG instead.
      const made = type === 'image/webp' && !webp ? 'image/png' : type
      return new Blob([new Uint8Array(sizeOf(made, quality))], { type: made })
    }),
  } satisfies PictureBrowser<Decoded, Drawn>
  return { browser, close }
}

const picture = (type = 'image/jpeg', bytes = 2_000_000) =>
  new File([new Uint8Array(bytes)], 'photo', { type })

beforeEach(() => forgetWebpCheck())

// --- sizes and files -----------------------------------------------------------

describe('the size a picture is drawn at', () => {
  it.each([
    [4000, 3000, 512, 384],
    [3000, 4000, 384, 512],
    [1024, 1024, 512, 512],
    [512, 300, 512, 300],
    [300, 200, 300, 200],
    [1, 1, 1, 1],
    [5000, 3, 512, 1],
    [3, 5000, 1, 512],
  ])('%i×%i becomes %i×%i', (w, h, width, height) => {
    expect(fitWithin(w, h)).toEqual({ width, height })
  })
})

describe('which files may be shrunk', () => {
  it.each(['image/jpeg', 'image/png', 'image/webp'])('%s is accepted', (type) => {
    expect(checkPicture(picture(type))).toBeNull()
  })

  it.each(['image/gif', 'image/svg+xml', 'image/heic', 'text/plain', 'application/pdf', ''])(
    '%s is refused',
    (type) => {
      expect(checkPicture(picture(type))).toMatch(/isn’t a JPEG, PNG or WebP picture/)
    },
  )

  it('10 MB is allowed; a byte more is not', () => {
    expect(checkPicture(picture('image/jpeg', MAX_SOURCE_BYTES))).toBeNull()
    expect(checkPicture(picture('image/jpeg', MAX_SOURCE_BYTES + 1))).toMatch(/10 MB at most/)
  })

  it('an empty file is refused', () => {
    expect(checkPicture(picture('image/png', 0))).toMatch(/empty/)
  })
})

// --- shrinking -------------------------------------------------------------------

describe('shrinking', () => {
  it('a 4000×3000 photo comes out 512×384 WebP, at most 300 KB', async () => {
    const { browser } = fakeBrowser()

    const shrunk = await shrinkPicture(picture(), browser)

    expect(shrunk).toMatchObject({ type: 'image/webp', width: 512, height: 384 })
    expect(shrunk.blob.type).toBe('image/webp')
    expect(shrunk.blob.size).toBeLessThanOrEqual(MAX_PICTURE_BYTES)
    expect(browser.render).toHaveBeenCalledWith(expect.anything(), 512, 384, null)
  })

  it('a small picture is never enlarged', async () => {
    const { browser } = fakeBrowser({ width: 300, height: 200 })

    expect(await shrinkPicture(picture(), browser)).toMatchObject({ width: 300, height: 200 })
  })

  it('quality drops step by step until the picture fits', async () => {
    const { browser } = fakeBrowser({ sizeOf: (_, q) => (q > 0.6 ? MAX_PICTURE_BYTES + 1 : MAX_PICTURE_BYTES) })

    const shrunk = await shrinkPicture(picture(), browser)

    expect(browser.encode.mock.calls.map(([, , q]) => q)).toEqual([0.85, 0.75, 0.65, 0.55])
    expect(shrunk.blob.size).toBe(MAX_PICTURE_BYTES)
  })

  it('stops at the first quality that fits', async () => {
    const { browser } = fakeBrowser()
    await shrinkPicture(picture(), browser)
    expect(browser.encode).toHaveBeenCalledTimes(1)
    expect(browser.encode).toHaveBeenCalledWith(expect.anything(), 'image/webp', QUALITY_STEPS[0])
  })

  it('a picture too big even at the lowest quality is refused', async () => {
    const { browser } = fakeBrowser({ sizeOf: () => MAX_PICTURE_BYTES + 1 })

    await expect(shrinkPicture(picture(), browser)).rejects.toThrow(/still over 300 KB/)
    expect(browser.encode).toHaveBeenCalledTimes(QUALITY_STEPS.length)
  })

  it('a refused file is never decoded', async () => {
    const { browser } = fakeBrowser()

    await expect(shrinkPicture(picture('text/plain'), browser)).rejects.toBeInstanceOf(PictureProblem)
    await expect(shrinkPicture(picture('image/jpeg', MAX_SOURCE_BYTES + 1), browser)).rejects.toThrow(/10 MB/)
    expect(browser.decode).not.toHaveBeenCalled()
  })

  it('a file that will not decode is refused with a message', async () => {
    const { browser } = fakeBrowser({ decodeFails: true })

    await expect(shrinkPicture(picture(), browser)).rejects.toThrow(/couldn’t be read/)
    expect(browser.encode).not.toHaveBeenCalled()
  })

  it('a browser that cannot encode at all is refused with a message', async () => {
    const { browser } = fakeBrowser({ encodeFails: true })
    await expect(shrinkPicture(picture(), browser)).rejects.toThrow(/could not save the picture/)
  })

  it('the decoded picture is let go, whether it worked or not', async () => {
    const ok = fakeBrowser()
    await shrinkPicture(picture(), ok.browser)
    expect(ok.close).toHaveBeenCalledTimes(1)

    const tooBig = fakeBrowser({ sizeOf: () => MAX_PICTURE_BYTES + 1 })
    await expect(shrinkPicture(picture(), tooBig.browser)).rejects.toThrow()
    expect(tooBig.close).toHaveBeenCalledTimes(1)
  })
})

describe('without WebP', () => {
  it('JPEG is used instead, drawn on white', async () => {
    const { browser } = fakeBrowser({ webp: false })

    const shrunk = await shrinkPicture(picture('image/png'), browser)

    expect(shrunk.type).toBe('image/jpeg')
    expect(browser.render).toHaveBeenLastCalledWith(expect.anything(), 512, 384, '#ffffff')
  })

  it('WebP is kept transparent: no background', async () => {
    const { browser } = fakeBrowser()
    await shrinkPicture(picture('image/png'), browser)
    expect(browser.render).toHaveBeenCalledTimes(1)
    expect(browser.render.mock.calls[0]![3]).toBeNull()
  })

  it('is found out once, then JPEG is used straight away', async () => {
    const first = fakeBrowser({ webp: false })
    await shrinkPicture(picture(), first.browser)
    expect(first.browser.encode.mock.calls.map(([, type]) => type)).toEqual(['image/webp', 'image/jpeg'])

    const second = fakeBrowser({ webp: false })
    await shrinkPicture(picture(), second.browser)
    expect(second.browser.encode.mock.calls.map(([, type]) => type)).toEqual(['image/jpeg'])
  })

  it('a JPEG too big at every quality is refused', async () => {
    const { browser } = fakeBrowser({ webp: false, sizeOf: () => MAX_PICTURE_BYTES + 1 })
    await expect(shrinkPicture(picture(), browser)).rejects.toThrow(/still over 300 KB/)
  })

  it('a browser that does encode WebP keeps being asked for it', async () => {
    await shrinkPicture(picture(), fakeBrowser().browser)
    const second = fakeBrowser()
    await shrinkPicture(picture(), second.browser)
    expect(second.browser.encode.mock.calls.map(([, type]) => type)).toEqual(['image/webp'])
  })
})

// --- the real browser's steps ----------------------------------------------------

describe('the browser steps', () => {
  const context = {
    fillStyle: '',
    imageSmoothingQuality: 'low',
    fillRect: vi.fn(),
    drawImage: vi.fn(),
  }

  beforeEach(() => {
    context.fillRect.mockClear()
    context.drawImage.mockClear()
    vi.spyOn(HTMLCanvasElement.prototype, 'getContext').mockReturnValue(
      context as unknown as CanvasRenderingContext2D,
    )
  })

  afterEach(() => vi.restoreAllMocks())

  it('decoding turns a photo upright by its EXIF orientation', async () => {
    const createImageBitmap = vi.fn(async () => ({ width: 1, height: 1, close: vi.fn() }))
    vi.stubGlobal('createImageBitmap', createImageBitmap)
    const file = picture()

    await canvasBrowser.decode(file)

    expect(createImageBitmap).toHaveBeenCalledWith(file, { imageOrientation: 'from-image' })
  })

  it('drawing fills the canvas at the given size, on white only when asked', () => {
    const bitmap = {} as ImageBitmap

    const plain = canvasBrowser.render(bitmap, 512, 384, null)
    expect([plain.width, plain.height]).toEqual([512, 384])
    expect(context.fillRect).not.toHaveBeenCalled()
    expect(context.drawImage).toHaveBeenCalledWith(bitmap, 0, 0, 512, 384)

    canvasBrowser.render(bitmap, 300, 200, '#ffffff')
    expect(context.fillStyle).toBe('#ffffff')
    expect(context.fillRect).toHaveBeenCalledWith(0, 0, 300, 200)
  })

  it('a canvas that cannot draw is refused with a message', () => {
    vi.spyOn(HTMLCanvasElement.prototype, 'getContext').mockReturnValue(null)
    expect(() => canvasBrowser.render({} as ImageBitmap, 1, 1, null)).toThrow(PictureProblem)
  })

  it('encoding asks the canvas for the type and quality', async () => {
    const made = new Blob(['x'], { type: 'image/webp' })
    const toBlob = vi
      .spyOn(HTMLCanvasElement.prototype, 'toBlob')
      .mockImplementation((done: BlobCallback) => done(made))
    const canvas = document.createElement('canvas')

    expect(await canvasBrowser.encode(canvas, 'image/webp', 0.75)).toBe(made)
    expect(toBlob).toHaveBeenCalledWith(expect.any(Function), 'image/webp', 0.75)
  })
})
