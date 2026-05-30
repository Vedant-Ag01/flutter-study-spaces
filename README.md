# 📚 Study Spaces

A collaborative study application where students can join shared Study Spaces to learn together. Built with a focus on real-time collaboration, stability, and intelligent learning algorithms.

## Tech Stack
* **Frontend:** Flutter & Dart
* **State Management:** Riverpod (`flutter_riverpod`)
* **Networking:** Supabase SDK (for WebSockets)
* **Backend:** Supabase (PostgreSQL)
* **Routing:** GoRouter

---
## Features by Development Phase

### Phase 1 — Foundation & Auth
* **Supabase Integration:** Designed and implemented the Postgres database schema.
* **Authentication:** Secure Sign Up, Login, and Logout flows via Supabase Auth.
* **Session Persistence:** Configured `GoRouter` redirects to act as an auth guard, protecting internal routes.

### Phase 2 — Spaces & User Management
* **Access Control:** Implemented strict Row Level Security (RLS) policies ensuring users only access their joined spaces.
* **Invite System:** Custom 6-character randomized invite code generation and validation.
* **Profiles:** User profile management including avatar image uploads via Supabase Storage.

### Phase 3 — Flashcards & Notes
* **Text Editing:** Integrated `flutter_quill` for robust, formatted note-taking.
* **Interactive Flashcards:** Full CRUD operations for decks and cards, featuring custom 3D matrix-transformation flip animations and swipeable study sessions.

### Phase 4 — Comments, Realtime & Polish
* **Live Collaboration:** Threaded discussion UI attached to individual decks and notes.
* **WebSockets:** Configured Supabase Realtime subscriptions for instant, live comment updates across connected devices.
* **UX Polish:** Integrated `shimmer` for skeleton loading states to mask network latency and prevent UI pop-ins.

### Phase 5 — Intelligent Learning (Mastery Mode)
* **Spaced Repetition System (SRS):** Built a custom Spaced Repetition algorithm based on the Leitner System.
* **Dynamic Scheduling:** Utilizes Postgres timestamps (`next_review_date`) and client-side Dart filtering to schedule cards for optimal retention.
---
---

## How to Run Locally
1. Clone this repository.
2. Run `flutter pub get` to install all dependencies (including `riverpod`, `shimmer`, `flutter_quill`).
3. Add your Supabase `URL` and `Anon Key` to your environment configuration.
4. Run `flutter run`.

---
## AI Usage Disclosure
I built the core architecture, UI, and logic independently

AI assistance was utilized for the following specific implementations:
* **Database Configuration:** Assisted with writing and optimizing raw SQL commands for the Supabase SQL Editor based on my database logic.
* **Spaced Repetition System (Phase 5):** Assisted in suggesting an example for the Leitner system that could be beneficial for the user .
* **Tutor:** Acted as a tutor to explain specific Dart methodologies (e.g., explaining the underlying ASCII math behind `codeUnitAt` for the invite code generator).
* **Documentation:** Assisted in formatting and structuring this `README.md` file.

