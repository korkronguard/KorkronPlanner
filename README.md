# Kor'kron Planner

The in-game companion to the Kor'kron Guard talent planner: https://korkronguard.github.io/planner/

## What it does

- **Follow a build while you level.** Type **/kp** and pick one of the planner's suggested builds for your class, or
  paste the link to your own build from the planner website (its **Copy link** button). Builds are grouped by spec,
  each with up to three paths: **Solo** (questing alone), **Dungeon** (ready for groups while you level, then dungeons
  and raids at 60) and **PvP** (fighting players; its PvP talents are picked from class knowledge, and it says so). The
  window shows the talent to take next and the points after it with their levels. Hover a point to see the talent's
  tooltip, why the planner picked it and the talents it rates nearly as good there; hover the build's name for what
  the build is about. When you level up and have a point to spend, a line in chat names the next talent.
- **Right in the game's talent window.** Press **N**: your build is drawn on the game's own talent trees. The talent
  to take next glows gold, the other points you can spend now are numbered in order (up to 5), and each talent of the
  build shows your points and the build's in gold (a green tick once done). Talents outside the build are left as
  they are. Click whatever you like: the marks follow your clicks before you press Apply. Hover a talent for what the
  build says about it, why and what's nearly as good. Along the bottom of the window, pick your build (or **No build**
  for the plain window), see the next talent, and open **/kp** with the **Planner** button.
- **Make it yours.** Builds aren't set in stone. "Your choice" points can go either way, and any other point you spend
  outside the build is fine too: the build makes room by dropping its last points, and the window lists your own picks.
- **Your trees at a glance.** The **Talents** tab shows your three talent trees with your points and the build's:
  gold where the build wants more, green where you're done, blue for your own picks, white for the next one.
- **What to press.** The window's **Priority** tab shows the planner's rotation for your build at your level: what to
  keep up, what to use on cooldown, builders, finishers and cooldowns.
- **What to wear.** The **Gear** tab shows the planner's best item for each slot for your build at your level, where
  it comes from, and ticks what you already wear. Hover an item for its tooltip. Click a slot to see the next best
  items for it and how close each comes, and choose your own. **Link** gives the item's page on Wowhead's WoW: Forever
  database to copy into your browser, with the quest, the boss or the vendor it comes from.
- **Upgrade or downgrade, on every item.** Hover an item in your bags, on your character, in loot or at a vendor: the
  tooltip says whether it beats what you wear for your build, by how much overall (in %: of your own damage for
  Warriors, of your build's damage or healing per second at your level for the other classes), in damage or healing
  per second and effective HP, and why: what each stat that differs adds. Hover gear you're wearing to see what it
  gives you, stat by stat,
  and what those points do on your character sheet. With your bags open, a **green arrow** in the top-right corner marks
  each item that's an upgrade you can wear now. Using **Baganator**? The arrow shows there too, top right (move it in
  Baganator's settings, Icons tab, where it's called "Kor'kron Planner"). **EllesmereUI**'s bags show it too.
- **What each stat is worth to you.** The **Stats** tab has a section for each of your build's two numbers, staying
  alive (effective health) and damage or healing. Each lists the stats that count for it: how much of the stat you
  have, what 1 more point adds, and what that's worth in your main stat ("0.5 Strength"; other tools call these stat
  weights). For Warriors they're worked out from your own character sheet, talents and weapons, against the enemy you
  choose (a normal one of your level, an elite, or an elite 3 levels up), with your own effective health and damage
  on top of each section, and the tab says how many points are left before a cap, like the hit you need. Your item
  tooltips and bag arrows judge gear by the same numbers. The other classes see the planner's numbers for their build
  with its best gear at their level, until their class is added.
- **How your numbers are worked out.** The **Formulas** tab shows the formula behind your health, mana, attack power,
  crit, armor, mana regen, rage and effective health, with your own numbers and the game's next to them, and for every
  number in it what it is and where it comes from; what 1 point of each stat does for you and your build; and your
  class's rules of combat.
- **Your damage, worked out in game (Warriors so far).** The **DPS** tab shows your damage a second from your own
  character sheet, talents and weapons, in each stance you know, against a normal mob of your level, an elite of your level
  and an elite 3 levels up. Say whether you're tanking it or someone else is, and hover a number for what it's made of. Other
  classes will come one at a time.
- **Brings your real stats into the planner.** Type **/kp export**, copy the code, and paste it into the planner's
  "Import from the addon" box (under base stats): your base stats, race and level fill in.
- **Makes the planner match the game.** WoW: Forever keeps some numbers on its servers (like your base stats at each
  level), so the planner can only estimate them. This addon shares your character's real numbers with the Guard, and
  together they replace the estimates.

- **Tells you when there's a new version.** When a guildmate's addon is newer than yours, a line in chat says so, at
  each login until you update it in WowUp. Tip: in WowUp, turn on auto-update for Kor'kron Planner and new versions
  install by themselves.

Builds marked **\*** have a talent the planner's math can't put a number on yet; the window says which.

## What is shared

A few seconds after you log in, level up, change gear, change talents or call your pet (never in combat or inside a
dungeon or raid), the addon notes your character's:

- class, race and level
- stats: strength, agility, stamina, intellect, spirit, health, mana, armor, crit, hit, dodge, parry, block, attack
  power, spell power, healing, mana regeneration and combat ratings
- the items you wear (with enchants) and your talent points
- your pet or demon, if you have one out: its kind (Wolf, Voidwalker...), level, stats, health, mana, armor, attack
  power, damage, attack speed and happiness. Not its name. The game's files don't say how hard pets hit on Forever,
  so the planner learns it from yours.
- the character's ID number, so the same character isn't counted twice

A minute after you log in, it also checks the planner against the game, by itself, once per game patch:

- your class's talent tooltips, compared right in your game with the planner's: only a talent whose numbers differ is
  sent (usually none), with a note that your class was checked
- the descriptions of the spells you know, once each (and again when you learn a new rank)

It all goes to the Guild Master's addon over the guild's addon channel, a little at a time. **Never chat, whispers or
where you are.** Names never appear on the website, only numbers combined from many characters.

Your addon's version number is also exchanged with guildmates' addons, so everyone hears about updates; that one
goes out even with sharing off (it says nothing about your character).

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
