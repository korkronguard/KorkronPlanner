# Changelog

## 0.3.0

- **Follow a build in game:** `/kp` opens a window where you pick one of the planner's suggested builds for your class
  or paste a link to your own build from the planner website. It shows the next talent to take, the points after it
  with their levels, and any points spent outside the build.
- When you level up with a point to spend, a line in chat names the build's next talent.
- The builds and talent trees are Forever's launch ones (4 November). Warrior Arms and Fury, every Rogue build and
  Elemental Shaman are marked provisional (**\***) until the planner's math knows the new talents.
- `/kp export`'s code can now be pasted into the planner website ("Import from the addon", under base stats).
- `/kp` used to list the commands; that's `/kp help` now.

## 0.2.0

- First release.
- Shares your character's real stats with the Kor'kron Guard so the planner website's numbers match WoW: Forever:
  class, race, level, stats, gear and talent points, noted a few seconds after you log in, level up or change gear
  or talents. Never chat, whispers or where you are; names never appear on the website. `/kp share off` stops it.
- `/kp export` shows your stats as a code for the planner website (the website's import box is coming soon).
- Stats the game hides from addons (it can inside dungeons and raids) are left blank instead of causing errors.
- `/kp errors` lists each problem once, with how often it happened; `/kp errors clear` empties the list.
