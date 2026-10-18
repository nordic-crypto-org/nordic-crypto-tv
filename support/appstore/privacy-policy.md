# Nordic Crypto app: privacy policy

Last updated: 11 October 2026

The Nordic Crypto app for iPhone, iPad, Mac, Apple Vision Pro, Apple TV and Android is made by Jørgen S. Notland (jQrgen).

## What the app collects

The app has no account, no analytics, no advertising and no tracking. The only thing it stores outside your device is what notifications need, and only after you turn notifications on (see below).

## Notifications

When you turn on notifications for new stories (iPhone, iPad, Mac, Apple Vision Pro and Android; Apple TV has none), the app sends our push server, a Cloudflare Worker run by us:

- the push token that Apple (APNs) or Google (Firebase Cloud Messaging) gave the app on this device,
- the kind of device (iPhone, iPad, Mac, Vision Pro or Android),
- the countries you chose and the app's language.

That is all. No name, no email address, no IP address, no device name and no location are stored. The push token only lets us send this app on this device a notification; it does not identify you, and we do not use it for anything else or share it. The server uses it to send one notification per new story from the countries you chose, through Apple or Google, who deliver it to your device under their own privacy terms. On Android, Firebase also gives the app an installation id that Google uses to deliver the messages; there is no Firebase Analytics in the app.

Turning notifications off in the app deletes the token and the preferences from the server straight away. A device that has not opened the app for 180 days is deleted automatically, and so is a token that Apple or Google reports as no longer valid. If the push server cannot be reached, the app checks for new stories on the device instead, as before, and nothing is sent anywhere.

Legal basis: your consent (turning notifications on), which you can withdraw at any time by turning them off.

## What the app connects to

- **Nordic Crypto data** (`nordiccrypto.no`, `cryptonordic.no`, `jqrgen.github.io` and `raw.githubusercontent.com`): the app downloads the public news, events and newsletter files. These are ordinary web requests; we do not run code on these servers that identifies you.
- **Push server** (`nordic-crypto-app-push.nordiccrypto.workers.dev`, Cloudflare), only with notifications on: see Notifications above. Cloudflare sees the IP address of the request, as any web server does; our code does not store it and request logging is off.
- **Newsletter video** (`github.com`): the newsreel is streamed from a public GitHub release when you choose to play it.
- **Radio** (Apple TV only; Radio Norge from `live-bauerno.sharp-stream.com`, Techno Underground and Berlin Beach House Radio from FluxFM's `streams.fluxfm.de`): the selected station is played from the broadcaster's public stream while the radio is on. You can switch it off with Play/Pause on the remote.

Like any web request, these services see your IP address. Their own privacy policies apply to that.

## What stays on your device

The app keeps a copy of the latest news so it works offline, your notification settings and the ids of stories it has already seen, and on Apple TV whether you switched the radio off. These stay on your device and are removed when you delete the app.

## Links and QR codes

Stories link to the original publishers, and the newsletter links to Substack. When you open those links or scan the QR codes, you leave the app and the destination's privacy policy applies.

## Contact

Questions: open an issue at https://github.com/jQrgen/nordic-crypto/issues.
