# Metro One live train feed

1. Install Node.js if it is not already installed.
2. In PowerShell, open this folder and run `powershell -ExecutionPolicy Bypass -File .\start.ps1`.
3. Enter the OTD key into the hidden prompt. The key stays in the local server process and is not saved to a file or sent to the browser.
4. Open `http://127.0.0.1:4177` in a browser. The server requests the OTD vehicle-position feed every 30 seconds.

Alternatively, set `OTD_API_KEY` in the server's environment or in a local `.env` file and run `node server.js`.

The map only shows vehicles that the configured feed returns with coordinates. The public OTD documentation describes this endpoint under Delhi bus real-time data; this app assumes the authorized feed for this key is the Metro vehicle feed. If the feed returns buses, no positions, or an error, the app reports that result instead of inventing train locations.
