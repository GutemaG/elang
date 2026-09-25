import type { ApiClient } from '../api'
import { routes } from '../tree/levels'
import { uploadThroughLink } from '../upload/link'
import { canvasBrowser, shrinkPicture } from './shrink'

/** Stores one shrunk picture and returns the address to save as a
 * choice's `image_url`, through a short-lived link (see
 * `uploadThroughLink`). */
export function uploadPicture(api: ApiClient, lessonId: string, picture: Blob, type: string): Promise<string> {
  return uploadThroughLink(api, routes.imageUploads, lessonId, picture, type, {
    notConfigured: 'This server has nowhere to store pictures yet, so pictures can’t be uploaded.',
    store: 'picture store',
  })
}

/** What happens to a picked file: shrunk in this browser, then uploaded.
 * Throws a PictureProblem or an ApiError, both with a message for the
 * admin; nothing is uploaded unless shrinking worked. */
export async function shrinkAndUpload(api: ApiClient, lessonId: string, file: File): Promise<string> {
  const shrunk = await shrinkPicture(file, canvasBrowser)
  return uploadPicture(api, lessonId, shrunk.blob, shrunk.type)
}
