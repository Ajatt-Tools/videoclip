require('tests.setup')

local h = require('helpers')
local cfg_mgr = require('config.config')
local eutils = require('encoder.utils')
local mpv_encoder = require('encoder.mpv')
local ffmpeg_encoder = require('encoder.ffmpeg')
local encoder = require('encoder.encoder')

print("Running helpers tests...")
h.run_tests()
print("helpers tests passed.")

print("Running config tests...")
cfg_mgr.run_tests()
print("config tests passed.")

print("Running encoder utility tests...")
eutils.run_tests()
print("encoder utility tests passed.")

print("Running mpv encoder tests...")
mpv_encoder.run_tests()
print("mpv encoder tests passed.")

print("Running ffmpeg encoder tests...")
ffmpeg_encoder.run_tests()
print("ffmpeg encoder tests passed.")

print("Running encoder facade tests...")
encoder.run_tests()
print("encoder facade tests passed.")

print("ALL TESTS PASSED")
