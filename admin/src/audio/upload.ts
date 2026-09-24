import { ApiError, type ApiClient } from '../api'
import { routes } from '../tree/levels'
import type { AudioLinkResponse, AudioUploadResponse } from '../types'

/** Stores one clip and returns the address to save as `audio_url`.
 *
 * Two requests: the admin API hands out a short-lived link signed for this
 * lesson, type and exact size, then the clip goes straight to the store
 * (R2, or the local backend). The second request is a plain `fetch`, not
 * the API client: it must carry exactly the headers the link was signed
 * with and no bearer token, which R2 would refuse. Setting Content-Type
 * explicitly also keeps a recording's `;codecs=...` from reaching the
 * store. */
export async function uploadClip(api: ApiClient, lessonId: string, clip: Blob, type: string): Promise<string> {
  let link: AudioUploadResponse
  try {
    link = await api.post<AudioUploadResponse>(routes.audioUploads, {
      lesson_id: lessonId,
      content_type: type,
      size: clip.size,
    })
  } catch (e) {
    if (e instanceof ApiError && e.status === 503) {
      throw new ApiError(
        503,
        e.errorCode,
        'This server has nowhere to store audio yet, so clips can’t be uploaded. Paste a link instead.',
      )
    }
    throw e
  }

  let response: Response
  try {
    response = await fetch(link.upload_url, { method: 'PUT', headers: link.headers, body: clip })
  } catch {
    // Also what a store without a CORS rule for this site looks like.
    throw new ApiError(
      0,
      'upload_unreachable',
      'Could not reach the audio store. Check your connection and try again. If it keeps happening, the store may not allow uploads from this site yet.',
    )
  }
  if (!response.ok) {
    throw new ApiError(
      response.status,
      'upload_refused',
      response.status === 403
        ? 'The audio store refused the upload, perhaps because its link expired. Try again.'
        : `The audio store refused the upload (${response.status}). Try again.`,
    )
  }
  return link.public_url
}

/** Asks the server to check a pasted link answers with audio. */
export function checkLink(api: ApiClient, url: string): Promise<AudioLinkResponse> {
  return api.post<AudioLinkResponse>(routes.audioLinks, { url })
}
