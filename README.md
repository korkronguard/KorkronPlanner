# Kor'kron Planner

The in-game companion to the Kor'kron Guard talent planner: https://korkronguard.github.io/planner/

## What it does

- **Follow a build while you level.** Type **/kp** and pick one of the planner's suggested builds for your class, or
  paste the link to your own build from the planner website (its **Copy link** button). The window shows the talent to
  take next, the points after it with their levels, and any points you've spent outside the build. Hover a point to see
  the talent's tooltip and why the planner picked it; hover the build's name for what the build is about. When you
  level up and have a point to spend, a line in chat names the next talent.
- **Brings your real stats into the planner.** Type **/kp export**, copy the code, and paste it into the planner's
  "Import from the addon" box (under base stats): your base stats, race and level fill in.
- **Makes the planner match the game.** WoW: Forever keeps some numbers on its servers (like your base stats at each
  level), so the planner can only estimate them. This addon shares your character's real numbers with the Guard, and
  together they replace the estimates.

Builds marked **\*** have a talent the planner's math can't put a number on yet; the window says which.

## What is shared

A few seconds after you log in, level up, change gear or change talents (never in combat or inside a dungeon or raid),
the addon notes your character's:

- class, race and level
- stats: strength, agility, stamina, intellect, spirit, health, mana, armor, crit, hit, dodge, parry, block, attack
  power, spell power, healing, mana regeneration and combat ratings
- the items you wear (with enchants) and your talent points
- the character's ID number, so the same character isn't counted twice

It goes to the Guild Master's addon over the guild's addon channel. **Never chat, whispers or where you are.** Names
never appear on the website, only numbers combined from many characters.

Don't want to share? Type **/kp share off** (it covers every character on your account). **/kp share on** turns it back
on, and **/kp share** shows the setting.

## Commands

| Command | What it does |
|---|---|
| `/kp` | Your build: the next talent to take and the points after it |
| `/kp export` | Your stats as a code for the planner website |
| `/kp share` | Shows whether your stats are shared (`/kp share off` stops it, `/kp share on` starts it again) |
| `/kp errors` | Shows any errors the addon ran into (`/kp errors clear` empties the list) |
| `/kp help` | Lists the commands |

Made for WoW: Forever by Grimscar of the Kor'kron Guard.
