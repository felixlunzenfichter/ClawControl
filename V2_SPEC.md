# V2_SPEC.md

Goal: add conversation screen as second screen while keeping logs screen.

## Screens
1. Logs Screen
2. Conversation Screen (this current chat thread)

## Required v2 behavior
1. On app start, automatically send one message: `ping hello`.
2. That message must land in this current conversation.
3. Conversation thread must receive a reply containing: `pong`.
4. V2 story/test passes only when `pong` is observed in the same conversation thread.
5. Conversation Screen must display this exact live conversation thread (same messages as here).
6. User can switch between:
   - Logs Screen
   - Conversation Screen

## Minimal data shown on Conversation Screen
- message timestamp
- sender
- message text

## Done criteria
- Auto `ping hello` is sent once on startup and appears in this chat.
- Conversation Screen on iPad shows this same conversation.
- Logs Screen still works as before.
