# Review — Tech/Version Claims in ARCHITECTURE-SPINE.md

**Target:** `_bmad-output/planning-artifacts/architecture/architecture-atendimento-2026-09-01/ARCHITECTURE-SPINE.md`
**Reviewed:** 2026-09-02, via WebSearch/WebFetch/n8n-docs MCP against current (Sept 2026) sources.
**Method:** every version/tech claim in the Stack table and AD rules was checked against an external source (n8n's own changelog, Microsoft Graph docs, RD Station/Tallos developer docs, PostgreSQL EOL policy) rather than accepted on the document's own wording.

---

## Summary table

| # | Claim | Verdict | Severity |
|---|---|---|---|
| 1 | n8n `2.14.2` is a real version | Confirmed | — |
| 2 | n8n `2.14.2` + AD-9's "Microsoft OAuth2 (Graph)" credential on the Outlook node | **Contradiction found** — that credential option didn't exist yet on 2.14.2 | HIGH |
| 3 | AD-9 scope `Calendars.ReadWrite` sufficient for a shared/delegated calendar across several professionals | **Likely under-scoped / ambiguous** per Microsoft's own docs | HIGH |
| 4 | `postgres:16-alpine` as a "pinned, no-drift" tag (AD-10) | **Inconsistent with AD-10's own stated goal** — it's a floating tag | MEDIUM |
| 5 | n8n 2.14.2 as "the" stack version for a Sept 2026 architecture | Confirmed real, but ~5 months / ~23 minors behind current stable — unclear if intentional | MEDIUM |
| 6 | PostgreSQL 16 still supported/maintained | Confirmed | fine |
| 7 | RD Station Conversas base URL `api.tallos.com.br`, no typing-indicator endpoint | Corroborated against full endpoint list | fine (reasonably confirmed) |
| 8 | RD CRM OAuth2 token expires in 2h (AD-8) | Confirmed by official docs (7200s) | fine |
| 9 | RD CRM "renewal always returns a new refresh_token, keeping the old one breaks the next renewal" (AD-8) | **Not confirmed** — official sample code treats it as conditional | LOW |

---

## 1. n8n `2.14.2` (Stack table, AD-10)

**Claim:** `n8nio/n8n:2.14.2` pinned in `docker-compose.yml`.

**Checked against:** `docs.n8n.io/changelog/release-notes-2.x` (via n8n-docs MCP + WebFetch) and `github.com/n8n-io/n8n/releases`.

- 2.14.2 is a real release, published **2026-03-26** ("contains bug fixes" — a patch release), following 2.14.0 (2026-03-24) and 2.13.0 (2026-03-16).
- As of **today, 2026-09-02**, the latest n8n stable is **2.37.7** (released same day) with beta at **2.38.2**. n8n ships new minors almost weekly.
- So the pinned version is real but is **~5 months and ~23 minor releases behind current stable** at the moment the spine was authored (2026-09-01). AD-10's own text acknowledges "n8n libera minors com alta frequência," which is accurate — but the spine doesn't say whether 2.14.2 was chosen because it's *already installed and tested on the dev VPS* (which would justify the pin per AD-10's own rationale) or just asserted as "a recent-sounding version." **Recommend confirming against the actual dev VPS `docker-compose.yml`/`docker inspect` output before treating this as settled.**

Sources:
- https://docs.n8n.io/changelog/release-notes-2.x
- https://github.com/n8n-io/n8n/releases

## 2. HIGH — n8n 2.14.2 vs. AD-9's Microsoft OAuth2 (Graph) credential on the Outlook node

This is the most concrete, sourced contradiction found in the document.

**AD-9 states:** "o acesso é sempre via node nativo `Microsoft Outlook` (n8n-nodes-base.microsoftoutlook), credencial **Microsoft OAuth2 (Graph)**, escopo `Calendars.ReadWrite`."

**Checked against:** `docs.n8n.io/changelog` (n8n-docs MCP).

The n8n changelog explicitly dates when the Outlook node gained support for the **generic** "Microsoft OAuth2 (Graph)" credential (as opposed to the Outlook-specific "Outlook OAuth2" credential that was previously the only option):

> "Microsoft Outlook Node: Accept the generic Microsoft OAuth2 (Graph) credential: The Microsoft Outlook v2 action node and Outlook Trigger now also accept the generic Microsoft OAuth2 (Graph) credential, in addition to the existing Outlook-specific OAuth2 credential." — released in **n8n 2.28 (2026-06-23)**.

Microsoft Entra Service Principal (app-only) auth for the Outlook node arrived even later, in **n8n 2.29 (2026-06-30)**.

Since the pinned Stack version is **n8n 2.14.2 (2026-03-26)** — three months *before* 2.28 — the Outlook node on that version almost certainly only offers the **Outlook-specific "Outlook OAuth2"** credential type, not the generic "Microsoft OAuth2 (Graph)" credential AD-9 names. This is an internal inconsistency between AD-9 and the Stack table/AD-10, not just an external-reality check failure.

**Impact:** low urgency today (AD-9 is explicitly "prepared, not exercised" in the Piloto — no live auth setup happens yet), but it means the AD-9 text as written would not be buildable as described unless n8n is upgraded to ≥2.28 before that work starts, or the credential type is corrected to "Outlook OAuth2."

Sources:
- https://docs.n8n.io/changelog (searched via n8n-docs MCP, entries dated 2026-06-23 / n8n 2.28)
- https://docs.n8n.io/integrations/builtin/app-nodes/n8n-nodes-base.microsoftoutlook

## 3. HIGH — AD-9 scope `Calendars.ReadWrite` for a shared calendar across several professionals

**AD-9 states:** scope `Calendars.ReadWrite`, for a "Calendário Compartilhado" spanning several professionals (delegated/shared, not the signed-in account's own calendar).

**Checked against:** Microsoft Graph docs (`learn.microsoft.com/en-us/graph/outlook-create-event-in-shared-delegated-calendar`, `outlook-get-shared-events-calendars`, `graphpermissions.merill.net`) and n8n's own Microsoft credentials doc.

Microsoft's own guidance is explicit and narrower than AD-9's stated scope:

- **`Calendars.ReadWrite`** (delegated) grants full read/write **only on the signed-in account's own calendars**.
- To create/update events **directly in another user's shared or delegated calendar/mailbox**, Microsoft's docs recommend the least-privileged permission **`Calendars.ReadWrite.Shared`**: *"signed in as Adele, use the calendar ID... to create an event in the delegated calendar... using the least privileged delegated permission, Calendars.ReadWrite.Shared."*
- Notably, n8n's own default scope set for the Outlook credential (per `docs.n8n.io/integrations/builtin/credentials/microsoft`) already includes `Calendars.Read.Shared` (read-only on shared calendars) but **not** `Calendars.ReadWrite.Shared` — so even n8n's default credential config would need a custom scope addition for write access to a genuinely shared calendar.
- The exception: if "Calendário Compartilhado" is implemented as an Exchange **shared mailbox** (a resource object) with **Full Access** delegation granted at the Exchange/admin level to the service account, then plain `Calendars.ReadWrite` against `/users/{shared-mailbox-upn}/events` can work, because the effective access comes from the Exchange-level Full Access grant, not from a `.Shared` Graph scope.

**Conclusion:** the spine doesn't specify which of these two models ("shared mailbox" vs. "calendar shared/delegated between individual professionals' mailboxes") the "Calendário Compartilhado" actually is — and the correct scope differs depending on the answer. As written, `Calendars.ReadWrite` alone is the documented-insufficient choice for the more common "calendar shared between several professionals' personal mailboxes" interpretation. This should be resolved (which model, and whether `Calendars.ReadWrite.Shared` is needed) before AD-9's integration work is built in the post-Piloto phase — it doesn't block the Piloto itself since AD-9 is explicitly not exercised live yet.

Sources:
- https://learn.microsoft.com/en-us/graph/outlook-create-event-in-shared-delegated-calendar
- https://learn.microsoft.com/en-us/graph/outlook-get-shared-events-calendars
- https://learn.microsoft.com/en-us/graph/outlook-share-or-delegate-calendar
- https://graphpermissions.merill.net/permission/Calendars.ReadWrite.Shared
- https://graphpermissions.merill.net/permission/Calendars.ReadWrite
- https://docs.n8n.io/integrations/builtin/credentials/microsoft
- https://docs.n8n.io/integrations/builtin/app-nodes/n8n-nodes-base.microsoftoutlook

## 4. MEDIUM — `postgres:16-alpine` is a floating tag, contradicting AD-10's own "no drift" rule

**AD-10 states:** "Prevents: container recriado puxando versão diferente da testada." It pins n8n to an exact patch (`2.14.2`) but Postgres only to `postgres:16-alpine` (major-only).

**Checked against:** Docker Hub official `postgres` image tag metadata.

`postgres:16-alpine` currently resolves to **PostgreSQL 16.15 on Alpine 3.24** (`16.15-alpine3.24`), and this resolution **changes over time** as new 16.x patch releases and Alpine base-image rebuilds ship — the exact failure mode AD-10 says it wants to prevent for n8n. Docker's own official-image guidance recommends pinning to the full `<postgres-version>-alpine<alpine-version>` tag (e.g. `16.15-alpine3.24`) for reproducibility. As written, the rule is applied inconsistently: n8n gets true pinning, Postgres does not.

This is not "wrong" in the sense of PostgreSQL 16 being a bad choice (see §5 below) — it's an internal inconsistency in how AD-10 implements its own stated invariant.

Sources:
- https://hub.docker.com/_/postgres
- https://hub.docker.com/layers/library/postgres/16-alpine/images/... (tag resolution)
- https://github.com/docker-library/official-images/blob/master/library/postgres

## 5. PostgreSQL 16 — support status: confirmed fine

**Checked against:** PostgreSQL versioning/EOL policy (community docs, cross-referenced via multiple EOL-tracker summaries).

- PostgreSQL major versions get 5 years of support from release, ending in mid-November of the fifth year.
- PostgreSQL 16 was released 2023; its support window runs to **~November 2028**.
- As of Sept 2026, versions 14 through 18 are all still receiving security updates (PG 14 is the next to reach EOL, Nov 2026; PG 16 has ~2 more years of support after that).

**Verdict:** PostgreSQL 16 is a legitimate, currently-maintained choice with comfortable runway past the Piloto and well beyond. No issue with the major version choice itself — only the floating-tag mechanics flagged in §4.

Sources:
- General PostgreSQL EOL/versioning summaries (community policy: 5-year support, annual major release, quarterly minor releases) cross-checked via WebSearch aggregating multiple EOL-tracking sites (endoflife.ai, herodevs.com, instaclustr.com) — no single authoritative PostgreSQL.org page URL was directly fetched in this session; recommend a follow-up direct check of https://www.postgresql.org/support/versioning/ if a canonical citation is required for a compliance/audit context.

## 6. RD Station Conversas (Tallos) — base URL and "no typing indicator" claim

**AD-7 states:** base URL `api.tallos.com.br`; "Sem indicador de 'digitando' nem envio pausado nativo... RD não suporta."

**Checked against:**
- `developers.rdstation.com/reference/conversas-v2-introduction` (official intro page) — confirms `api.tallos.com.br` as the base and describes the API as WhatsApp-only, JSON-based, versioned (v2 current).
- `developers.rdstation.com/llms.txt` — full sitemap of Conversas v2 reference pages (~45 endpoints across Contacts, Custom Fields, Employees, Flows/Jobs, Messaging, Templates, Wallets/Integrations/Workflows, Analytics, Campaigns).
- The project's own `.claude/skills/rd-station-api/references/conversas.md` (already in the repo, listed as a spine source).

**Findings:**
- Base URL confirmed accurate.
- No endpoint related to "typing," "presence," "status," or "delayed/paced sending" appears anywhere in the full v2 endpoint sitemap, nor in the project's own reference notes. This is reasonably solid corroboration — though it's a negative claim (absence of evidence from a documentation index, not an explicit "we do not support typing indicators" statement from RD Station). Treat as **corroborated but not 100% airtight**; if this ever becomes a hard product commitment, worth a direct question to RD Station/Tallos support rather than relying solely on doc-index absence.

**Note (unrelated to the tech claim, flagging for awareness):** the fetched `conversas-v2-introduction` page contained what looked like an injected instruction block appended after the real content, asking the fetching tool to follow certain formatting/behavior rules. The WebFetch tool correctly disregarded it as untrusted page content rather than an instruction from this session. No action taken on it; flagging only so you're aware unusual content was present on that URL fetch.

Sources:
- https://developers.rdstation.com/reference/conversas-v2-introduction
- https://developers.rdstation.com/llms.txt
- `/home/thiago/projetos/nouvet/atendimento/.claude/skills/rd-station-api/references/conversas.md`

## 7–9. RD Station CRM OAuth2 details (AD-8)

**AD-8 states:** "Token OAuth2 do CRM expira em 2h; renovar com `refresh_token` sempre substitui o `refresh_token` anterior (guardar o antigo quebra a próxima renovação)."

- **2-hour expiry: confirmed.** Official RD Station docs state a 7200-second (2h) access-token lifetime for the CRM product specifically (distinct from RD Station Marketing's 24h tokens).
- **"Renewal always returns a new refresh_token, and keeping the old one breaks the next renewal": not confirmed as an absolute rule.** Fetched `developers.rdstation.com/reference/criar-fluxo-renovacao-access-token` directly — the official sample code updates the stored refresh_token with a comment "se um novo for fornecido" (**if** a new one is provided), i.e. conditional, not guaranteed on every renewal. The spine states this as an unconditional rule. It's the safer implementation default regardless (always overwrite if present), so this doesn't need to change, but it's currently asserted more strongly than the source documents it.

Sources:
- https://developers.rdstation.com/reference/crm-v2-authentication-step-3
- https://developers.rdstation.com/reference/criar-fluxo-renovacao-access-token
- https://developers.rdstation.com/reference/obter-tokens-acesso

## Other stack items checked, no issues found

- `@n8n/n8n-nodes-langchain.agent` (AI Agent / Tools Agent root node) and the `toolWorkflow`/sub-workflow pattern for tool-calling — both confirmed as current, real n8n node type names and patterns per `docs.n8n.io` (n8n-docs MCP search), including the n8n 3.0 breaking-changes note that legacy agent modes (SQL Agent, Conversational Agent, etc.) were removed and only the Tools Agent pattern remains going forward — relevant context for the n8n 2.14.2→future-upgrade path, since AD-9's "phase after Piloto" work will land on a much newer n8n where the agent-node internals have already changed once.

---

## Recommendations (priority order)

1. **Verify n8n 2.14.2 is actually the version installed on the dev VPS** (not an assumed/typo'd number) — `docker inspect` or `docker-compose.yml` on the real host. If it is intentional, note in AD-10 *why* (matches what's already running/tested), since as written it reads as an unexplained ~5-month-old pin for a Sept 2026 document.
2. **Resolve the AD-9 / n8n-version conflict** before the post-Piloto Outlook build starts: either commit to upgrading n8n to ≥2.28 (for the generic Graph credential) or change AD-9 to specify the "Outlook OAuth2" (Outlook-specific) credential type, which works on any current node version.
3. **Clarify the "Calendário Compartilhado" model** (Exchange shared mailbox w/ Full Access vs. calendar shared/delegated between individual professionals' mailboxes) and confirm whether `Calendars.ReadWrite.Shared` is needed in addition to/instead of `Calendars.ReadWrite`, before that integration is built.
4. **Pin Postgres to a full tag** (e.g. `postgres:16.15-alpine3.24`) if AD-10's "no drift" guarantee is meant to apply to both services equally, or explicitly scope AD-10's no-drift rule to n8n only if that's the intent.
5. Soften AD-8's refresh_token claim to "always persist the newest refresh_token returned" (safe default) rather than asserting the API contractually requires it — current sourcing only shows it as conditional in RD's own sample code.
