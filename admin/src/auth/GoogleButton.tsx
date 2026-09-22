import { useEffect, useRef, useState } from 'react'

import { GOOGLE_CLIENT_ID } from '../config'

interface Props {
  onCredential: (idToken: string) => void
}

/** Google's own "Sign in with Google" button, rendered by the GIS script in
 * index.html. The only place that talks to Google, so tests replace it. */
export function GoogleButton({ onCredential }: Props) {
  const container = useRef<HTMLDivElement>(null)
  const callback = useRef(onCredential)
  const [failed, setFailed] = useState(false)

  useEffect(() => {
    callback.current = onCredential
  }, [onCredential])

  useEffect(() => {
    if (!GOOGLE_CLIENT_ID) return
    let tries = 0
    // The script loads async; wait for it (up to ~10 s).
    const timer = window.setInterval(() => {
      const gis = window.google?.accounts.id
      if (gis && container.current) {
        window.clearInterval(timer)
        gis.initialize({ client_id: GOOGLE_CLIENT_ID, callback: (r) => callback.current(r.credential) })
        gis.renderButton(container.current, { theme: 'outline', size: 'large', text: 'signin_with' })
      } else if (++tries > 100) {
        window.clearInterval(timer)
        setFailed(true)
      }
    }, 100)
    return () => window.clearInterval(timer)
  }, [])

  if (!GOOGLE_CLIENT_ID) {
    return <p className="error">VITE_GOOGLE_CLIENT_ID is not set, so Google sign-in cannot be shown.</p>
  }
  return (
    <>
      <div ref={container} />
      {failed && <p className="error">Google sign-in did not load. Check your connection or ad blocker, then reload.</p>}
    </>
  )
}
