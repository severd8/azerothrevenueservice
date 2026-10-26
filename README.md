# ARS Forever

**See how much gold a player has made and the most they've ever held, for you and anyone you inspect.**

ARS Forever (Azeroth Revenue Service) is a gold statistics addon for **World of Warcraft: Forever**. It reads the statistics the game already keeps: for yourself, the gold you've ever picked up, the most you've ever held and what's in your bags; for other players, the same figures the game shares when you inspect them. Every look is saved on your computer, so you can come back and see how someone's numbers have changed.

It's an updated rebuild of *Forever IRS* (Ironforge Revenue Service), with the shared Forever look, an options window, a minimap button and a few fixes.

---

## Features

- **The big numbers.** Total gold acquired, most gold ever owned, and (for your own characters) the gold in your bags right now.
- **Where it came from.** Gold looted, quest rewards, vendor sales and auction earnings; spending on travel, postage, barbers and respecs; auctions posted, won, the largest sale and bid.
- **Activity and professions.** Quests, kills, dungeons, deaths, disenchants, fish, flight paths, honorable kills, and every profession's highest rank.
- **Opens beside the Inspect window.** Inspect a player and the ledger opens next to it and reads their statistics. There's also an **ARS** button under the Inspect window. Both can be turned off.
- **History.** The last 20 captures of every character, with how much their gold acquired went up between captures.
- **Characters list.** Every saved character, searchable by name, realm, guild or class, and sortable by peak gold, gold acquired, level, name, when you last saw them, or how many captures there are.
- **Copy report.** The whole capture as plain text you can copy.
- **Brings in your Forever IRS history** (see below).

## Installation

1. Install with the CurseForge app, or download the latest release.
2. If you downloaded it, unzip it into your WoW: Forever `Interface\AddOns` folder so you end up with an `AddOns\ARSForever\` folder.
3. Restart the game, or type `/reload` if it's already running.

### Coming from Forever IRS

Your saved Forever IRS history comes along. The game only loads an addon's saved data while that addon is turned on, so:

1. Keep **Forever IRS** turned on together with ARS Forever and log in once. ARS brings the history in by itself and says so in chat.
2. Turn Forever IRS off in the AddOns list.

You can bring it in again any time from the options (**Saved data** tab); nothing is lost or doubled.

## Using it

- **Your own ledger:** type `/ars me`, or click **My character** in the ledger.
- **Another player:** inspect them, or target them and type `/ars`. They need to be close enough to inspect.
- **Saved characters:** the **Characters** tab, or `/ars history`. Click a row to open that capture.
- **Move the ledger:** drag its red header. It always opens beside the Inspect window when it opens from there.
- **Hover anything** for what it means, where it came from, or why it's missing.

### The ledger window

| Tab | What's there |
|---|---|
| **Ledger** | The three big numbers, a count of the activity recorded, peak minus acquired, and the income, spending, auction, gameplay and profession figures |
| **Activity** | Every activity counter and all twelve professions |
| **History** | The saved captures of this character, newest first, with the increase in gold acquired |
| **Characters** | Every saved character, with search and sorting |

### Options window

Type `/ars options`, click **Options** in the ledger, or right-click the minimap button. Every setting has hover help and applies at once.

| Tab | What's there |
|---|---|
| **General** | Open beside the Inspect window, the ARS button on the Inspect window, the ledger's size, move it back to the middle, the minimap button, the welcome screen after updates, Restore defaults |
| **Saved data** | How many characters and captures are saved, open the list, delete saved history, bring in Forever IRS's history, and the two checks below |

### Slash commands

| Command | Does |
|---|---|
| `/ars` | Your target's ledger if it's a player, otherwise yours |
| `/ars me` | Your own ledger |
| `/ars target` | Your target's ledger |
| `/ars history` (or `/ars list`) | The saved characters |
| `/ars refresh` | Read the player shown again |
| `/ars auto on` · `/ars auto off` | Open beside the Inspect window, or not |
| `/ars options` | The options window |
| `/ars status` | Versions, whether the game's statistics functions are there, and what's happening |
| `/ars check` | Every statistic the addon reads, by ID, with the game's own name for it |
| `/ars scale 0.6`–`1.6` · `/ars scale reset` | The ledger's size |
| `/ars reset` | Put the ledger back in the middle (history is kept) |
| `/ars news` | The welcome / what's new window |
| `/ars import` | Bring in Forever IRS's history |
| `/ars close` | Close the ledger |

`/arsforever` works too.

## Good to know

- **Gold acquired is not profit, and peak gold is not what someone has now.** Gold acquired counts everything that came in. Peak gold is a past high.
- **A difference does not necessarily indicate wrongdoing.** The income breakdown doesn't list gifts, gold from alts or friends, or player trades (normal item sales, selling ports or summons, and so on). These numbers are **not proof of innocence or wrongdoing.**
- **Missing is not zero.** A grey `--` means the game didn't report a value. Hover it: *not reported* (the game returned nothing) or *unavailable* (it couldn't be read).
- **The numbers come straight from the game** and may be incomplete or out of date. Counter resets and game updates can change them.
- **Other players' gold in their bags** isn't shared by the game, so it's only shown for your own characters.
- **Profession ranks marked `*`** are the highest ever recorded; that profession may have been unlearned since.
- **Private.** No data leaves your computer: no addon messages, no chat posts, no background scanning. ARS only asks the game for a player's statistics when you click, type a command, or inspect them with **Open beside the Inspect window** on. One request at a time, at least 5 seconds apart, and it gives up after 15 seconds without sending again by itself.
- **Saved data** (`ARSForeverDB`) holds your settings and the captures: each character's name, realm, class, level, guild, the time, the game build and the statistics; your own gold only for your own characters. To erase it, use **Delete saved history** in the options.

## Troubleshooting

- **"This player can't be inspected right now"**: move closer to them and click **Refresh**.
- **"The game is hiding who this player is here"**: the game hides player details from addons in some places, often inside instances. Try again outside.
- **"Another addon took over the request"**: another addon (or the game's achievement comparison) asked for someone's statistics at the same time. Click **Refresh**.
- **A number shows `--`**: hover it to see why. Type `/ars check` to list every statistic and whether the game knows it.
- **The ledger is off-screen**: type `/ars reset`.

## Feedback and bug reports

Found a bug or have an idea? Please [submit it on GitHub](https://github.com/severd8/azerothrevenueservice/issues/new/choose). A short form asks what you were looking at and for any error message, so issues can be fixed quickly. You'll need a free GitHub account. Otherwise, feel free to leave a comment on the CurseForge page.

## Support the addon

ARS Forever is free. If it helps you, you can [leave a small tip on Ko-fi](https://ko-fi.com/tauntmasterforever). Thank you!

## All addons by me

- **TauntMaster Forever**: one-click taunts off your healers and DPS, for tanks.
- **ToppedOff Forever**: reminds you when buffs, food, reagents, ammo or gear need topping off.
- **Outfitter Forever**: save your gear as outfits and switch between them with one click, or let them change by themselves.
- **BattleText Forever**: scrolling combat text for your hits, heals and the damage you take.
- **AuctionHouse Forever**: a bigger Auction House window, so long item names stop getting cut off.
- **GatherPath Forever**: the shortest gathering route through your GatherMate2 herb and ore nodes, on the world map and minimap.
- **ARS Forever** (Azeroth Revenue Service): see how much gold a player has made and the most they've ever held, for you and anyone you inspect.

## Credits

Based on **Forever IRS** by wowplayer95 (MIT license); not affiliated. Its statistic list, number reading and much of its logic are reused with thanks.

An independent community addon, not endorsed by Blizzard or the U.S. Internal Revenue Service.

## License

MIT, see [LICENSE](LICENSE).
