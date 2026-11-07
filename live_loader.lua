-- ============================
-- TDS LIVE - Loader (ไฟล์ที่กด Run ทุกจอ ทุกแอคเคานต์)
-- โหลดโค้ดรายงานสดรุ่นล่าสุดจาก repo นี้โดยตรง
-- ============================
local url = "https://raw.githubusercontent.com/SightBob/tds-auto/refs/heads/main/live_report.lua"
local ok, err = pcall(function()
	loadstring(game:HttpGet(url))()
end)
if not ok then
	warn("[TDS-LIVE] load failed: " .. tostring(err))
end
