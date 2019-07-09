--[[
NEXA License
Copyright (c) 2019 NEXA Corporation

(In real world usage, treat this as the MIT License)

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

The license also applies selling rules on Minecraft(TM) servers:
Only NEXA Corporation representatives or contracts owners are allowed to distribute the Software,
the access is blocked to non-authorized seller. If the distribution is selling, then the money used in distribution must be in-game.
Real world money or any money used outside of the Minecraft(TM) server usage will result in the end of contract in the following 15 days after discovery of the fraud.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]--
local os = require("os")
local fs = require("filesystem")
local com = require("component")
local net = com.internet
local bin = "/usr/bin/"
local lib = "/usr/lib/"
local man = "/usr/man/"
local etc = "/usr/etc/"
local bse = "https://raw.githubusercontent.com/nexacorp/osu/master/"
local args = shell.parse(...)
function download(url, file)
  req = net.request(url)
  handle = io.open(file, "w")
  repeat
    data = req.read()
    handle:write(data)
  until data == "nil"
end
if args[1] == "setup" then
  if not fs.exists("/usr/bin/") then
    os.execute("mkdir /usr/bin/")
  end
  print("OSU Installer V1, by PrismaticYT")
  print("Downloading OSU core...")
  download(bse.."osu_core/osu.lua", bin.."osu.lua")
  print("Downloading config...")
  download(bse.."osu_core/osu_config.lua", etc.."osu_config.lua")
  print("OSU installed!")
  print("Exiting...")
  os.exit()
end
