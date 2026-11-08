-- Kor'kron Planner: your talent points as the game reports them. Forever's talents are "traits": one tree per class
-- (Warrior 1117...) whose node IDs are the ones in Data/Talents.lua.
local _, KP = ...

-- Every node of your active talent tree: { { id, purchased, current, active }, ... } and the config ID, or nil when
-- the game can't tell (no talent config yet, or values hidden inside an instance: guessing 0 there would look like
-- unspent points). Forever doesn't always fill all three rank numbers (ForeverAuras saw a partly filled talent
-- missing from one of them), so all three are kept. configID: another config to read (the game's talent window's,
-- whose points you clicked but haven't applied yet count), else your active one.
function KP.TalentNodes(configID)
  configID = configID or C_ClassTalents.GetActiveConfigID()
  if not (KP.Readable(configID) and type(configID) == "number") then return nil end
  local info = C_Traits.GetConfigInfo(configID)
  local treeID = info and info.treeIDs and info.treeIDs[1]
  if not (KP.Readable(treeID) and type(treeID) == "number") then return nil end
  local nodes = {}
  for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID)) do
    local node = C_Traits.GetNodeInfo(configID, nodeID)
    local purchased, current, active = node.ranksPurchased, node.currentRank, node.activeRank
    if not (KP.Readable(purchased) and KP.Readable(current) and KP.Readable(active)) then return nil end
    table.insert(nodes, { id = nodeID, purchased = tonumber(purchased) or 0, current = tonumber(current) or 0,
      active = tonumber(active) or 0 })
  end
  return nodes, configID
end

-- Points in each talent: { [nodeID] = rank } (the highest of the three numbers), or nil like KP.TalentNodes
function KP.TalentRanks(configID)
  local nodes = KP.TalentNodes(configID)
  if not nodes then return nil end
  local ranks = {}
  for _, n in ipairs(nodes) do ranks[n.id] = math.max(n.purchased, n.current, n.active) end
  return ranks
end
