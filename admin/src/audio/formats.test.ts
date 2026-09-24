import { describe, expect, it, vi } from 'vitest'

import {
  AUDIO_TYPES,
  IPHONE_SAFE_RECORDING,
  MAX_AUDIO_BYTES,
  audioTypeOf,
  baseType,
  canRecord,
  checkClip,
  formatDuration,
  formatSize,
  recordingType,
} from './formats'

describe('the allowed types', () => {
  it('are exactly the backend’s', () => {
    // AUDIO_TYPES in backend/app/application/admin_audio_use_cases.py.
    expect([...AUDIO_TYPES].sort()).toEqual(['audio/mp4', 'audio/mpeg', 'audio/ogg', 'audio/webm', 'audio/x-m4a'])
    expect(MAX_AUDIO_BYTES).toBe(5 * 1024 * 1024)
  })
})

describe('baseType', () => {
  it.each([
    ['audio/webm;codecs=opus', 'audio/webm'],
    ['audio/mp4;codecs=mp4a.40.2', 'audio/mp4'],
    [' Audio/MPEG ', 'audio/mpeg'],
    ['', ''],
  ])('%s -> %s', (type, base) => {
    expect(baseType(type)).toBe(base)
  })
})

describe('audioTypeOf', () => {
  it.each([
    [{ type: 'audio/mpeg' }, 'audio/mpeg'],
    [{ type: 'audio/x-m4a' }, 'audio/x-m4a'],
    [{ type: 'audio/webm;codecs=opus' }, 'audio/webm'],
    [{ type: 'audio/mp3' }, 'audio/mpeg'],
    [{ type: 'audio/m4a' }, 'audio/mp4'],
    [{ name: 'clip.M4A', type: '' }, 'audio/mp4'],
    [{ name: 'clip.mp3', type: '' }, 'audio/mpeg'],
    [{ name: 'clip.ogg', type: '' }, 'audio/ogg'],
  ])('%o is sent as %s', (clip, type) => {
    expect(audioTypeOf(clip)).toBe(type)
  })

  it.each([
    [{ type: 'audio/wav' }],
    [{ type: 'video/webm' }],
    [{ name: 'clip.webm', type: 'video/webm' }],
    [{ type: 'image/png' }],
    [{ name: 'clip.wav', type: '' }],
    [{ name: 'm4a', type: '' }],
    [{ type: '' }],
  ])('%o is refused', (clip) => {
    expect(audioTypeOf(clip)).toBeNull()
  })
})

describe('checkClip', () => {
  const clip = (type: string, size: number, name = 'clip') => ({ name, type, size })

  it('accepts an allowed type up to exactly 5 MB', () => {
    expect(checkClip(clip('audio/mpeg', MAX_AUDIO_BYTES))).toEqual({ ok: true, type: 'audio/mpeg' })
  })

  it('refuses one byte more, naming the size', () => {
    expect(checkClip(clip('audio/mpeg', MAX_AUDIO_BYTES + 1))).toEqual({
      ok: false,
      problem: 'That file is 5.0 MB. Clips can be 5 MB at most.',
    })
    expect(checkClip(clip('audio/mpeg', 8 * 1024 * 1024))).toMatchObject({ problem: expect.stringMatching(/8\.0 MB/) })
  })

  it('refuses an empty file', () => {
    expect(checkClip(clip('audio/mpeg', 0))).toEqual({ ok: false, problem: 'That file is empty.' })
  })

  it('tells an unstorable audio format from something that is not audio', () => {
    expect(checkClip(clip('audio/wav', 10))).toMatchObject({ ok: false, problem: expect.stringMatching(/format can’t be stored/) })
    expect(checkClip(clip('image/png', 10))).toMatchObject({ ok: false, problem: expect.stringMatching(/isn’t an audio file/) })
  })
})

describe('recordingType', () => {
  function recorderSupporting(...types: string[]) {
    vi.stubGlobal('MediaRecorder', { isTypeSupported: (t: string) => types.includes(t) })
  }

  it('is AAC in mp4 whenever the browser has it', () => {
    recorderSupporting('audio/webm', 'audio/mp4', IPHONE_SAFE_RECORDING)
    expect(recordingType()).toBe('audio/mp4;codecs=mp4a.40.2')
  })

  it('then plain mp4, then WebM, then whatever the browser picks', () => {
    recorderSupporting('audio/webm', 'audio/mp4')
    expect(recordingType()).toBe('audio/mp4')
    recorderSupporting('audio/webm')
    expect(recordingType()).toBe('audio/webm')
    recorderSupporting()
    expect(recordingType()).toBe('')
  })

  it('is empty, and recording impossible, without MediaRecorder', () => {
    expect(recordingType()).toBe('')
    expect(canRecord()).toBe(false)
  })
})

describe('formatting', () => {
  it.each([
    [512, '512 B'],
    [70 * 1024, '70 KB'],
    [5 * 1024 * 1024, '5.0 MB'],
  ])('%i bytes is %s', (bytes, text) => {
    expect(formatSize(bytes)).toBe(text)
  })

  it.each([
    [0, '0:00'],
    [4.9, '0:04'],
    [75, '1:15'],
    [120, '2:00'],
    [-1, '0:00'],
  ])('%s seconds is %s', (seconds, text) => {
    expect(formatDuration(seconds)).toBe(text)
  })
})
