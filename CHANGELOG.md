# Changelog

## 0.21.0

- **Solo, Dungeon and PvP builds for every class.** In **/kp**, your class's builds are now grouped by spec, each with
  three paths: **Solo** (questing alone), **Dungeon** (ready for groups while you level, then dungeons and raids at 60)
  and **PvP** (world PvP while you level, battlegrounds at 60). Druids have two Feral builds on Solo and Dungeon (Cat and
  Bear).
  - **Dungeon** paths are measured in dungeon pulls at each level (the gear you'd have then, no resting counted), with
    their own Priority and Gear lists from level 10. Tanks take their threat talents as soon as they can (Paladin:
    Holy Shield, Iron Creed; Warrior: Defiance, Improved Sunder Armor; Druid: Feral Instinct, Lacerate). The Warrior's
    separate "Protection: leveling (dungeons)" build is now Protection's Dungeon path: if you followed it, you follow
    that now.
  - **PvP** builds, one per spec, for example: Paladin Retribution (Repentance, a quicker Hammer of Justice, Eye for an
    Eye), Warrior Arms (Improved Hamstring, Piercing Howl), Priest Shadow (Blackout, Silence, Silent Resolve), Rogue
    Subtlety (Preparation, Elusiveness, Improved Sprint), Mage Frost (Frostbite, Improved Frost Nova, Ice Block),
    Hunter Survival (Improved Wing Clip, Counterattack, Deterrence), Druid Feral (Brutal Impact, Feral Charge), Shaman
    Elemental (Earthbound, Eye of the Storm), Warlock Demonology (Soul Link, Fel Domination). They take the crowd
    control, stuns and utility a PvE build skips. The planner can't measure a fight against a player, so these talents
    are picked from class knowledge; Beast Mastery and Marksmanship Hunters and Elemental Shamans follow the PvP builds
    Icy Veins publishes for WoW: Forever. Each build says which. The Gear tab ranks their gear with the planner's
    questing numbers.
- **Builds checked by the planner's own math:** a new search moves points wherever the math says the build gets
  better, and 22 Solo and Dungeon builds changed. For example: Arms Solo takes Improved Slam; Frost and Fire Mages take
  Arcane Blast (on Forever its stacks add spell damage to everything you cast); the Protection Paladin takes Conviction;
  Combat Rogue Solo trades Hack and Slash for Improved Poisons; Restoration Shaman Solo takes Shamanistic Focus. Hover a
  build's name to see how many of its 51 points the math measures. The rest are picked by judgment (utility and crowd
  control the math can't put a number on yet), and the planner website names them.
- **Warriors in dungeons:** a damage-dealing Warrior's Enrage no longer counts there (the tank is the one being hit).
- **Make a build yours:**
  - Hover a point to see the talents the planner rates as good or nearly as good there.
  - "Your choice" points: a point or a few in every build can go either way (the window lists them; Warlocks can take
    a stronger Succubus for faster kills). Taking the other option counts as following the build.
  - Points you spend outside the build are your own picks, no longer marked red: the build drops its last points to
    make room, and the Talents tab shows your picks in blue.
- **Hunters and Warlocks: your pet's stats are shared too** (its kind, level, stats, health, mana, armor, attack
  power, damage, attack speed and happiness; not its name). The game's files don't say how hard pets hit on Forever, so today
  the planner counts no pet damage at all. Your pet's numbers let it value Beast Mastery and Demonology talents from
  real numbers. You'll see the sharing message once more because of this; **/kp share off** still stops all sharing.

## 0.20.1

- **Baganator: the green upgrade arrow shows now.** Choosing the Planner as Baganator's upgrade source only changed its
  searches, so Baganator users never saw an arrow. The arrow is now one of Baganator's corner icons, in the top-right
  corner by itself (move or remove it in Baganator's settings, Icons tab, "Kor'kron Planner"). Nothing to change in
  your settings.

## 0.20.0

- **Priests: the builds are right for Horde Priests now.** The planner gave every Priest Starshards, which only Night
  Elves learn, and it was about a third of a leveling Priest's damage. Spells only some races learn now count only
  for those races (Starshards and Elune's Grace for Night Elves, Desperate Prayer and Chastise for Dwarves, Touch of
  Weakness and Dark Sacrifice for Undead, Hex of Weakness and Shadowguard for Trolls...), and the Priority lists
  never suggest another race's spell. The Holy and Discipline leveling talent orders changed from the first point,
  Shadow's from level 22. Level 60 Priest builds are unchanged.
- **Leveling Priest Priority lists follow the leveling math:** Shadow Word: Pain once per mob (a mob of your level
  dies before it runs out), then Mind Blast, Shadow Word: Death and Devouring Plague on cooldown with Mind Flay to
  fill, wand when your mana is gone. Holy Fire is listed once, Inner Fire says what it does on Forever (armor), and
  Vampiric Embrace heals you too.
- **"Once per mob":** damage over time that outlasts a mob of your level now says so in every leveling list
  (Corruption and Immolate for Warlocks, Insect Swarm for Druids too).
- **Short cooldowns are ready at every pull:** while you eat and drink between mobs, Holy Strike, Judgement,
  Stormstrike, the shocks, Shank, Mind Blast and the like come back. Paladins, Enhancement Shamans and Rogues level
  faster in the planner's numbers, and 13 leveling orders changed a little.
- **Rogues:** Shank gives combo points only with Boot Knife (the game's tooltip since the Nov 6 hotfix), so Combat and
  Assassination estimates are lower.
- **More items:** about 480 more items in the gear lists and upgrade arrows, from today's game data.
- Keep WowUp's auto-update on to get new versions without checking.

## 0.19.0

- **Leveling fights now end when the mob dies.** A mob of your level lives about 8 to 22 seconds, so damage over time
  (Shadow Word: Pain, Corruption, Rend, Serpent Sting, Moonfire...) only counts the ticks that land before it dies,
  and long cooldowns (Death Wish, racials) count as coming back while you eat and drink. Leveling builds that lean on
  damage over time come out slower, and 12 leveling talent orders changed (Discipline, Shadow and Holy Priest,
  Elemental and Enhancement, Protection Warrior, Restoration and Balance Druid, all three Warlocks). Affliction keeps
  Bane of Agony while leveling: Bane of Doom's damage comes after a minute. Level 60 builds are unchanged.
- **Warriors:** Overpower, Slam, Rend and Thunder Clap are now part of the damage math. Arms does about 25% more than
  the planner thought, and the Arms, Arms leveling and both Protection leveling orders changed. Fury's Priority list
  now has Slam, with the white damage its cast costs.
- **Warlocks:** one Bane at a time, Conflagrate uses up your Immolate, Incinerate's bonus on an Immolated target, and
  Shadow and Flame's bonus only when you cast Conflagrate and Shadowburn. Affliction and Demonology estimates drop by
  about a tenth; builds and gear follow.
- **Arcane Mages:** Arcane Blast's stacks are in the math; the Priority list says how many Blasts per 18 seconds pay off.
- **Priority tab:** Shadow Priests (Mind Blast when you have mana to spare, wand when you're out), Balance Druids,
  Rogues (Slice and Dice kept up, poisons counted) and Enhancement Shamans (Searing Totem; Magma Totem and Fire Nova
  for packs) get lists that fit their talents.
- **Fixes:** Wand Specialization, Ranged Weapon Specialization and Furious Precision only count with their weapon;
  ranged attack power was counted twice; melee classes no longer get Auto Shot damage.
- **Real numbers from the guild:** Warrior and Paladin base stats are now measured up to level 22, Priests to 12
  (thanks to everyone sharing). Paladin Spirit above level 19 was a little low and is fixed.
- Keep WowUp's auto-update on to get new versions without checking.

## 0.18.0

- **Priority tab: Hunter, Mage and Warlock lists fixed.**
  - **Hunters** (Marksmanship, Beast Mastery): the shots were missing (Aimed Shot, Arcane Shot, Serpent Sting, even
    Auto Shot). They're back, in the order the planner's numbers give: at 60 your mana runs out before your
    cooldowns do, so the most damage per mana goes first. Beast Mastery: Summon Hawk before Arcane Shot, which waits
    until 2 hawks are out.
  - **Mages** get a list per spec instead of the "basic list": Fire casts Pyroblast at 3 Heating Up and keeps 5
    Improved Scorch stacks; Frost uses Ice Lance with Fingers of Frost, Cone of Cold at 5 Winter's Chill and keeps Ice
    Barrier up for its Frost damage; Arcane keeps 4 Arcane Blast stacks and uses Arcane Missiles with Missile Barrage.
  - **Warlocks** too: one Bane per target (Bane of Doom when the target lives another minute), Curse of the Elements,
    the instant Shadow Bolt from Nightfall, Soul Fire below 35% with Decimation, Searing Pain for Demonic Brand,
    Conflagrate and Shadowburn with Shadow and Flame, and which demon to sacrifice or keep out.

## 0.17.0

- **The rotation helper is gone** (`/kp helper` and its bar). WoW: Forever hides too much from addons during a fight
  for it to be right: inside dungeons it couldn't even tell which enemy you had targeted, or whether it was Undead for
  Exorcism. The **Priority** tab stays: your build's rotation at your level, for reading outside a fight. The helper's
  saved settings are cleared.

## 0.16.0

- **Upgrade arrows in your bags:** with your bags open, a green arrow in the top-right corner of a slot marks an item
  that's an upgrade for your build and that you can wear now (items for a later level get no arrow; their tooltip says
  from which level). It updates when you change gear, level up or pick another build.
- **Baganator users:** the Planner is now one of Baganator's upgrade icon choices. In Baganator's settings, choose
  "Kor'kron Planner" as the upgrade icon (if you had Pawn there, it stays Pawn until you change it).
- **Overall % on the tooltip:** the upgrade line now says how much better or worse the item is overall, e.g.
  **"Upgrade +3.2%"**: the change in your build's damage per second (healers: healing per second) compared with what
  the planner works out for your build at your level with its best gear. When an item only changes your survival, it
  says so ("+1.6% survival"). Tanks: their mix of survival (70%) and damage (30%).

## 0.15.0

- **Rotation helper for Protection Paladins and Elemental Shamans (first versions, to test):** pick a Protection or
  Elemental build in `/kp` and type **/kp helper**.
  - **Protection Paladins:** it keeps Righteous Fury, Seal of Fury, Devotion Aura and Blessing of Kings up, then
    suggests both Judgements first (they don't use the global cooldown), Holy Shield as it runs out, Hammer of the
    Righteous, Holy Strike, Exorcism against Undead and Demons, and Hammer of Wrath when the game lets you. Consecration
    (for packs) is up to you.
  - **Elemental Shamans:** Flame Shock only once its burn has run out (a new one replaces the burn still going), Chain
    Lightning, then Lightning Bolt; Lightning Mastery against elites and bosses.
  - Tell Grimscar what feels wrong.
- **Fix for Paladins:** an Aura you turned on during a fight kept being asked for until the fight ended, and before a
  fight a missing Aura filled all three icons.
- On a build the helper doesn't cover yet, it now names the builds of your class it does.

## 0.14.1

- **Rotation helper for Retribution Paladins (first version, to test):** pick a Retribution build in `/kp` and type
  **/kp helper**. It keeps your Seal, Blessing of Might and Retribution Aura up, then suggests Judgement (it doesn't
  use the global cooldown, so it shows next to your other ability), Holy Strike, Hammer of Wrath when the game lets
  you (below 20% health) and Exorcism only against Undead and Demons. Consecration (for packs) is up to you. Tell
  Grimscar what feels wrong.
- **New version alert:** when a guildmate's addon is newer than yours, a line in chat tells you, at each login until
  you update it in WowUp. (Guildmates on 0.14.0 or older will need this one update before they get the alert.) Tip: in
  WowUp, turn on auto-update for Kor'kron Planner and new versions install by themselves.
- Paladin base stats now follow a real Paladin of the Guard (levels 10-19).

## 0.14.0

- **Helping the planner, with nothing to type:** with sharing on, the addon now also checks the planner's talent and
  spell numbers against the game once per patch: your class's talent tooltips are compared right in your game (only a
  difference is sent), and the descriptions of the spells you know go to the Guard once each. It waits a minute after
  login, never runs in combat or inside instances, and **/kp share off** stops it like the rest.
- **Protection Warriors: two leveling paths.** "Protection: leveling (solo)" for questing alone, and the new
  **"Protection: leveling (dungeons)"**, ready to tank the dungeons on the way: Defiance and Improved Sunder Armor as
  soon as they open (levels 20-22 and 25-27). Pick either one in `/kp`.
- **Protection leveling reworked:** the planner now counts how a Protection Warrior really fights: Revenge (it lights
  up after you block, dodge or parry, and Shield Block makes that happen often), Shield Slam, and the rage you get from
  being hit, from blocks with Shield Specialization and from dodges and parries with Master of Defense. Improved
  Revenge now comes at 15, Master of Defense at 20-21 and Vanguard at 25.
- **All Warriors:** Charge's rage at each pull and Bloodrage count now, and each attack only counts in the stance that
  allows it (no Whirlwind in Battle Stance), so some Warrior numbers and talent orders shift. A Warrior's base parry and
  block chance count too (5% each, as on the guild's real Warrior).
- **Every class's leveling builds:** the planner no longer pictures you in level 60 quest rewards at level 12 (an item
  without a level requirement now counts from about 5 levels below its item level), so many leveling orders shift a
  little. Arcane Mages now start in the Arcane tree.
- **Formulas tab:** Effective health counts the 5% of attacks that miss you, and your block chance only while you wear
  a shield. Gear picks and upgrade tooltips for Warriors and tanks follow the new numbers.
- **Item numbers checked against the game itself** (all 8,593 wearable items): robes now have their armor, bows and
  thrown weapons their real (smaller) stats, wands their real damage, and caster staves, wands and maces the spell
  power or healing the game gives them. A few Forever items whose bonus is "tripled in Forest and Grassland areas" now
  count only the bonus you get everywhere. Caster builds and gear picks gain from their staves' spell power; Hunter
  numbers drop a little.

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
