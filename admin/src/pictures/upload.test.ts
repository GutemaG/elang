import { beforeEach, describe, expect, it, vi } from 'vitest'

import { ApiClient, ApiError } from '../api'
import { FakeServer, type Call } from '../test/fakeServer'
import { PictureProblem } from './shrink'
import { shrinkAndUpload, uploadPicture } from './upload'

const BASE = 'http://localhost:8000'
const UPLOADS = '/api/v1/admin/images/uploads'
const STORE_PATH = '/am/lesson-1/0123456789ab.webp'
const PUBLIC_URL = 'https://pub.example/am/lesson-1/0123456789ab.webp'

let server: FakeServer

const api = () => new ApiClient({ baseUrl: BASE, getToken: () => 'session-abc', onUnauthorized: vi.fn() })
const shrunk = (bytes = 30_000) => new Blob([new Uint8Array(bytes)], { type: 'image/webp' })

beforeEach(() => {
  server = new FakeServer()
    .install()
    .on('POST', UPLOADS, (call: Call) => ({
      status: 201,
      body: {
        upload_url: `https://store.example${STORE_PATH}?X-Amz-Signature=abc`,
        method: 'PUT',
        headers: { 'Content-Type': (call.body as { content_type: string }).content_type },
        key: STORE_PATH.slice(1),
        public_url: PUBLIC_URL,
        expires_in: 600,
      },
    }))
    .on('PUT', STORE_PATH, { status: 200 })
})

describe('uploading a picture', () => {
  it('asks for a link for this lesson, type and exact size, and returns its address', async () => {
    const picture = shrunk(12_345)

    const url = await uploadPicture(api(), 'lesson-1', picture, 'image/webp')

    expect(url).toBe(PUBLIC_URL)
    expect(server.callsTo('POST', UPLOADS)[0]!.body).toEqual({
      lesson_id: 'lesson-1',
      content_type: 'image/webp',
      size: 12_345,
    })
  })

  it('PUTs the bytes with exactly the signed headers, and no session token', async () => {
    const picture = shrunk()

    await uploadPicture(api(), 'lesson-1', picture, 'image/jpeg')

    const put = server.callsTo('PUT', STORE_PATH)[0]!
    expect(put.query).toBe('?X-Amz-Signature=abc')
    expect(put.headers).toEqual({ 'Content-Type': 'image/jpeg' })
    expect(put.token).toBeNull()
    expect(put.raw).toBe(picture)
  })

  it('a server with nowhere to store pictures says so', async () => {
    server.on('POST', UPLOADS, {
      status: 503,
      body: { error_code: 'audio_storage_not_configured', message: 'Audio storage is not configured.' },
    })

    await expect(uploadPicture(api(), 'lesson-1', shrunk(), 'image/webp')).rejects.toThrow(
      'This server has nowhere to store pictures yet, so pictures can’t be uploaded.',
    )
    expect(server.callsTo('PUT', STORE_PATH)).toHaveLength(0)
  })

  it('a refused link request passes the server’s own message on', async () => {
    server.on('POST', UPLOADS, {
      status: 422,
      body: { error_code: 'validation_error', message: 'size must be at most 1048576' },
    })
    await expect(uploadPicture(api(), 'lesson-1', shrunk(), 'image/webp')).rejects.toThrow(
      'size must be at most 1048576',
    )
  })

  it('an unreachable store is named as the picture store', async () => {
    server.on('PUT', STORE_PATH, () => {
      throw new TypeError('Failed to fetch')
    })
    const error = await uploadPicture(api(), 'lesson-1', shrunk(), 'image/webp').catch((e: unknown) => e)
    expect(error).toBeInstanceOf(ApiError)
    expect((error as ApiError).message).toMatch(/^Could not reach the picture store\./)
  })

  it('a refused PUT says whether the link may have expired', async () => {
    server.on('PUT', STORE_PATH, { status: 403 })
    await expect(uploadPicture(api(), 'lesson-1', shrunk(), 'image/webp')).rejects.toThrow(
      'The picture store refused the upload, perhaps because its link expired. Try again.',
    )
    server.on('PUT', STORE_PATH, { status: 500 })
    await expect(uploadPicture(api(), 'lesson-1', shrunk(), 'image/webp')).rejects.toThrow(
      'The picture store refused the upload (500). Try again.',
    )
  })
})

describe('shrinking, then uploading', () => {
  it('a file that is not a picture is refused, and nothing is sent', async () => {
    const text = new File(['hello'], 'notes.txt', { type: 'text/plain' })

    await expect(shrinkAndUpload(api(), 'lesson-1', text)).rejects.toBeInstanceOf(PictureProblem)
    expect(server.calls).toHaveLength(0)
  })

  it('a picture over 10 MB is refused, and nothing is sent', async () => {
    const huge = new File([new Uint8Array(10 * 1024 * 1024 + 1)], 'huge.jpg', { type: 'image/jpeg' })

    await expect(shrinkAndUpload(api(), 'lesson-1', huge)).rejects.toThrow(/10 MB at most/)
    expect(server.calls).toHaveLength(0)
  })
})
