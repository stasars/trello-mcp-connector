---
name: trello-update
description: Move a Trello card to the list that matches a task status (backlog/todo/in_progress/blocked/review/qa/done/production_critical). Uses the `trello` MCP connector's cached status→list mapping.
---

# /trello-update — move a Trello card by status

You drive this skill when the user asks to update a Trello card's status, move
a task to QA/Done/Backlog, mark a bug as production-critical, or any phrasing
that means "change which Trello list a card lives in based on its workflow
state."

## When this skill is right

- "Move card X to QA"
- "This is done — close it on Trello"
- "Mark <card> as production critical"
- "Send the task to the backlog"
- "Update the Trello card status to in progress"

If the user just wants to read a card or list cards, use the matching
`trello` MCP tool directly without this skill.

## What you have access to

The `trello` MCP connector provides:

- `move_card_by_status` — the workhorse for this skill. Takes `{ cardId, status, refresh? }`. Reads (or auto-warms) the cached `.trello-list-mapping.json` and PUTs the card to the correct list.
- `cache_board_lists` — rebuild the cache. Call this when the user renames lists, adds a new list, or `move_card_by_status` reports an unmapped status.
- `list_cards` — find candidate cards by listing.
- `get_card` — fetch a card by id or shortLink to confirm before moving.
- `project_config` — see which board the connector is currently scoped to.
- `auth_status` — verify the connector is authenticated.

The 8 valid statuses are:

| Status                | When to use                                       |
| --------------------- | ------------------------------------------------- |
| `backlog`             | Planned but not committed.                        |
| `todo`                | Committed, ready to pull.                         |
| `in_progress`         | Active work.                                      |
| `blocked`             | Waiting on an external dependency.                |
| `review`              | PR open, awaiting review.                         |
| `qa`                  | In QA / staging.                                  |
| `done`                | Shipped to production.                            |
| `production_critical` | Live production incident requiring urgent action. |

## Procedure

1. **Confirm auth.** If you're unsure, call `auth_status`. If `authenticated` is `false`, tell the user to run `auth_login` and stop.

2. **Identify the card.**
   - If the user gave a card id, shortLink, or Trello URL, extract the id.
   - If they named a card by title, call `list_cards` for the project's default list (or the list the user mentions) and disambiguate with the user before continuing. Don't guess across multiple matches.

3. **Identify the target status.**
   - If the user said "done" / "QA" / "backlog" / etc., map to the closest of the 8 statuses above.
   - If unclear, ask the user. Offer the 8 options.

4. **Move the card.** Call `move_card_by_status` with `{ cardId, status }`.

5. **Handle the response.**
   - On success, summarise: card name → new list name. One sentence.
   - If the result is an error saying the status is unmapped on this board, the board's list names don't match the status. Read the error: it tells the user the common list names for that status. Offer to call `cache_board_lists` after they rename a list, OR fall back to `list_lists` and ask the user to pick an explicit target list — then use `update_card` with that `idList` directly.

6. **Verify (optional).** If the user wants confirmation, call `get_card` and show the `idList` matches the expected list.

## Things NOT to do

- Don't invent a status not in the eight above.
- Don't move multiple cards in one shot without explicit per-card confirmation when the user said "this card" (singular).
- Don't bypass the cache by calling `update_card` with a hand-picked `idList` unless `move_card_by_status` reports the status is unmapped — the cache is what keeps the workflow stable when list names change.
- Don't write to the cache file by hand. The MCP tools own that file.

## Examples

**User:** "Mark the auth refactor card as done"
**You:** Find the card via `list_cards` on the in-progress list → confirm the title with the user → call `move_card_by_status({ cardId: "...", status: "done" })` → report "Moved 'Auth refactor' to Done."

**User:** "This is a production incident — move it to critical"
**You:** Identify the card → `move_card_by_status({ cardId: "...", status: "production_critical" })` → if unmapped, surface the error and the suggested list names ("Production", "Hotfix", "Critical", "Incident"), offer to refresh the cache after the user renames a list.

**User:** "Send card 6451f… back to the backlog"
**You:** `move_card_by_status({ cardId: "6451f...", status: "backlog" })` → confirm.
