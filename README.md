<p align="center">
  <img src="media/dans-riches-logo.webp" alt="Dan's Riches logo" width="320">
</p>

# Dan's Riches

All your gold at a glance for WoW Forever: hover your backpack to see how much gold each of your characters has.

Dan's Riches adds a **Your Riches** section to the tooltip Blizzard already shows on your backpack button,
under the usual "Backpack" and free-slots lines. You don't get a new window or a minimap button, just your
characters, their gold and a total, right where you look when you check your bags.

## Features

- **Gold in the backpack tooltip:** hover the backpack button on your bag bar to see each of your characters
  on this realm with their gold, and a **Total** line for all of them together.
- **Every character, automatically:** a character is added the first time you log in on them, and their gold
  is kept up to date while you play. Nothing to set up.
- **Choose who shows up:** the options page lists all your characters with their level and gold. Untick a
  character to keep them out of the tooltip. They stay in the list, so you can tick them again any time.
- **Your own order:** characters are listed richest first. Untick **Richest first** and use the up and down
  arrows next to each character to put them in any order you like. The tooltip follows that order.
- **Class colors:** names are colored by class, or plain white if you turn it off.
- **Alts you haven't played yet:** if you use **Syndicator** (it comes with Baganator), the characters it
  already knows show up straight away with their last known gold.

## Installation

1. Download **`DansRiches-x.y.z.zip`** from the [latest release](https://github.com/MachineDan/Dans-Riches/releases/latest)
   (not the "Source code" downloads, and not **Code → Download ZIP**).
2. Open the zip and drag the **`DansRiches`** folder inside it into your AddOns folder, for example
   `World of Warcraft\_forever_\Interface\AddOns\`. You should end up with `AddOns\DansRiches\DansRiches.toc`.
3. Restart the game.

Or install it through the CurseForge app, which does all of this for you.

## Usage

Hover the backpack button on your bag bar. That's it.

Open the options with `/riches`, or from **Esc → Options → AddOns → Dan's Riches**. Changes apply right away.

| Option | What it does |
| --- | --- |
| **Class colors** | Color names by class in the tooltip and the character list |
| **Show total** | Add a Total line with all the shown characters' gold together |
| **Richest first** | Sort characters by gold. Turn it off to order them yourself with the arrows |
| **Characters** | Tick or untick each character to show or hide them in the tooltip |
| **Defaults** | Turn every option back on and show every character again |

All options are on by default.

### Slash commands

`/riches` and `/dansriches` both work.

| Command | What it does |
| --- | --- |
| `/riches` | Open the options |
| `/riches reset` | Reset all settings and show every character again |

## Good to know

- **A character's gold is known once you've logged in on them** with Dan's Riches installed (or Syndicator,
  see above). Until then they aren't listed. If a character's gold isn't known yet, it shows as a grey **?**.
- **Gold means the gold your character is carrying**, the same amount shown at the bottom of your backpack.
  Gold waiting in the mailbox counts once you take it.
- **Forever realms:** character names in WoW Forever are unique per ruleset, and the server you land on can
  change between logins. So characters are grouped by ruleset (**PvP**, **PvE**, **RP**…) instead of by
  server name, and all your PvP characters show up together.
- **Forever names:** characters have a first name and a surname ("Healy Dan"), and the full name is always shown.
- **Both factions** of the same realm are listed together.

## Compatibility

Made for the WoW Forever (**1.60**) client. No libraries.

## License

[MIT](LICENSE)
