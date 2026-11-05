# Changelog

## 0.13.1

- **Real numbers from the Guard's own characters** (thank you for sharing your stats):
  - Mana regen from Spirit is WoW: Forever's own: **Spirit ÷ 4 every second**, for every class (the guild's Priest,
    Druid and Paladin all show exactly this). At level 60 that's more than the old estimate, so Mage, Hunter and
    Enhancement Shaman builds and gear picks shift a little.
  - Warriors: crit and dodge from Agility follow a real Warrior, level by level (about 4.4 Agility per 1% at level 2
    and 6.5 at level 16), and **dodge from Agility now counts**, so Agility is worth more to Warriors and the leveling
    builds rest less.
  - Warrior and Priest base stats follow real characters level by level.
- **Formulas tab:** Warriors get a "Dodge from Agility" line, and crit shows the Agility per 1% at your level. Lines
  past the levels measured so far are marked as estimates.

## 0.13.0

- **New: a rotation helper (Warriors first).** Type **/kp helper**, or tick "Rotation helper" in the `/kp` window: a
  small bar shows what to press now (the big icon) and the next two, each with the game's own cooldown swirl. Hover an
  icon to see why it's there. It follows your suggested build at your level, shows in combat or when you target an
  enemy (Charge, Bloodrage and your shouts come up before the pull), and against elites and bosses adds your big
  cooldowns. Drag it where you like; **/kp helper lock** keeps it there. WoW: Forever hides your rage, your buff timers
  and your target's health from addons during a fight, so the helper keeps its own notes of what you cast and never
  suggests Heroic Strike: use that yourself when you have rage to spare. Other classes will follow.
- **Better Warrior priorities** (the Priority tab and the helper): attacks are ordered by how much damage each point of
  rage buys, so Fury uses Whirlwind before Bloodthirst and Arms puts Overpower and Slam ahead of Mortal Strike. In the
  Execute phase, attacks that still beat Execute stay ahead of it. Protection opens with Shield Block (it doesn't
  use the global cooldown) and adds Thunder Clap and Rend; every Warrior gets Charge and Bloodrage before the pull and
  Victory Rush while leveling.
- **The Formulas tab explains every number:** under each formula and rule, what each number is and where it comes
  from: the game's files, the original game's rules, checked against real Forever characters, Forever's patch notes,
  or the planner's estimate. Rage now shows its conversion value and the rage your own average hit gives.
- **Data straight from the game:** the planner now reads its data from the WoW: Forever game itself, with the
  server's latest changes: about 2,100 more items in the Gear tab and the upgrade tooltips.

## 0.12.0

- **Better builds:** every suggested build was compared with the popular WoW: Forever guides (Icy Veins) and checked
  with the planner's math; 38 of the 56 builds now take better talents. A few: Destruction sacrifices its Imp for +15%
  Shadow damage, Affliction takes Suppression and Agonizing Flames, Elemental keeps a longer Flame Shock up, Warriors
  take Enrage, Beast Mastery adds Careful Aim and Rapid Killing.
- **Faster leveling orders for healers and Mages:** they may start with another tree's damage talents when that levels
  faster (a Restoration Druid starts with Balance's cheaper Wrath, for example), so their 31-point talent can come
  after level 40.
- **Sharper math behind the builds:** Enrage counts while you're the one being hit (tanking, or solo), Demonic
  Sacrifice's bonus counts, a damage-over-time spell recast on its cooldown (Flame Shock) no longer counts the ticks it
  cuts off, and a Warlock who sacrifices the demon takes the hits it used to take while leveling.
- **A bigger `/kp` window:** wider tabs, bigger talent icons, the next 14 talent points instead of 10, and room for
  long build and item names.
- The Gear and Priority tabs and the upgrade tooltips follow the new builds.

## 0.11.0

- **Cleaner item tooltips:** two columns, the stat on the left and what it does for your build on the right (green when
  it goes up, red when down), a short header, and "Upgrade overall" or "Downgrade overall" when one number goes up and
  another down (more damage but less survival, say).
- **What the stats do, right on the tooltip:** under Strength, Agility, Stamina, Intellect and Spirit, a grey line says
  what those points change on your character sheet, like "+0.37% crit, +4 armor, +4 ranged attack power".
- **The Formulas tab starts with "What each stat does for you":** for each stat, every effect of one point on its own
  line with what it means ("crit chance: hits for double damage", "dodge chance: a melee hit misses you completely"),
  from the game's own numbers where it gives them and the planner's estimates otherwise (marked), and what the point is
  worth to your build. The formulas below are shorter, and "what your armor stops" is checked against the game.
- Shared stats now include what the game says your Agility and Intellect give (crit, spell crit, dodge), so the
  planner can learn the real numbers for every class and level.

## 0.10.0

- **Why an item is better:** item tooltips now list, stat by stat, what makes the difference with what you wear, and
  what each point is worth: "+81 Armor -> +31 effective HP (0.38 each)", "+2 Strength -> +0.22 DPS (0.11 each)".
  The totals show both damage (or healing) per second and effective HP; tanks see effective HP first, then damage.
- **What 1 point of each stat does for you,** in the Formulas tab: what +1 Strength, Agility, Stamina, Intellect or
  Spirit changes on your character sheet (like "+2 armor, +2 ranged attack power, +0.3% melee crit"), what it's worth
  to your build at your level, and the same worth for every other stat (attack power, crit rating, defense...).
- **Effective health** in the Formulas tab: how much damage you can take, worked out from your health, armor, dodge,
  parry and block. It's what the tooltips mean by "effective HP".

## 0.9.0

- **Upgrade or downgrade on item tooltips:** hover any item (in your bags, on your character, loot, vendors, links in
  chat) to see whether it beats what you wear for the build you follow in `/kp`, in damage or healing per second
  (tanks: effective health), with the planner's values for your level. Rings and trinkets are compared with the weaker
  of your two, a two-hander with both your hands; random bonuses like "of the Bear" count. Special effects ("Chance on
  hit", "Use:") and set bonuses aren't counted, and the tooltip says so. Choose one of the planner's builds in `/kp`
  to see it.
- **Formulas tab** in the `/kp` window: how your health, mana, attack power, crit, armor and mana regen are worked out,
  with your own numbers, and the game's number next to each one (a tick when they agree). Below them, the rules of
  combat for your class: white hits, spells, rage or energy, and what changes against a raid boss.

## 0.8.1

- Thanks to guild members' shared stats, the planner now counts mana from Intellect the way the game does (the first
  20 Intellect give 1 mana each). Casters' builds keep their talents; some take them in a slightly different order,
  and the Priority and Gear tabs are updated to match.
- Shared stats now include your race's ID, so the planner can tell the two Skyborne races apart.

## 0.8.0

- **More gear options:** click a slot in the Gear tab to see up to five items for it, the planner's best first, each
  with how close it comes to the best (like "85%"). Click one to make it your choice for that slot: the tab then shows
  it (the slot's name turns gold) and ticks it when you wear it. Your choices are kept per character, build and level
  range; pick the best one again to go back to the planner's.
- **Wowhead links:** a **Link** button on each item opens a small box with the item's page on Wowhead's WoW: Forever
  database, ready to copy (Ctrl+C) and paste into your browser. The page says where the item comes from.
- Fixed: the game's placeholder and test items ("DNT HEAD", "[TMP] ...", "Twain's Shoulder" and about 50 others) no
  longer show up anywhere, and items that add nothing the planner counts (like Insignia of the Horde, which also
  showed up twice) are no longer suggested.
- Fixed: items the planner had no icon for now show the game's icon.
- Fixed: the chosen build's name no longer runs out of its button.

## 0.7.0

- **Talents tab** in the `/kp` window: your class's three talent trees with your points, and the build's next to them.
  Gold frame: the build wants (more) points there. Green: you've taken all it wants. Red: points the build doesn't
  use. White: the build's next point. Each tree shows your points and the build's. Hover a talent for its tooltip,
  what it needs and (for many) a note on what it's good for.

## 0.6.0

- **Gear tab** in the `/kp` window: the planner's best item for each slot for your build at your level (the website's
  "Equip BiS", with the build's own kind of weapons), where it comes from (quest, drop, vendor, crafted), and a green
  tick on what you're already wearing. Hover an item to see its tooltip. It updates as you level and change gear.
- Horde gear only (the Guard is Horde). Profession items, other classes' tier sets and unconfirmed weapons are left out,
  like on the website.

## 0.5.0

- **Priority tab:** the `/kp` window now has tabs. **Priority** shows the planner website's "what to press" list for
  your build at your level: what to keep up, what to use on cooldown, your builders, finishers and cooldowns, each
  with a line on when or why. It changes as you level (every few levels), worked out for the build's own talents and
  gear by then. Following a level 60 build while you level? You see its leveling build's list until 60.
- The window is a little bigger to make room for the tabs.

## 0.4.0

- **Why each talent:** in the `/kp` window, hover a point of your build to see the talent's tooltip at that rank,
  why the planner put it there (like "+3.1 damage per second" or "needed for Mortal Strike") and, for many talents,
  a note on what it's good for. Hover the build's name to read what the build is about.

## 0.3.1

- The suggested builds now count Forever's new launch talents: Shank and its talents (Flash of Steel, Boot Knife,
  Venom), Reckless Swings, Improved Whirlwind, Lightning Overload and Lightning Mastery, and Warriors' extra rage from
  critical strikes. Only the Subtlety Rogue builds keep their **\***: Death Mark's damage can't be worked out yet.
- Fury leveling no longer takes Reckless Swings: alone, its health cost means more eating than its rage saves.

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
