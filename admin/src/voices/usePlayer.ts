import { useCallback, useEffect, useRef, useState } from 'react'

export interface Player {
  /** The key of what is playing, or null. */
  playing: string | null
  /** Plays `src`, stopping anything else first. Resolves false when the
   * browser refuses to play it. A `blob:` source is freed once replaced. */
  play: (key: string, src: string) => Promise<boolean>
  stop: () => void
}

/** One sound at a time for a whole page: a voice preview or a try. */
export function usePlayer(): Player {
  const audio = useRef<HTMLAudioElement | null>(null)
  const blobUrl = useRef<string | null>(null)
  const [playing, setPlaying] = useState<string | null>(null)

  const element = useCallback(() => {
    if (!audio.current) {
      audio.current = new Audio()
      audio.current.addEventListener('ended', () => setPlaying(null))
    }
    return audio.current
  }, [])

  const stop = useCallback(() => {
    audio.current?.pause()
    setPlaying(null)
  }, [])

  const play = useCallback(
    async (key: string, src: string) => {
      const el = element()
      el.pause()
      if (blobUrl.current && blobUrl.current !== src) URL.revokeObjectURL(blobUrl.current)
      blobUrl.current = src.startsWith('blob:') ? src : null
      el.src = src
      setPlaying(key)
      try {
        await el.play()
        return true
      } catch {
        setPlaying(null)
        return false
      }
    },
    [element],
  )

  useEffect(
    () => () => {
      audio.current?.pause()
      if (blobUrl.current) URL.revokeObjectURL(blobUrl.current)
    },
    [],
  )

  return { playing, play, stop }
}
