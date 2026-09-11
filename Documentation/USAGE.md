# Usage accounting

Token totals and limit percentages answer different questions. This guide describes the local token history shown in **Settings → Usage**. For setup, see the [README](../README.md).

```text
Codex session JSONL
  → contained source discovery
  → bounded incremental reader
  → cumulative snapshot normalization
  → local normalized event cache
  → the notch and the Settings ▸ Usage pane
```

Codex token-count events are cumulative snapshots. CodexMeter derives component-wise increases and ignores repeated snapshots. The local total uses the inclusive input count plus output:

```text
Total = Input + Output
```

`Cached Input` is the portion of `Input` that Codex served from cache rather than processing from scratch. Because it is already included in `Input`, CodexMeter shows it as a separate auditable breakdown but does not add it to Total a second time. The derived local Total therefore matches the raw Codex `total_tokens` meaning: `Input + Output`.

When optional profile sync is enabled, lifetime comes directly from the account-wide profile statistic and the dated day/week/month values are derived from its daily buckets. They are never combined with the local component breakdown.

## Data sources

CodexMeter reads JSONL files only inside:

- `~/.codex/sessions`
- `~/.codex/archived_sessions`

Optional profile sync also reads only `tokens.access_token` and `tokens.account_id` from `~/.codex/auth.json` for a fixed read-only request to `https://chatgpt.com/backend-api/wham/profiles/me`. Credentials and the response are held only in memory and are not written to CodexMeter's database or logs. This is a non-public ChatGPT endpoint and may change.

The macOS **Limits** view uses the signed Codex app-server's read-only `account/rateLimits/read` RPC. The last successful limit response is held in memory only. This provider never changes accounts, consumes reset credits, or makes purchases. The separate **Accounts** feature changes the local Codex login only after the user confirms a switch.

Claude account discovery uses the read-only `claude auth status` command; signing in stays entirely inside Claude Code. After the user enables Claude and adds that account, CodexMeter installs a small local status-line helper and records only the documented five-hour/weekly percentages and reset timestamps. Claude credentials remain owned by Claude Code. Any prior user status-line command is preserved and restored when the integration is disabled or disconnected.

For local analytics, CodexMeter stores canonical model IDs, a keyed HMAC of each normalized working directory, the final project-folder name, hashed session relationships, and numeric image counts. Image counts describe the whole retained session after the local-history cutoff, rather than only the selected chart range. It does not store full working-directory paths, session text, image bytes, MIME payloads, or attachment contents.

## Accuracy and limitations

- **Local History** means the oldest token record still present in local Codex session history through now.
- Optional **Lifetime** profile totals are account-wide and can include older, cloud, or other-device activity that is absent from this Mac.
- Profile statistics can lag behind real time; CodexMeter shows the server's exact `stats_as_of` date instead of presenting delayed data as current.
- Deleted logs cannot be reconstructed in **This Mac** or **Local History** totals.
- Activity from another computer is absent from local totals unless its session history exists locally; optional account totals can include it.
- A future Codex session-schema change may require a CodexMeter update.
- Ambiguous counter baselines and malformed records are excluded rather than guessed.
- API-equivalent cost uses the bundled current pricing snapshot and is marked unavailable for unknown models or incomplete pricing metadata. It is not an OpenAI bill.
- Project names are folder basenames and can be identical; their stored identities remain separate keyed hashes.
