import { beforeEach, describe, expect, it, vi, type Mock } from 'vitest'

import { ApiClient, ApiError } from './api'
import { FakeServer } from './test/fakeServer'

const BASE = 'http://localhost:8000'

let server: FakeServer
let unauthorized: Mock<() => void>
let token: string | null

function client(): ApiClient {
  return new ApiClient({ baseUrl: BASE, getToken: () => token, onUnauthorized: unauthorized })
}

beforeEach(() => {
  server = new FakeServer().install()
  unauthorized = vi.fn<() => void>()
  token = 'session-abc'
})

describe('requests', () => {
  it('sends the bearer token and the JSON body', async () => {
    server.on('POST', '/api/v1/admin/sections/sec-1/skills', { status: 201, body: { id: 'skill-9' } })

    await client().post('/api/v1/admin/sections/sec-1/skills', { title: 'Numbers' })

    const call = server.calls[0]!
    expect(call.token).toBe('session-abc')
    expect(call.body).toEqual({ title: 'Numbers' })
  })

  it('sends no Authorization header when there is no session', async () => {
    token = null
    server.on('GET', '/api/v1/admin/courses', { body: { courses: [] } })

    await client().get('/api/v1/admin/courses')

    expect(server.calls[0]!.token).toBeNull()
  })

  it('returns nothing for a 204', async () => {
    server.on('DELETE', '/api/v1/admin/sections/sec-1', { status: 204 })

    await expect(client().delete('/api/v1/admin/sections/sec-1')).resolves.toBeUndefined()
  })
})

describe('errors', () => {
  it('keeps the backend error code, message and details', async () => {
    server.on('DELETE', '/api/v1/admin/sections/sec-1', {
      status: 409,
      body: {
        error_code: 'confirmation_required',
        message: 'Deleting this section also deletes everything in it; repeat with confirm=true',
        details: { skills: 2, lessons: 4, exercises: 11 },
      },
    })

    const error = await client()
      .delete('/api/v1/admin/sections/sec-1')
      .catch((e: unknown) => e)

    expect(error).toBeInstanceOf(ApiError)
    const api = error as ApiError
    expect(api.status).toBe(409)
    expect(api.errorCode).toBe('confirmation_required')
    expect(api.details).toEqual({ skills: 2, lessons: 4, exercises: 11 })
  })

  it('reports a 401 so the session can end, and still raises', async () => {
    server.on('GET', '/api/v1/admin/me', {
      status: 401,
      body: { error_code: 'invalid_session', message: 'Session token is unknown or expired' },
    })

    await expect(client().get('/api/v1/admin/me')).rejects.toThrow('Session token is unknown or expired')
    expect(unauthorized).toHaveBeenCalledOnce()
  })

  it('does not report a 403 as a lost session', async () => {
    server.on('GET', '/api/v1/admin/me', { status: 403, body: { error_code: 'not_admin', message: 'Admins only' } })

    await expect(client().get('/api/v1/admin/me')).rejects.toThrow('Admins only')
    expect(unauthorized).not.toHaveBeenCalled()
  })

  it("reads FastAPI's own validation errors", async () => {
    server.on('POST', '/api/v1/admin/courses/course-1/sections', {
      status: 422,
      body: { detail: [{ msg: 'Field required', loc: ['body', 'title'] }] },
    })

    await expect(client().post('/api/v1/admin/courses/course-1/sections', {})).rejects.toThrow('Field required')
  })

  it('falls back to the status when the body is not JSON', async () => {
    vi.stubGlobal('fetch', async () => new Response('<html>Bad gateway</html>', { status: 502 }))

    await expect(client().get('/api/v1/admin/courses')).rejects.toThrow('The server answered 502.')
  })

  it('turns a dead connection into a readable message', async () => {
    vi.stubGlobal('fetch', async () => {
      throw new TypeError('Failed to fetch')
    })

    const error = await client()
      .get('/api/v1/admin/courses')
      .catch((e: unknown) => e)

    expect((error as ApiError).errorCode).toBe('network_error')
    expect((error as ApiError).message).toMatch(/Could not reach the server/)
  })
})

describe('files (intent 027)', () => {
  it('returns a file’s bytes and the headers that describe it', async () => {
    server.on('POST', '/api/v1/admin/voice/generate', {
      body: new Blob(['ID3-mp3'], { type: 'audio/mpeg' }),
      headers: { 'Content-Type': 'audio/mpeg', 'X-Voice-Id': 'om-obse' },
    })

    const { blob, headers } = await client().postForBlob('/api/v1/admin/voice/generate', { text: 'Akkam' })

    expect(await blob.text()).toBe('ID3-mp3')
    expect(headers.get('X-Voice-Id')).toBe('om-obse')
    const call = server.callsTo('POST', '/api/v1/admin/voice/generate')[0]!
    expect(call.token).toBe('session-abc')
    expect(call.body).toEqual({ text: 'Akkam' })
  })

  it('turns a JSON error into an ApiError', async () => {
    server.on('POST', '/api/v1/admin/voice/generate', {
      status: 402,
      body: { error_code: 'voice_credit_exhausted', message: 'The Addis AI credit has run out.' },
    })

    await expect(client().postForBlob('/api/v1/admin/voice/generate', {})).rejects.toMatchObject({
      status: 402,
      errorCode: 'voice_credit_exhausted',
      message: 'The Addis AI credit has run out.',
    })
  })
})
