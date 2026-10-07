"""Public web pages both app stores link to: the privacy policy, the terms
of use, and how to delete an account without the app. Plain HTML from the
backend, so they live at the same address as the API and need no sign-in.
"""

from __future__ import annotations

from fastapi import APIRouter
from fastapi.responses import HTMLResponse

router = APIRouter(tags=["legal"])

CONTACT_EMAIL = "birhanu.gudisa.tolosa@gmail.com"
UPDATED = "7 October 2026"

_STYLE = """
:root { color-scheme: light dark; --fg: #1f1b16; --muted: #6b6259; --bg: #fffaf3; --link: #8a4b14; }
@media (prefers-color-scheme: dark) {
  :root { --fg: #f1ebe3; --muted: #b5aa9d; --bg: #1a1714; --link: #f0a868; }
}
body { margin: 0; background: var(--bg); color: var(--fg);
  font: 17px/1.6 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; }
main { max-width: 42rem; margin: 0 auto; padding: 2.5rem 1rem 4rem; }
h1 { font-size: 1.9rem; line-height: 1.2; margin: 0 0 .25rem; }
h2 { font-size: 1.2rem; margin: 2rem 0 .5rem; }
.updated { color: var(--muted); margin: 0 0 2rem; }
a { color: var(--link); }
nav { margin-top: 3rem; color: var(--muted); font-size: .95rem; }
"""


def _page(title: str, body: str) -> HTMLResponse:
    return HTMLResponse(
        f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title} · Buna</title>
<style>{_STYLE}</style>
</head>
<body><main>
<h1>{title}</h1>
<p class="updated">Buna · last updated {UPDATED}</p>
{body}
<nav><a href="/privacy">Privacy policy</a> · <a href="/terms">Terms of use</a> ·
<a href="/delete-account">Delete your account</a></nav>
</main></body>
</html>"""
    )


_MAIL = f'<a href="mailto:{CONTACT_EMAIL}">{CONTACT_EMAIL}</a>'

_PRIVACY = f"""
<p>Buna is an app for learning Amharic and Afaan Oromo. This page explains
what Buna stores about you, why, and how to remove it.</p>

<h2>What we store</h2>
<ul>
<li><b>Your sign-in.</b> When you sign in with Google or Apple we receive an
account identifier, your email address and, from Google, your first name.
We never see your password.</li>
<li><b>Your learning.</b> The course you chose, your daily goal, the lessons
and practice sessions you finish, your answers' results for each word, your
streak, beans and Amole balance, and your app settings.</li>
<li><b>Leagues.</b> Your weekly score and your first name, which other
learners in your league can see. You can turn leagues off in Settings.</li>
<li><b>Feedback you send.</b> Your message, your rating, the course you were
using and your phone type (Android or iPhone).</li>
</ul>
<p>Lessons, audio and the daily reminder are kept on your phone so the app
works offline. Buna shows no ads and uses no advertising or tracking tools.</p>

<h2>Why we store it</h2>
<p>Only to run Buna: to sign you in, keep your progress across phones, run
leagues, and answer your feedback. We do not sell your data or share it
with anyone for advertising.</p>

<h2>Where it is stored</h2>
<p>Buna's server runs on Vercel and its database on Neon, both in the
cloud. Sign-in is handled by Google or Apple under their own privacy
policies. These providers process data only to run their services for Buna.</p>

<h2>Deleting your data</h2>
<p>In the app, open Settings and choose <b>Delete account</b>. Your account
and everything listed above is removed at once and cannot be restored.
Without the app, see <a href="/delete-account">Delete your account</a>.</p>

<h2>Children</h2>
<p>Buna is not meant for children under 13, and we do not knowingly collect
data from them. If you believe a child has an account, write to us and we
will delete it.</p>

<h2>Changes</h2>
<p>If this policy changes, the new version appears on this page with a new
date.</p>

<h2>Contact</h2>
<p>Questions or requests: {_MAIL}.</p>
"""

_TERMS = f"""
<p>By using Buna you agree to these terms. If you do not agree, please do
not use the app.</p>

<h2>Using Buna</h2>
<p>Buna is free to use for learning languages. You need a Google or Apple
account to sign in, and you are responsible for keeping that account
secure.</p>

<h2>Fair use</h2>
<p>Do not misuse Buna: no attempts to break or overload the service, no
cheating leagues with automated tools, and no abusive or unlawful content
in feedback. We may suspend an account that does.</p>

<h2>Our content</h2>
<p>The lessons, audio, pictures and design of Buna belong to Buna and its
contributors. You may use them for your own learning, not copy or resell
them.</p>

<h2>No guarantee</h2>
<p>We work hard to keep Buna accurate and running, but it is provided as it
is, without warranties. We are not liable for losses from using it, as far
as the law allows.</p>

<h2>Ending</h2>
<p>You can stop using Buna and delete your account at any time (see
<a href="/delete-account">Delete your account</a>). We may change or end the
service, and will update these terms on this page if they change.</p>

<h2>Contact</h2>
<p>{_MAIL}</p>
"""

_DELETE = f"""
<p>You can delete your Buna account and all of its data at any time.</p>

<h2>In the app</h2>
<ol>
<li>Open Buna and go to <b>Settings</b>.</li>
<li>Choose <b>Delete account</b> and confirm.</li>
</ol>
<p>This removes your account at once.</p>

<h2>Without the app</h2>
<p>Email {_MAIL} from the address you sign in with, with the subject
“Delete my Buna account”. We delete the account within 7 days and reply
when it is done.</p>

<h2>What is deleted</h2>
<p>Your sign-in details, email and name, your course and settings, all
lesson and practice history, your streak, beans and Amole, your league
places, and the feedback you sent. Nothing is kept afterwards, and it
cannot be restored. Signing in again starts a new, empty account.</p>
"""


@router.get("/privacy", response_class=HTMLResponse, include_in_schema=False)
async def privacy_policy() -> HTMLResponse:
    return _page("Privacy policy", _PRIVACY)


@router.get("/terms", response_class=HTMLResponse, include_in_schema=False)
async def terms_of_use() -> HTMLResponse:
    return _page("Terms of use", _TERMS)


@router.get("/delete-account", response_class=HTMLResponse, include_in_schema=False)
async def delete_account_page() -> HTMLResponse:
    return _page("Delete your account", _DELETE)
