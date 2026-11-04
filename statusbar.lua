-- Publish this maki process's session states for a status bar to read.
-- One file per process, named by pid; one character per session:
--   "1" = working, "0" = idle or waiting.
-- The bar resolves pid -> workspace, so this knows nothing about sway.

local DIR = maki.fs.joinpath(maki.env.state_dir(), "statusbar")

-- braid: needs_input shares "0" with idle. Give it "2" (and add a colour in the
-- bar) when you want "waiting for me" shown apart from "asleep".
local CODE = { working = "1", needs_input = "0", idle = "0" }

local PID
local dirty = true

local function publish()
  if not PID then return end
  local out = {}
  for i, s in ipairs(maki.session.live() or {}) do out[i] = CODE[s.status] or "0" end
  maki.fs.atomic_write(maki.fs.joinpath(DIR, PID .. ".status"), table.concat(out))
end

-- Callbacks only flag; the coroutine below owns every yielding call, because
-- top-level plugin code cannot yield across the C call boundary of require().
maki.api.create_autocmd("SessionStatusChanged", { callback = function() dirty = true end })
maki.api.create_autocmd("SessionEnd", {
  callback = function()
    dirty = true
    -- Remove our heartbeat so the status dir does not accumulate one file per
    -- dead process. The bar sweeps orphans too, in case we are killed.
    if PID then
      maki.fs.rm(maki.fs.joinpath(DIR, PID .. ".status"))
    end
  end,
})

maki.async.spawn(function()
  local ok, err = maki.fs.mkdir(DIR, { parents = true })
  if not ok then maki.log.warn("statusbar: " .. tostring(err)) end

  -- our own pid is the parent of this shell
  maki.fn.jobstart("echo $PPID", {
    on_stdout = function(_, line)
      PID = line:match("%d+")
      dirty = true
    end,
  })

  local tick = 0
  while true do
    if PID and (dirty or tick % 3 == 0) then
      publish()
      dirty = false
    end
    tick = tick + 1
    maki.async.sleep(1000)     -- prompt on change, heartbeat every 3 s
  end
end)
