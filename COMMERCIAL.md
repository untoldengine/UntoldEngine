# Untold Engine Commercial License

Untold Engine is open source under the **Mozilla Public License 2.0 (MPL-2.0)**,
which requires that modifications to MPL-covered engine files be made available
when those files are distributed.

If you need to **modify the engine privately** — without disclosing your changes
or contributing them back — a Commercial License is available.

## What the Commercial License grants

- Modify engine source code and keep those changes proprietary
- No obligation to open-source or contribute modifications back
- Distribute your products without source disclosure requirements
- Covers unlimited Licensee Products for the licensed studio/team
- Priority triage for confirmed engine bugs

## Who needs it

| Use case                                         | Open Source (MPL-2.0) | Commercial License |
|--------------------------------------------------|-----------------------|--------------------|
| Build games or apps with the engine              | Yes                   | Yes                |
| Modify engine files, keep changes private        | No                    | Yes                |
| Embed modified engine in a closed-source product | No                    | Yes                |
| Use engine unmodified in a commercial product    | Yes                   | Yes                |
| Priority triage for confirmed engine bugs         | No                    | Yes                |

## License tiers and support

| Tier           | Who it's for                  | Bug acknowledgement | Fix targeting        | Support channel              |
|----------------|-------------------------------|---------------------|----------------------|------------------------------|
| **Indie**      | Solo dev or 2-person team     | 48 business hours   | Next minor release   | GitHub Issues (include tier)  |
| **Studio**     | Up to 8 developers            | 24 business hours   | Next patch release   | GitHub Issues (include tier)  |
| **Enterprise** | 8+ devs / embedded products   | Custom SLA          | Negotiated           | GitHub Issues (include tier)  |

## Support scope

> **Important:** The Commercial License grants you the right to modify the
> engine privately. It does not entitle you to support for those modifications.
> Support covers the unmodified engine only. If you modify the engine and
> something breaks, that is outside support scope.

Support covers **correctness bugs** — incorrect or crashed behavior
reproducible on an unmodified version of the engine. Not every report qualifies:

| Issue type | Covered |
|---|---|
| Correctness bug (crash, wrong output on device) | Yes — priority queue |
| Performance issue (correct output, lower throughput) | Best effort — documented regressions escalated |
| Platform-specific issue (visionOS, tvOS quirks) | Partial — triaged to confirm engine vs SDK root cause |
| Large scene / stress failure | Partial — requires minimal repro attempt |
| Feature gap (desired feature not in licensed version) | No — logged as feature request |
| Issue only present after your engine modifications | No — outside support scope |

Issues caused by your own modifications to engine internals are outside support scope.

Engine bugs reported by Commercial License holders take priority over all
community (MPL-2.0) issues and feature requests.

Out-of-scope issues (e.g. debugging your custom modifications) may be
addressed as paid consulting — contact harold.serrano@untoldengine.com
to inquire. See [LICENSE-COMMERCIAL-SUPPORT](LICENSE-COMMERCIAL-SUPPORT)
for full triage and scope details.

## How to obtain a Commercial License

Contact Untold Engine Studios to discuss pricing and terms:

- **Email:** harold.serrano@untoldengine.com

Full license terms: [LICENSE-COMMERCIAL](LICENSE-COMMERCIAL)
Support policy: [LICENSE-COMMERCIAL-SUPPORT](LICENSE-COMMERCIAL-SUPPORT)
