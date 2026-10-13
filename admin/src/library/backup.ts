// Building the audio backup in the browser (intent 029, FR-8): fetch each
// file from its signed link, then write the ZIP with a manifest that ties
// every file to the exercise, Workbook row or letter that uses it.

import Papa from 'papaparse'

import type { AudioExport, ExportRow } from './api'
import { typeLabel } from './api'
import { zipParts, type ZipEntry } from './zip'

export const MANIFEST_COLUMNS = [
  'file',
  'status',
  'place',
  'course',
  'section',
  'skill',
  'lesson',
  'exercise_number',
  'exercise_type',
  'prompt',
  'text',
  'english',
  'letter',
  'open_in_admin',
  'key',
  'original_url',
  'size_bytes',
  'uploaded_at',
] as const

const PLACE: Record<string, string> = {
  exercise: 'Exercise',
  workbook: 'Workbook',
  sound: 'Sounds letter',
  sound_example: 'Sounds example word',
}

/** The manifest as CSV, with a BOM so Excel reads Fidel and Qubee. */
export function manifestCsv(rows: ExportRow[], failed: ReadonlySet<string>, origin: string): string {
  const data = rows.map((r) => {
    const u = r.use
    return [
      r.zip_path,
      failed.has(r.key) ? 'download_failed' : r.status,
      u ? PLACE[u.place] : '',
      u?.course_title ?? '',
      u?.section ?? '',
      u?.skill ?? '',
      u?.lesson ?? '',
      u?.exercise_number ?? '',
      typeLabel(u?.exercise_type ?? null),
      u?.prompt ?? '',
      u?.text ?? '',
      u?.english ?? '',
      u?.letter ?? '',
      u ? `${origin}${u.admin_path}` : '',
      r.key,
      r.url,
      r.size ?? '',
      r.uploaded_at ?? '',
    ]
  })
  return '﻿' + Papa.unparse({ fields: [...MANIFEST_COLUMNS], data }, { newline: '\r\n' })
}

export interface Progress {
  done: number
  total: number
}

export interface Backup {
  parts: Uint8Array[]
  failed: string[]
}

/** Downloads every file (a few at a time), then zips them with
 * `manifest.csv`. A file that fails is left out and marked in the manifest. */
export async function buildBackup(
  plan: AudioExport,
  {
    origin,
    signal,
    onProgress,
    concurrency = 4,
  }: { origin: string; signal?: AbortSignal; onProgress?: (p: Progress) => void; concurrency?: number },
): Promise<Backup> {
  const data = new Map<string, Uint8Array>()
  const failed = new Set<string>()
  let next = 0
  let done = 0
  const total = plan.files.length
  onProgress?.({ done, total })

  async function worker() {
    while (next < total) {
      const file = plan.files[next++]!
      try {
        const response = await fetch(file.download_url, { signal })
        if (!response.ok) throw new Error(String(response.status))
        data.set(file.key, new Uint8Array(await response.arrayBuffer()))
      } catch (e) {
        if (signal?.aborted) throw e
        failed.add(file.key)
      }
      onProgress?.({ done: ++done, total })
    }
  }
  await Promise.all(Array.from({ length: Math.min(concurrency, total) }, worker))
  if (signal?.aborted) throw new DOMException('Cancelled', 'AbortError')

  const entries: ZipEntry[] = plan.files
    .filter((f) => data.has(f.key))
    .map((f) => ({ path: `${plan.name}/${f.zip_path}`, data: data.get(f.key)! }))
  entries.push({
    path: `${plan.name}/manifest.csv`,
    data: new TextEncoder().encode(manifestCsv(plan.rows, failed, origin)),
  })
  return { parts: zipParts(entries), failed: [...failed] }
}

export function saveBlob(name: string, blob: Blob): void {
  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = name
  document.body.append(link)
  link.click()
  link.remove()
  setTimeout(() => URL.revokeObjectURL(url), 0)
}
