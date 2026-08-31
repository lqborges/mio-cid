# Telemetry

Opt-in. Default **off**.

Transport is first-party HTTPS POST to `https://telemetry.mio-cid.example/v1/chapter`, or **none**. If that URL is not hosted by ship, telemetry is compiled out. No third-party SDK.

Body: beat timings and meter histograms. **No Steam ID, hardware ID, filesystem paths, or other PII.**

`SaveService` never phones home (including on a failed HMAC). Crash dumps stay in `user://logs/` unless the player opts in.
