# Shopping Order Plan

## Goal
Order the **To‑Buy** list by inferred shopping path based on historical purchase order, with a manual shop selector.

## Session Definition
- **Session gap:** 2 hours. Purchases separated by more than 2 hours start a new session.
- Session ordering uses item timestamps in that window to infer sequence.

## Ordering Strategy
1. Build sessions from purchase history (items marked bought).
2. For each session, record the relative order of categories as they appear.
3. Compute a **rolling average** of category order positions over the **last 5 sessions**.
4. Sort **To‑Buy** categories by that average position (lower = earlier in list).
5. Within a category, sort items by recency or alphabetical (to be decided later).

## Multi‑Shop Support
- Provide a **manual shop switcher** in the Shopping list screen.
- Each shop stores its own session history and ordering scores.
- Default shop is “Main”.

## Scope
- Applies **only** to the **To‑Buy** section.
- Bought items remain in a flat list (no category grouping).

## Data Needed
- `boughtAt` timestamps per item
- category key per item
- optional `shopId` (string) for multi‑shop separation

## Next Steps
- Add storage for shop definitions
- Track `shopId` on shopping items
- Add settings UI for shop management
- Implement scoring + ordering in Shopping list view
