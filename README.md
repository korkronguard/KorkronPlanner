# Kor'kron Planner

The in-game companion to the Kor'kron Guard talent planner: https://korkronguard.github.io/planner/

## What it does

- **Makes the planner match the game.** WoW: Forever keeps some numbers on its servers (like your base stats at each
  level), so the planner can only estimate them. This addon shares your character's real numbers with the Guard, and
  together they replace the estimates.
- **/kp export** shows your character's stats as a code for the planner website (the website's import box is coming
  soon).
- Coming later: load a build from the website, see which talent to take next, and (optionally) spend points
  automatically as you level.

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
| `/kp share` | Shows whether your stats are shared (`/kp share off` stops it, `/kp share on` starts it again) |
| `/kp export` | Your stats as a code for the planner website |
| `/kp errors` | Shows any errors the addon ran into (`/kp errors clear` empties the list) |

Made for WoW: Forever by Grimscar of the Kor'kron Guard.
