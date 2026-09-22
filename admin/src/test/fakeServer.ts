import { vi } from 'vitest'

export interface Call {
  method: string
  path: string
  query: string
  body: unknown
  token: string | null
}

export interface Reply {
  status?: number
  body?: unknown
}

type Handler = (call: Call) => Reply

/** A stand-in for the backend: routes are registered per test, and every
 * request is recorded, so tests assert on what the site actually sent. */
export class FakeServer {
  readonly calls: Call[] = []
  private readonly handlers = new Map<string, Handler>()

  on(method: string, path: string, reply: Reply | Handler): this {
    this.handlers.set(`${method} ${path}`, typeof reply === 'function' ? reply : () => reply)
    return this
  }

  /** Calls to one route, in order. */
  callsTo(method: string, path: string): Call[] {
    return this.calls.filter((c) => c.method === method && c.path === path)
  }

  install(): this {
    vi.stubGlobal('fetch', async (input: RequestInfo | URL, init?: RequestInit) => {
      const url = new URL(String(input))
      const method = init?.method ?? 'GET'
      const headers = (init?.headers ?? {}) as Record<string, string>
      const call: Call = {
        method,
        path: url.pathname,
        query: url.search,
        body: typeof init?.body === 'string' ? (JSON.parse(init.body) as unknown) : null,
        token: headers.Authorization?.replace('Bearer ', '') ?? null,
      }
      this.calls.push(call)

      const handler = this.handlers.get(`${method} ${url.pathname}`)
      if (!handler) {
        return json(404, { error_code: 'not_found', message: `No fake route for ${method} ${url.pathname}` })
      }
      const reply = handler(call)
      const status = reply.status ?? 200
      if (status === 204 || reply.body === undefined) return new Response(null, { status })
      return json(status, reply.body)
    })
    return this
  }
}

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } })
}
