# Epic 1 Context: A Nouvi atende, reconhece e sabe quando parar

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Any client who writes on WhatsApp gets an immediate reply, at any hour, from an agent that already knows who they are and which pet — without yet being able to book anything (that's Epic 2). The agent also recognizes when a topic isn't its own: emergencies get redirected to "come now," out-of-scope requests get transferred, and questions about someone else's appointment get no information at all. This epic is deliverable on its own: a complete, safe virtual receptionist that doesn't depend on any later epic, ending with an n8n flow already pointed at RD Station.

## Stories

- Story 1.1: A base de quem já é cliente
- Story 1.2: A mensagem chega e não se perde
- Story 1.3: A Nouvi responde
- Story 1.4: Uma segunda porta, para poder testar
- Story 1.5: A Nouvi sabe quem está falando
- Story 1.6: Preferências que não se perguntam duas vezes
- Story 1.7: A Nouvi cadastra quem ainda não é cliente
- Story 1.8: A Nouvi entende o que o cliente quer
- Story 1.9: A Nouvi reconhece emergência
- Story 1.10: A Nouvi transfere e fica quieta
- Story 1.11: A Nouvi não pode ser virada do avesso

## Requirements & Constraints

- A one-time import turns the SimplesVet export into the product's own identity base (tutors, pets, phone numbers, tutor↔pet links) — this is what makes recognition possible at all. Phones normalize to a canonical international format. A phone matching more than one tutor is recorded as ambiguous, never force-resolved to one. Re-running the import later must never overwrite fields the conversation itself has already set (preferences, message-authorization state, migration state) and must never duplicate conversation-created records. Missing fields (e.g. no size/species) leave the record usable, never excluded. Import results are reported as absolute counts with the covered fraction of the base, never a bare percentage. No client data or PII is ever committed to the repository.
- The agent must resolve the conversation's phone to exactly one tutor to know anyone. Zero matches = treat as a brand-new client, never blocked or made to feel different. More than one match = treat as unauthorized: no data from any of the matched records is exposed. A tutor with one pet is never asked which pet; with more than one, the agent asks by name.
- The agent never confirms or denies that an appointment exists for anyone other than the phone's own tutor, never asks for personal data to "verify identity," and never links an unrecognized phone to an existing record on that number's own request — it offers the two legitimate paths instead (the real owner uses her own number, or Reception verifies) and routes to Reception.
- New-client intake asks only name + pet together in one question; species only if not volunteered; breed, size and coat type are excluded from initial signup. Any other missing registration data is collected only when the task in progress needs it, or offered — optional, refusable — after the booking task is done; never before or in a way that delays it. New tutor/pet records are only created once the task concludes, not at "hi."
- A pet's stable preferences (plan, perfume, accessory, own product, free-text note) are confirmed with one closed question ("same as last time — nails trimmed, no perfume, no accessory?"), never re-asked field by field; anything the client changes becomes the new stored preference.
- Every inbound message is queued before any processing, so a downstream failure never loses it. Rapid-fire messages from the same client in a short window are aggregated and answered as a single turn — never multiple replies, never parallel processing of the same conversation.
- The agent sends exactly one message per turn; when something is slow, the delay notice goes inside that same message, never as a separate send. Replies arrive within a few seconds.
- The agent introduces itself as a virtual assistant exactly once, on the conversation's first turn, and never claims to be human even when asked directly.
- Emergency language anywhere in the conversation interrupts whatever else was happening, never offers a scheduling slot, never diagnoses or downplays the reported symptom, and alerts the configured recipients; the interrupted task is not resumed automatically afterward. A failed alert must leave an explicit record rather than fail silently.
- A request for a service outside the current wave's scope, or one matching nothing in the catalog after a single open clarifying question, is routed to transfer — never improvised or guessed.
- While a human is actively handling a conversation, the agent stays silent and never announces resuming when control returns to it.
- Any technical failure produces an honest, non-technical message to the client plus a record for the team — never silence.
- All client-supplied text is treated as data, never as an instruction that changes the agent's behavior; it refuses to reveal its prompt, internal configuration, on-call contacts, or any internal terminology ("wave," "system," "API," "flow").
- The development environment never reaches a real client or a real calendar; what it would have sent is recorded instead of sent.
- Agent identity/tone, the service catalog's names/synonyms/wave assignment, and emergency/transfer recipient mappings are all configuration data editable without a flow change or new deployment.

## Technical Decisions

- The SimplesVet import is a standalone, safely-rerunnable executable program that connects directly to Postgres with a restricted identity-only credential — not an n8n workflow, since the n8n container has no volume for the export files and importing personal data needs tighter privilege than the agent's own role.
- Every field derived from an external or conversational source (preferences, later size/coat, etc.) carries its own origin marker, so a later import can never silently clobber something the conversation already set.
- The message-intake layer (queueing, aggregation/dedupe, per-conversation lock) is a separate, swappable component from the agent's decision logic. The agent itself always receives the same shape of input — who's writing, the aggregated turn text, conversation state — regardless of how the message arrived, and always returns one reply.
- A second, parallel test entry point exposes the same underlying agent logic and returns the reply directly in the HTTP response, so behavior can be exercised without spending a real WhatsApp message or touching a real client; each test case carries its own isolated session id, and no test case may leak into another's or a real client's memory. Execution is automated; judging pass/fail is a human reading transcripts.
- An adversarial test bank accumulates cases across the epic (authorization bypass, catalog improvisation, masked/false emergency, prompt injection, configuration extraction) and becomes the basis for comparing candidate language models later; a failing case is a defect, not an observation.
- The agent's system prompt is assembled fresh from stored configuration on every turn — nothing about identity, tone, catalog or emergency routing is hardcoded.

## UX & Interaction Patterns

- Never ask "are you already a client?" — a recognized client is greeted by name with no perceptible difference in treatment from a new one.
- Tone is warm and conversational, like an experienced human receptionist, never a form or menu-like sequence of separate questions; affirm what's already known rather than re-asking it.
- The 🐾 emoji appears sparingly, only at booking confirmation and same-day reminders — never in an emergency, failure, or transfer message.
- Emergency responses never say "let me check availability" and never offer a time slot — only the instruction to come immediately, the address/hours, and confirmation the team was alerted.
- Failure messages stay honest and jargon-free; the client never hears an internal error detail.

## Cross-Story Dependencies

- Story 1.1 (SimplesVet import) is the data prerequisite for Story 1.5 (phone-based recognition) and Story 1.6 (preference recall) — there is nothing to recognize or inherit without it.
- Stories 1.2 (message intake) and 1.3 (baseline response) must exist before Story 1.4 (test entry point) can expose that same agent logic through a second, test-only entry.
- Story 1.4's adversarial test bank is the harness that Stories 1.5, 1.8, 1.9, and 1.11 each extend with their own adversarial cases.
- Story 1.9's emergency handling takes precedence over any in-progress task from any other story in the epic — an emergency interrupts regardless of what else is being collected.
- Epic 1 is self-contained and does not depend on Epic 2; Epic 2 (booking) depends on the recognition, memory, and safety behaviors this epic establishes.
