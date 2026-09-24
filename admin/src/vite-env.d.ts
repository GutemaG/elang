/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_API_BASE_URL?: string
  readonly VITE_GOOGLE_CLIENT_ID?: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}

// The slice of Google Identity Services this site uses.
interface GoogleCredentialResponse {
  credential: string
}

interface Window {
  google?: {
    accounts: {
      id: {
        initialize(config: {
          client_id: string
          callback: (response: GoogleCredentialResponse) => void
          use_fedcm_for_button?: boolean
        }): void
        renderButton(parent: HTMLElement, options: Record<string, unknown>): void
        disableAutoSelect(): void
      }
    }
  }
}
