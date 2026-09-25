import type { ApiClient } from '../api'
import { routes } from '../tree/levels'
import { uploadThroughLink } from '../upload/link'
import type { AudioLinkResponse } from '../types'

/** Stores one clip and returns the address to save as `audio_url`, through
 * a short-lived link (see `uploadThroughLink`). */
export function uploadClip(api: ApiClient, lessonId: string, clip: Blob, type: string): Promise<string> {
  return uploadThroughLink(api, routes.audioUploads, lessonId, clip, type, {
    notConfigured: 'This server has nowhere to store audio yet, so clips can’t be uploaded. Paste a link instead.',
    store: 'audio store',
  })
}

/** Asks the server to check a pasted link answers with audio. */
export function checkLink(api: ApiClient, url: string): Promise<AudioLinkResponse> {
  return api.post<AudioLinkResponse>(routes.audioLinks, { url })
}
