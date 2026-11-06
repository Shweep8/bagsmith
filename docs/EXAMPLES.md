# BagSmith icon corner examples

Short, working shapes for `RegisterCornerWidget` (BagSmith.API 1.1). The full contract is in [API.md](API.md).

These follow the shapes addons already use; mix them as you need.

**A single badge in a corner:**
```lua
api.RegisterCornerWidget("My Addon: New", "myaddon_new",
  function(badge, details) return MyAddon:IsNew(details.itemID) end,
  function(button)
    local t = button:CreateTexture(nil, "OVERLAY")
    local s = math.floor(button:GetWidth() * 0.35)
    t:SetSize(s, s); t:SetAtlas("my-new-badge")
    return t
  end,
  { corner = "top_right", priority = 1 })
```

**Several badges in one corner** (a frame holding a column of small icons, shown when any applies):
```lua
function(button)
  local f = CreateFrame("Frame")
  f:SetSize(button:GetWidth() * 0.4, button:GetWidth() * 0.4)
  f.badges = {}   -- create your textures inside f; lay them out in onUpdate
  return f
end
```

**A ring or glow around the whole slot**, tied to your corner widget: make it in onInit, positioned on
`itemButton` (not your corner frame), as a child of your frame, so it shows and hides with it.

**List rows:** pass `{ listRows = true }` as the seventh argument and size from the slot you're given
(`slot:GetWidth()` is the row's icon size), so the same code works in both views.

**Combat:** onInit isn't called in combat (BagSmith waits). If your own data changes during combat, call
`RequestItemButtonsRefresh()` once it ends.
