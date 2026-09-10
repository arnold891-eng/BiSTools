-- BiSTools / dev / theme.lua -- the whole suite again with a WRONG accent injected
-- after the addon files load. If the red never shows through NS.T.text and the
-- BiS> prompt, some path hardcodes the purple instead of reading the palette.
--   lua5.1 dev/theme.lua
_G.__THEME_MUTATION = "ff0000"
dofile("dev/tests.lua")
