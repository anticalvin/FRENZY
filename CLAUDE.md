# vzn

A social app for artists and photographers. Black or white, liquid glass, minimal. The signature is the **drum feed** (vertical, tilted, overlapping cards) and a deeply customizable **profile**.

Live: https://anticalvin.github.io/FRENZY/ (GitHub Pages, project site, so the base path is `/FRENZY/`).
Backend: Supabase project `cjtcuiouulnqcxjfhncs` (`https://cjtcuiouulnqcxjfhncs.supabase.co`).
Plan and priorities: see the "vzn: plan for Claude Code" doc. Work in its build order.

## Stack and constraints

- Static site, **no build step**. Plain HTML, CSS and ES modules (`<script type="module">`). GitHub Pages serves it as-is.
- The app is currently one `index.html`. First job is splitting it into modules: `config`, `api` (Supabase), `auth`, `gestures`, `sheet`, `drum`, `explore`, `profile`, `viewer`, `publish`, `haptics`, `brand`. Keep behavior identical while splitting, then change things.
- Use relative paths only (the site lives under `/FRENZY/`).
- Supabase JS loads from jsDelivr, pinned to an exact version. Pin every CDN script, and choose versions at least two weeks old.
- p5 sketches run in `<iframe sandbox="allow-scripts">` with `srcdoc`, p5 from cdnjs. Never give sketches `allow-same-origin`.
- Only the **publishable (anon) key** goes in client code. Never put a `service_role` key anywhere in the repo.

## Design rules

- Solid black or solid white backgrounds. Light and dark are both first class. **No neon**, no gradients as decoration.
- Liquid glass: frosted blur, bright top edge, soft inner glow. Every surface that floats uses the shared `.glass` style.
- One grotesque type family by default. Users can switch to editorial or mono on their profile.
- Minimal copy. Sentence case. Buttons say what they do ("Publish", "Save"), and errors say what went wrong and how to fix it.
- Respect safe areas (`env(safe-area-inset-*)`), `prefers-reduced-motion`, and visible focus rings.
- Minimum tap target **44px**.

## Motion and feel

- Motion is spring-based and interruptible. Answer the finger: if the user grabs something mid-animation, it follows the finger.
- Haptics go through one `hap()` function (vibrate on Android, a hidden `input[switch]` click on iOS Safari). Call it on taps, snaps, threshold crossings, likes, and success or failure. The user can turn it off in Edit profile.
- Gestures: one shared system. Any sheet or post dismisses by dragging down from anywhere when its scroll is at the top, locking to vertical after about 8px. It must not break text selection, textareas, horizontal carousels, p5 iframes, or the drum.

## Components: rules that must hold

- **Tab bar:** the active indicator is a two-edge spring (leading edge fast, trailing edge slow) that stretches and squashes. It is **clamped inside the bar** and must never overshoot the ends. It can be dragged.
- **Sheets:** every sheet (publish, edit profile, sign-in, viewer, sketch editor) grows out of the dock and collapses back into it. The dock and the sheet are one visual object. Measure the final size, then animate width, height and radius from the dock's rect. Handle the keyboard with `visualViewport`.
- **Drum feed:**
  - Card positions come from cumulative layout using each card's actual height.
  - **Overlap is the look.** Spacing is `(scaledHeightA + scaledHeightB) * 0.3`. Do not add gaps.
  - Posts snap to the preset ratios 9:16, 3:4, 4:5, 1:1, 4:3, 16:9.
  - The side labels use `mix-blend-mode: difference` against the drum's own background so they read in both themes.
  - The drum is touch-action `pan-x` on the feed and `pan-y` when embedded in the profile.
- **Explore:** JS masonry with real aspect ratios, using lightweight "still" media only (first frame, first carousel slide, p5 placeholder). Only rebuild the layout when the filter, search, column count, or data changes. No `backdrop-filter` on grid items.
- **Viewer:** fit media into the space that is left using `dvh` and `object-fit: contain`, never raw `vh`. Every ratio from 9:16 to 16:9, plus carousels and p5, must fit without leaving the screen.
- **Media types:** `image`, `video`, `p5`, `note`. A post has one or more items. More than one item makes a carousel (swipe on touch, arrows on desktop).

## Data (Supabase)

- Schema lives in `supabase/migrations/`. The initial schema is already applied. It covers `profiles`, `posts`, `post_items`, `likes`, `saves`, `comments`, `follows`, and a public `media` storage bucket where each user can only write inside their own `<uid>/` folder.
- RLS is on for every table. New tables need policies in the same migration.
- A trigger creates a profile row on signup. The client has a fallback insert if it is missing.
- Profile customization (layout, theme, section order) is stored in `profiles.settings` JSON. Images go to storage, not into the JSON.
- **Verified creator badge:** `profiles.verified` (default false). Only the project owner flips it, in the Supabase Table Editor. A trigger must reject any client update that changes `verified`.
- Guest mode (no key, or cloud unreachable) falls back to local storage (IndexedDB plus localStorage) with demo posts. Signed-in users must never inherit the demo persona or demo posts.

## Auth rules

- Sign in must be reachable from the profile, from every gated action, and from first run. It must never disappear because the cloud connection failed. Show why instead.
- Flows: email and password, magic link, forgot password, resend confirmation, new-password after recovery, and a welcome step for handle and name.
- Allowed redirect URLs in Supabase must include `https://anticalvin.github.io/FRENZY/**`. Email confirmation links depend on it.
- Supabase's built-in email sender is rate limited. Use custom SMTP before launch.

## Testing and definition of done

- Use Playwright with mobile device emulation (iPhone and a small Android) plus desktop. Take screenshots of every screen in both themes.
- Required checks before calling something done:
  - The viewer at each of the six preset ratios plus a very tall and a very wide image.
  - The drum with mixed ratios, checking for gaps and for anything leaving the screen.
  - Every sheet opening from the dock and closing by drag-down.
  - The tab indicator staying inside the bar at both ends.
  - Sign up, sign in, resend, reset, and sign out against a test project.
- Verify in a mobile viewport before moving to the next step. Do not report a UI change as working from code alone.

## Don'ts

- No frameworks or build tooling unless asked.
- No new visual styles: reuse `.glass`, the spring easing, and the type scale.
- No bullets-and-cards sprawl on the profile. It should feel designed, not templated.
- No secrets in the repo.
