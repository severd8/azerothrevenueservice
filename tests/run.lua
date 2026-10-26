-- Runs the ARS Forever test suite outside the game.
-- From the repo root:  lua5.1 tests/run.lua
-- Exits with code 1 (and prints the error) if any test fails.

ADDON_DIR = "."
local realPrint = print
REAL_PRINT_KEEP = realPrint

local ok, err = xpcall(function() dofile("tests/run_tests.lua") end, debug.traceback)

for _, line in ipairs(RESULTS or {}) do realPrint(line) end
if not ok then
    realPrint("FAILED: " .. tostring(err))
    os.exit(1)
end
realPrint("ALL TESTS PASSED")
