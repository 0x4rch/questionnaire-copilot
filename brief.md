# Questionnaire Copilot — Project Brief

## Overview
A self-hosted Phoenix LiveView application that helps security/compliance professionals answer vendor security questionnaires faster by maintaining a searchable library of canonical Q&A pairs and matching them against incoming questionnaires.

## Problem Statement
Security teams repeatedly answer the same questions across dozens of vendor questionnaires (RFIs, security assessments, vendor risk evaluations). Answers are scattered across old spreadsheets, Confluence, and Slack. Each new questionnaire means hours of copy-pasting and rewording. This tool creates a single source of truth and accelerates the workflow.

## Target User
- Security/compliance professionals
- GRC analysts
- Anyone who fills out vendor security questionnaires regularly

---

## Phase 1: Core Application (MVP)

### Tech Stack
- **Elixir 1.15+**
- **Phoenix 1.7+** with LiveView
- **PostgreSQL** (or SQLite for simpler setup)
- **Tailwind CSS** (included with Phoenix)

### Data Model

#### `qa_pairs` table
| Column | Type | Notes |
|--------|------|-------|
| id | uuid | Primary key |
| question | text | The canonical question |
| answer | text | Your approved answer |
| tags | array of strings | Categories: "encryption", "access-control", "incident-response", "authentication", "logging", "data-retention", etc. |
| source | string, nullable | Where this came from: "SOC2 2024", "Acme Corp RFI", etc. |
| inserted_at | timestamp | |
| updated_at | timestamp | |

#### `questionnaires` table
| Column | Type | Notes |
|--------|------|-------|
| id | uuid | Primary key |
| name | string | "Acme Corp Security Assessment Q1 2025" |
| status | enum | :in_progress, :completed |
| inserted_at | timestamp | |
| updated_at | timestamp | |

#### `questionnaire_items` table
| Column | Type | Notes |
|--------|------|-------|
| id | uuid | Primary key |
| questionnaire_id | uuid | FK to questionnaires |
| original_question | text | The question as received |
| matched_qa_pair_id | uuid, nullable | FK to qa_pairs |
| final_answer | text, nullable | The answer to submit (may be edited) |
| status | enum | :unmatched, :matched, :answered, :skipped |
| position | integer | Order in the questionnaire |
| inserted_at | timestamp | |
| updated_at | timestamp | |

### Features

#### 1. Q&A Vault (`/vault`)
- List all Q&A pairs with search and tag filtering
- Add new Q&A pair (form with question, answer, tags, source)
- Edit existing pairs inline or in modal
- Delete with confirmation
- Bulk import from CSV (question, answer, tags columns)

#### 2. Questionnaire Management (`/questionnaires`)
- List all questionnaires with status badges
- Create new questionnaire:
  - Name it
  - Paste raw questions (one per line) OR upload CSV
  - Parse into questionnaire_items
- Delete questionnaire

#### 3. Questionnaire Answering Interface (`/questionnaires/:id`)
This is the main LiveView — the core UX.

**Layout:**
- Left/main panel: Current question card
- Right panel: Suggested matches from vault (ranked by relevance)

**Per-question workflow:**
1. Display the original question prominently
2. Show top 3-5 matches from vault (fuzzy text search for Phase 1)
3. User can:
   - **Accept match** → copies answer to final_answer, marks :answered
   - **Accept & edit** → copies answer, opens inline editor, saves
   - **Skip** → marks :skipped, moves to next
   - **Answer manually** → type custom answer, optionally save to vault
4. Progress bar showing answered/total
5. Keyboard shortcuts (j/k to navigate, Enter to accept, s to skip)

**Matching algorithm (Phase 1):**
- Simple trigram similarity or `ILIKE` search
- Match on question text
- Boost matches with overlapping tags
- Show match confidence as percentage

#### 4. Export
- Download completed questionnaire as CSV (original_question, final_answer)
- Copy all to clipboard

### LiveView Structure
```
lib/
├── questionnaire_copilot/
│   ├── vault/
│   │   ├── qa_pair.ex          # Ecto schema
│   │   └── vault.ex            # Context module
│   ├── questionnaires/
│   │   ├── questionnaire.ex    # Ecto schema
│   │   ├── questionnaire_item.ex
│   │   └── questionnaires.ex   # Context module
│   └── matching/
│       └── matcher.ex          # Fuzzy matching logic
│
lib/questionnaire_copilot_web/
├── live/
│   ├── vault_live/
│   │   ├── index.ex            # List & search Q&A pairs
│   │   ├── form_component.ex   # Add/edit Q&A pair modal
│   │   └── import_component.ex # CSV import modal
│   ├── questionnaire_live/
│   │   ├── index.ex            # List questionnaires
│   │   ├── new.ex              # Create & import questions
│   │   └── show.ex             # Main answering interface
│   └── components/
│       ├── progress_bar.ex
│       ├── match_card.ex
│       └── question_card.ex
```

### UI/UX Guidelines
- Clean, minimal interface — this is a productivity tool
- Dark mode friendly (user will be grinding through questions)
- Clear visual hierarchy: current question > suggested matches > actions
- Responsive but desktop-first (this is work software)
- Toast notifications for saves/actions
- Keyboard-navigable for power users

---

## Phase 2: AI Enhancement (Future)

### Semantic Search
- Generate embeddings for all Q&A pairs (OpenAI `text-embedding-3-small` or local via Bumblebee/Nx)
- Store embeddings in pgvector column or separate vector store
- Replace fuzzy matching with cosine similarity search
- Much better matching: "Do you encrypt PII at rest?" matches "How is sensitive data protected?"

### AI Answer Drafting
- "Generate draft" button per question
- Sends to Claude API:
  - The incoming question
  - Top 3 matched Q&A pairs as context
  - System prompt: "Draft a professional answer to this security questionnaire question based on the provided context"
- User reviews, edits, accepts

### Bulk Processing
- "Auto-process all" button
- Processes unmatched questions in background (Task.async or Oban)
- LiveView shows real-time progress
- Flags low-confidence matches for manual review

### Additional Ideas
- Embeddings refresh when Q&A pairs are updated
- Suggested tags via AI
- Detect duplicate/similar questions in vault
- Analytics: most frequently matched Q&As, common gaps

---

## Getting Started

### 1. Create the project
```bash
mix phx.new questionnaire_copilot --database postgres --live
cd questionnaire_copilot
```

### 2. Setup database
```bash
mix ecto.create
```

### 3. Generate schemas
```bash
mix phx.gen.schema Vault.QAPair qa_pairs question:text answer:text tags:array:string source:string
mix phx.gen.schema Questionnaires.Questionnaire questionnaires name:string status:string
mix phx.gen.schema Questionnaires.QuestionnaireItem questionnaire_items questionnaire_id:references:questionnaires original_question:text matched_qa_pair_id:uuid final_answer:text status:string position:integer
```

### 4. Run migrations
```bash
mix ecto.migrate
```

### 5. Start building LiveViews
Start with the Vault CRUD, then questionnaire import, then the answering interface.

---

## Success Criteria
- [ ] Can add/edit/delete Q&A pairs in vault
- [ ] Can import a questionnaire from pasted text or CSV
- [ ] Can work through questions with suggested matches
- [ ] Can accept, edit, or skip answers
- [ ] Can export completed questionnaire as CSV
- [ ] Real-time updates via LiveView (no page refreshes)

---

## Notes for Claude CLI
When working on this project:
1. Prioritize working code over perfection — this is a learning project
2. Use Phoenix 1.7+ conventions (verified modules, core components)
3. Keep LiveView components focused and composable
4. Add basic Tailwind styling as you go — doesn't need to be beautiful yet
5. Write brief inline comments explaining Phoenix/Elixir patterns for learning purposes
6. Test interactively via browser as you build each feature
