# TrackNest website

The responsive static landing page for the TrackNest Windows app. It has no build step.

## Local preview

From this directory, run:

```powershell
python -m http.server 4173 --bind 127.0.0.1
```

Open `http://127.0.0.1:4173`. A localhost address only works on this PC; visitors on other devices need the hosted website URL.

## Hosting and downloads

The website is hosted as the TrackNest Website project on Hatchable. The project starts with personal visibility, so the owner must switch it to public in the project Settings before sharing the permanent URL. The Windows trial is distributed as a GitHub Release asset; the landing page links to that release download.

## Email sign-in

The sign-in dialog uses Supabase email one-time codes. Its public project URL and publishable/anon key live in `auth-config.js`. Do not place a service-role key in the website. The app and website accounts do not sync local media files.

## Settings

Settings stores dark mode, reduced motion, and the glowing pointer preference in the visitor's browser.
