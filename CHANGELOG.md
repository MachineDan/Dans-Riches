# Changelog

## Unreleased

First release of **Dan's Riches**: your characters' gold in the backpack tooltip, for WoW Forever.

### Features
- **Gold in the backpack tooltip:** hover the backpack button to see each character on this realm and their gold, richest first, plus a total.
- **Choose the characters** shown in the tooltip from the options page, grouped by realm, with a **Forget** button for old characters.
- **Class colors** for names (can be turned off), and an optional **Total** line.
- **Alts you haven't logged into yet** are filled in from Syndicator (Baganator's data addon) when it's installed.
- On WoW Forever, characters are grouped by ruleset (e.g. **PvP**), not by the server you happen to be on, since that changes between logins.
- An options page in **Esc → Options → AddOns → Dan's Riches** (or `/riches`), plus `/riches reset`.

### Fixes during development
- Gold no longer saves as 0 right after logging in or while logging out: `GetMoney()` reports 0 then. Gold that was saved as 0 this way is cleared and refilled.
- The tooltip header reads **Your Riches**.
