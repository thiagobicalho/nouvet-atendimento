# Review — ARCHITECTURE-SPINE.md (rubric walk)

**Verdict:** The spine is mostly sound and enforceable — its 10 ADs are largely concrete, ratify the PRD and the `n8n-agent-patterns`/`rd-station-api` reference material without contradiction, and correctly closed the AD-4/AD-9 "no real booking in the Piloto" gap during reconciliation — but it silently drops one PRD-mandated architecture decision (Fontes Confiáveis/knowledge-base shape, FR-30/31, PRD Q7), defers the timer/escalation trigger mechanism for a must-ship, primary-metric feature without even a directional default, and leaves the operational envelope (backup/DR, monitoring) completely unaddressed.

---

## Critical

### 1. FR-30/FR-31 (Fontes Confiáveis / knowledge-base architecture) is unaddressed anywhere in the spine, despite the PRD explicitly delegating this decision to architecture

- **Location:** Capability → Architecture Map, row "4.9 Guardrails de IA"; also missing from Deferred and from the AD list.
- **Problem:** PRD §4.9 Notes for FR-30 say verbatim: *"A arquitetura da base de conhecimento (RAG, documentos, banco estruturado) ainda não está definida — decisão técnica a resolver na arquitetura (ver Questão em Aberto #7)."* This is a direct, named request for the architecture layer to close Questão em Aberto #7. The spine's 4.9 row only cites AD-1 (sinais de alerta configuráveis, which is FR-8, not FR-30) and AD-2 (never reveal credentials/config, which is FR-40). FR-30 ("toda resposta factual se baseia em Fontes Confiáveis") and FR-31 (reconhecimento de incerteza) get no AD, no Deferred entry, no Open Question carry-forward — they simply vanish between PRD and spine.
- **Why it matters:** This is exactly the kind of real divergence point the spine exists to fix. Without a stated answer, one plausible (wrong) build path is to paste institutional/service knowledge straight into the agent's `systemMessage` — which would directly contradict AD-1's own prevents-clause (the `clinica/` anti-pattern the spine itself warns against). Another plausible path is to over-build an unplanned RAG pipeline mid-Piloto, burning days from a 10-day budget. Either way, the ambiguity is load-bearing.
- **Fix:** Either (a) add an explicit AD (or extend AD-1) stating that for Piloto scope, "Fontes Confiáveis" = the same `secretaria_config` data already read every turn (i.e., FR-30 is resolved by AD-1, no RAG needed), and update the 4.9 map row to cite it — or (b) if that's genuinely not yet decided, move PRD Q7 explicitly into the spine's Deferred/Open Questions list instead of letting it disappear silently.

---

## High

### 2. Follow-up/escalation trigger mechanism (FR-25–29, feeds primary metric SM-3) is Deferred with no directional lean, despite being in-scope and structurally consequential

- **Location:** Deferred, item "Gatilho de lembretes/follow-up automático"; Capability → Architecture Map row "4.8 Temporizadores, Continuidade e SLA" ("gatilho de disparo em Deferred").
- **Problem:** FR-25–29 (renew due date, client-inactivity reminder, human-delay auto-update, progressive manager escalation) are explicitly **in scope for the Piloto** (§6.1 of the PRD) and are what SM-3 ("Zero leads perdidos silenciosamente") measures. The spine defers the trigger *shape* itself — "cron fixo varrendo `lembretes_horas`/`follow_ups_horas` vs. disparo por mudança de etapa no funil RD CRM. Não fechado." — with zero lean, unlike the dev→prod cutover Deferred item, which at least states a "direção provável." Cron-poll and CRM-webhook-trigger are not implementation nuances; they are two different workflow topologies (a `scheduleTrigger`-driven independent agent, per the `11 - Lembretes Agendamento.json` reference pattern, vs. an event-driven flow reacting to CRM stage changes, per the `clinica/08` reference pattern) with different schema needs on `n8n_status_atendimento`.
- **Why it matters:** Deferring this without a default risks FR-26 (Aguardando Cliente) and FR-28/29 (Aguardando Atendimento Humano) being built against two different mechanisms, or the build team guessing wrong and reworking mid-Piloto on a feature that a primary success metric depends on.
- **Fix:** State a default direction now (the reference material already leans cron/state-column, given `n8n_status_atendimento` is explicitly scoped in the Structural Seed table as holding "estado de follow-up") even if it stays flagged as revisable, and note the schema implication either way.

### 3. Operational envelope: no backup/DR policy and no system-health monitoring/alerting anywhere in the spine

- **Location:** Whole document — no AD, Structural Seed entry, or Deferred item addresses this. Closest adjacent content is AD-2's own line: *"perda de volume = credenciais irrecuperáveis"* — which names the failure mode but proposes no backup mitigation, only a fixed encryption key.
- **Problem:** The spine decides deployment topology (two VPS, Docker, pinned versions) but is silent on: backup cadence/retention for the two Postgres databases (including the identity table, which the memlog itself flags as having become a *permanent* PII store, not a temporary export); backup of n8n workflows/credentials beyond the eventual dev→prod export; and any monitoring/alerting for system-level failures (distinct from the product-level SLA/escalation feature in §4.8, which only covers conversational delay, not n8n/Postgres downtime or workflow execution errors).
- **Why it matters:** This is a whole structural dimension at this altitude — the operational/environmental envelope — left completely silent, exactly the kind of omission the rubric flags as especially significant. A 10-day pilot with no stated backup policy for a now-permanent PII database, sitting on infrastructure whose own architecture doc flags catastrophic, irrecoverable data loss as a known risk, is a real gap, not a nice-to-have.
- **Fix:** Add a short AD or Structural Seed entry stating backup cadence/retention for both Postgres databases and for n8n workflow/credential exports, plus a baseline statement of who monitors uptime/errors and how (even "Btech checks manually daily during the Piloto" is better than silence) — or explicitly move it to Deferred with a stated risk acceptance for the 10-day window.

---

## Medium

### 4. Indicator computation/serving mechanism (FR-36–39, §4.11) is not decided or deferred

- **Location:** Capability → Architecture Map, row "4.11 Indicadores e Visibilidade Gerencial" (cites only AD-8, "etapas do funil RD CRM").
- **Problem:** FR-37 (atendidos/não atendidos) is well-defined via RD Station's existing esteira states, but FR-36 (leads recebidos), FR-38 (distribuição por setor), and especially FR-39 (tempo de resposta, which needs a first-response timestamp, not a funnel stage) need a data source and computation path that "etapas do funil" alone doesn't obviously provide. Nothing in the spine says whether this is a live query against RD CRM's API, a query against the Postgres queue/history tables, or a manual export.
- **Fix:** Name the intended source/mechanism for the 5 indicators (even a one-line note in Structural Seed), or explicitly note it's low-risk/deferrable because indicators are read-only reporting with no build-order dependency.

### 5. AD-2's encryption-key sizing claim carries an internal arithmetic inconsistency from the memlog

- **Location:** AD-2 Rule: *"`N8N_ENCRYPTION_KEY` fixa via variável de ambiente (mín. 32 chars hex)."* Source in `.memlog.md` line 9: *"minimo 32 chars hex/256-bit."*
- **Problem:** 32 hexadecimal characters encode 128 bits, not 256 bits (256-bit would require 64 hex characters). The spine dropped the "256-bit" gloss but kept "32 chars hex" — worth confirming against actual n8n documentation requirements (a separate reviewer is covering version/tech currency, but this specific arithmetic mismatch is worth flagging explicitly for that pass, since it suggests the "256-bit" framing in the source material was itself wrong, not just dropped).
- **Fix:** Verify against `docs.n8n.io/hosting/configuration/configuration-examples/encryption-key` what the actual minimum/recommended length is, and state it without the bit-count claim if it's not actually tied to one.

---

## Low

### 6. Inconsistent `[ADOPTED]` status tagging across ADs

- **Location:** AD-1 through AD-5, AD-7, AD-10 carry `[ADOPTED]`; AD-6, AD-8, AD-9 do not, despite reading as equally settled decisions (all reference specific `[DECISÃO ...]` or confirmed-with-Thiago content in the memlog).
- **Fix:** Tag consistently, or state explicitly what the absence of a tag is meant to signal (e.g., "still provisional" vs. simply an oversight).

### 7. Capability Map cross-reference placement: AD-1's "sinais de alerta configuráveis" citation sits under 4.9, not 4.2

- **Location:** Capability → Architecture Map, rows "4.2 Triagem e Direcionamento" (cites only AD-4) and "4.9 Guardrails de IA" (cites AD-1 for "sinais de alerta configuráveis").
- **Problem:** The configurable alert-signal list is FR-8, which lives in §4.2 (Triagem), not §4.9. A reader scanning the 4.2 row alone would miss that AD-1 (config-as-data) governs FR-8 too.
- **Fix:** Cite AD-1 under the 4.2 row as well (or move the citation there instead of 4.9).

### 8. NFR-1–NFR-5 are claimed as `binds` in front-matter but have no explicit row/anchor in the Capability → Architecture Map

- **Location:** Front-matter `binds: [..., 'NFR-1–NFR-5']`; Capability → Architecture Map only enumerates PRD §4 Features 4.1–4.12.
- **Problem:** NFR-3 (immutable/append-only history) and NFR-4 (resiliência de dados via pipeline único) have no stated architectural anchor — they're presumably satisfied implicitly by relying on RD CRM's native card/history behavior via AD-6/AD-8, but this is never said.
- **Fix:** Add a short explicit line (doesn't need a full table) connecting each NFR to the AD(s) that satisfy it, so the "binds" claim is actually traceable.

---

## What's working well (not a finding, for calibration)

- AD-4/AD-9's "no real booking in the Piloto, only preference-collection + human confirmation" correction is properly reconciled against the addendum's 01/set/2026 decision, and consistently threaded through the dependency diagram, the Capability Map (4.3/4.4), and Deferred — this was flagged in the memlog as a real gap found during reconciliation and it reads as fully fixed now.
- AD-6, AD-7, AD-8 correctly ratify the `rd-station-api` skill's gotchas verbatim (two tenants/two credentials, phone-format normalization, OAuth2 2h expiry + refresh-token rotation, Conversas being form-urlencoded and lacking a typing indicator) — no contradiction found.
- AD-1/AD-2/AD-3 correctly ratify the `n8n-agent-patterns` skill's proven pattern (config-in-Postgres read every turn, credentials only in the native vault, `secretariav3-completo/` as the pattern to follow vs. `clinica/` as the named anti-pattern) and explicitly avoid that skill's own flagged mistake (mixing secrets like `url_asaas`/`telefone_twilio` into the config table).
- FR-41's "alert to all involved professionals, array-based" is correctly traced to the `05.1 - Escalar Humano Multi.json` precedent in both AD-4 and the Capability Map (4.12).
