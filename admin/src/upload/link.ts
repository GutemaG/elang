import { ApiError, type ApiClient } from '../api'
import type { AudioUploadResponse } from '../types'

/** What a failure says, in the words of the kind of file being stored. */
export interface UploadWords {
  /** Sentence for a server with nowhere to store this kind of file (503). */
  notConfigured: string
  /** "audio store", "picture store". */
  store: string
}

/** Stores one file through a short-lived link and returns its public
 * address (bolts 039 and 052).
 *
 * Two requests: the admin API hands out a link signed for this lesson,
 * type and exact size, then the file goes straight to the store (R2, or
 * the local backend). The second request is a plain `fetch`, not the API
 * client: it must carry exactly the headers the link was signed with and
 * no bearer token, which R2 would refuse. Setting Content-Type explicitly
 * also keeps a recording's `;codecs=...` from reaching the store. */
export async function uploadThroughLink(
  api: ApiClient,
  route: string,
  lessonId: string,
  file: Blob,
  type: string,
  words: UploadWords,
): Promise<string> {
  let link: AudioUploadResponse
  try {
    link = await api.post<AudioUploadResponse>(route, {
      lesson_id: lessonId,
      content_type: type,
      size: file.size,
    })
  } catch (e) {
    if (e instanceof ApiError && e.status === 503) {
      throw new ApiError(503, e.errorCode, words.notConfigured)
    }
    throw e
  }

  let response: Response
  try {
    response = await fetch(link.upload_url, { method: 'PUT', headers: link.headers, body: file })
  } catch {
    // Also what a store without a CORS rule for this site looks like.
    throw new ApiError(
      0,
      'upload_unreachable',
      `Could not reach the ${words.store}. Check your connection and try again. If it keeps happening, the store may not allow uploads from this site yet.`,
    )
  }
  if (!response.ok) {
    throw new ApiError(
      response.status,
      'upload_refused',
      response.status === 403
        ? `The ${words.store} refused the upload, perhaps because its link expired. Try again.`
        : `The ${words.store} refused the upload (${response.status}). Try again.`,
    )
  }
  return link.public_url
}
