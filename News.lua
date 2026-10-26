-- Short "What's new" lines for the welcome window (Splash.lua), newest first.
-- Add an entry here with every release, matching the top version in
-- CHANGELOG.md (a test fails if they don't match).

local _, ns = ...
local A = ns.ARS

A.NEWS = {
    { version = "1.0.0", date = "2026-10-26", items = {
        "First release: an updated rebuild of Forever IRS in the Forever look.",
        "Your Forever IRS history comes along: keep Forever IRS on for one login, then turn it off.",
        "Options window (/ars options), a minimap button, and /ars check to list every statistic read.",
        "Fixes: opens beside Inspect even after you've moved it, follows a second inspect, full copy report.",
    } },
}
