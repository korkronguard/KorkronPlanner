local _, KP = ...

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

function KP.TalentRanks(configID)
  local nodes = KP.TalentNodes(configID)
  if not nodes then return nil end
  local ranks = {}
  for _, n in ipairs(nodes) do ranks[n.id] = math.max(n.purchased, n.current, n.active) end
  return ranks
end
