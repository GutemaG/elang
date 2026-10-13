import { describe, expect, it } from 'vitest'

import { manifestCsv } from './backup'
import { crc32, zipParts } from './zip'

const bytes = (text: string) => new TextEncoder().encode(text)

function join(parts: Uint8Array[]): Uint8Array {
  const out = new Uint8Array(parts.reduce((n, p) => n + p.length, 0))
  let at = 0
  for (const p of parts) {
    out.set(p, at)
    at += p.length
  }
  return out
}

/** Reads a ZIP back through its central directory, as an unzip tool does. */
function unzip(zip: Uint8Array): { path: string; text: string; crc: number; flags: number }[] {
  const view = new DataView(zip.buffer)
  const end = zip.length - 22
  expect(view.getUint32(end, true)).toBe(0x06054b50)
  const count = view.getUint16(end + 10, true)
  let at = view.getUint32(end + 16, true)
  const decoder = new TextDecoder()
  const files = []
  for (let i = 0; i < count; i++) {
    expect(view.getUint32(at, true)).toBe(0x02014b50)
    const crc = view.getUint32(at + 16, true)
    const size = view.getUint32(at + 20, true)
    const nameLength = view.getUint16(at + 28, true)
    const offset = view.getUint32(at + 42, true)
    const path = decoder.decode(zip.subarray(at + 46, at + 46 + nameLength))
    expect(view.getUint32(offset, true)).toBe(0x04034b50)
    const flags = view.getUint16(offset + 6, true)
    const start = offset + 30 + view.getUint16(offset + 26, true)
    files.push({ path, text: decoder.decode(zip.subarray(start, start + size)), crc, flags })
    at += 46 + nameLength
  }
  return files
}

describe('the backup ZIP', () => {
  it('computes the standard CRC-32', () => {
    expect(crc32(bytes('hello'))).toBe(0x3610a686)
    expect(crc32(new Uint8Array())).toBe(0)
  })

  it('stores each file under its path, UTF-8 names included', () => {
    const zip = join(
      zipParts([
        { path: 'buna/english-to-amharic/ex01-listening.m4a', data: bytes('audio-1') },
        { path: 'buna/manifest.csv', data: bytes('ሰላም') },
      ]),
    )

    const files = unzip(zip)
    expect(files.map((f) => [f.path, f.text])).toEqual([
      ['buna/english-to-amharic/ex01-listening.m4a', 'audio-1'],
      ['buna/manifest.csv', 'ሰላም'],
    ])
    expect(files[0]!.crc).toBe(crc32(bytes('audio-1')))
    expect(files.every((f) => f.flags === 0x0800)).toBe(true)
  })

  it('is a valid empty archive with no files', () => {
    expect(unzip(join(zipParts([])))).toEqual([])
  })
})

describe('the manifest', () => {
  it('has one row per use with a link back to the admin, and marks failed downloads', () => {
    const csv = manifestCsv(
      [
        {
          zip_path: 'c/ex02-listening-aaaaaa.m4a',
          status: 'in_use',
          key: 'am/l/aaaaaa.m4a',
          url: 'https://pub/am/l/aaaaaa.m4a',
          size: 1000,
          uploaded_at: '2026-10-01T08:00:00Z',
          use: {
            place: 'exercise',
            language: 'am',
            admin_path: '/courses/c1/lessons/l1/exercises/e2',
            course_title: 'English to Amharic',
            course_id: 'c1',
            section: 'Greetings',
            skill: 'Hello',
            lesson: 'Saying hi',
            exercise_id: 'e2',
            exercise_number: 2,
            exercise_type: 'listening',
            prompt: 'What did you hear?',
            text: null,
            english: null,
            letter: null,
          },
        },
        { zip_path: '', status: 'missing', key: 'am/l/gone.m4a', url: 'u', size: null, uploaded_at: null, use: null },
      ],
      new Set(['am/l/aaaaaa.m4a']),
      'https://admin.example',
    )

    expect(csv.startsWith('﻿file,status,place,course,section,skill,lesson,exercise_number')).toBe(true)
    const [, first, second] = csv.split('\r\n')
    expect(first).toBe(
      'c/ex02-listening-aaaaaa.m4a,download_failed,Exercise,English to Amharic,Greetings,Hello,Saying hi,2,Listening,' +
        'What did you hear?,,,,https://admin.example/courses/c1/lessons/l1/exercises/e2,am/l/aaaaaa.m4a,' +
        'https://pub/am/l/aaaaaa.m4a,1000,2026-10-01T08:00:00Z',
    )
    expect(second).toBe(',missing,,,,,,,,,,,,,am/l/gone.m4a,u,,')
  })
})
