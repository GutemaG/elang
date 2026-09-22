// A small typed wrapper over fetch for the Buna backend. It adds the bearer
// token, turns error bodies into ApiError, and reports a 401 so the session
// can end -- every screen gets that for free.

export class ApiError extends Error {
  readonly status: number
  readonly errorCode: string
  readonly details: Record<string, unknown>

  constructor(status: number, errorCode: string, message: string, details: Record<string, unknown> = {}) {
    super(message)
    this.name = 'ApiError'
    this.status = status
    this.errorCode = errorCode
    this.details = details
  }
}

type Method = 'GET' | 'POST' | 'PATCH' | 'PUT' | 'DELETE'

export interface ApiClientOptions {
  baseUrl: string
  getToken: () => string | null
  /** Called when the server refuses the session (any 401). */
  onUnauthorized: () => void
}

export class ApiClient {
  private readonly options: ApiClientOptions

  constructor(options: ApiClientOptions) {
    this.options = options
  }

  get<T>(path: string): Promise<T> {
    return this.request<T>('GET', path)
  }

  post<T>(path: string, body?: unknown): Promise<T> {
    return this.request<T>('POST', path, body)
  }

  patch<T>(path: string, body: unknown): Promise<T> {
    return this.request<T>('PATCH', path, body)
  }

  put<T>(path: string, body: unknown): Promise<T> {
    return this.request<T>('PUT', path, body)
  }

  delete(path: string): Promise<void> {
    return this.request<void>('DELETE', path)
  }

  private async request<T>(method: Method, path: string, body?: unknown): Promise<T> {
    const headers: Record<string, string> = { Accept: 'application/json' }
    const token = this.options.getToken()
    if (token) headers.Authorization = `Bearer ${token}`
    if (body !== undefined) headers['Content-Type'] = 'application/json'

    let response: Response
    try {
      response = await fetch(`${this.options.baseUrl}${path}`, {
        method,
        headers,
        body: body === undefined ? undefined : JSON.stringify(body),
      })
    } catch {
      throw new ApiError(0, 'network_error', 'Could not reach the server. Check your connection and try again.')
    }

    if (response.status === 401) this.options.onUnauthorized()
    if (!response.ok) throw await toApiError(response)
    if (response.status === 204) return undefined as T
    return (await response.json()) as T
  }
}

async function toApiError(response: Response): Promise<ApiError> {
  let body: unknown = null
  try {
    body = await response.json()
  } catch {
    // Not JSON (a proxy page, say); fall through to a generic message.
  }
  if (body && typeof body === 'object') {
    const b = body as { error_code?: unknown; message?: unknown; details?: unknown; detail?: unknown }
    if (typeof b.error_code === 'string') {
      const details = b.details && typeof b.details === 'object' ? (b.details as Record<string, unknown>) : {}
      return new ApiError(response.status, b.error_code, String(b.message ?? b.error_code), details)
    }
    // FastAPI's own request-validation errors: {"detail": [...]}.
    if (b.detail !== undefined) {
      return new ApiError(response.status, 'invalid_request', describeDetail(b.detail))
    }
  }
  return new ApiError(response.status, 'http_error', `The server answered ${response.status}.`)
}

function describeDetail(detail: unknown): string {
  if (typeof detail === 'string') return detail
  if (Array.isArray(detail)) {
    const messages = detail
      .map((d) => (d && typeof d === 'object' && 'msg' in d ? String((d as { msg: unknown }).msg) : ''))
      .filter(Boolean)
    if (messages.length) return messages.join('; ')
  }
  return 'The request was not accepted.'
}
