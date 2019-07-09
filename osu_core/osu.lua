local component = require("component")
local fs = require("filesystem")
local event = require("event")
local term = require("term")
local data = component.data
local modem = component.modem
if component.isAvailable("os_rfidreader") then
  local rfid = component.os_rfidreader
end
modem.open(340)
local ok, config = pcall(dofile, "/usr/etc/osu_config.lua")
if not ok or not type(config) == "table" then
  print("Error, failed to load config because '" .. config .. "'. Exiting!")
  os.exit()
end
local args = require 'shell'.parse(...)
local function containsValue(table, element)
  for _, value in pairs(table) do
    if value == element then
      return true
    end
  end
  return false
end
function containsKey(table, element)
  for key, _ in pairs(table) do
    if key == element then
      return true
    end
  end
  return false
end
local function onReceive(_, _, _, port, _, program, module, command, password, text, args1, args2, args3)
  if port == 340 then
    if program == "OSU" then
      password = data.decrypt(password, config.modules.network.encryption.key, config.modules.network.encryption.iv)
      text = data.decrypt(text, config.modules.network.encryption.key, config.modules.network.encryption.iv)
      if password == config.modules.network.password then
        if module == "DOOR" then
          if command == "UNLOCKALL" then
            if text == config.modules.door.override then
              for addr in component.list("os_doorcontroller") do
                component.invoke(addr, "open")
              end
            else
              modem.broadcast(340, "OSU", "NETWORK", "RESPONSE", data.encrypt(config.modules.network.password, config.modules.network.encryption.key, config.modules.network.encryption.iv), "INVALID_OVERRIDE_CODE")
            end
          elseif command == "LOCKALL" then
            if text == config.modules.door.override then
              for addr in component.list("os_doorcontroller") do
                component.invoke(addr, "close")
              end
            else
              modem.broadcast(340, "OSU", "NETWORK", "RESPONSE", data.encrypt(config.modules.network.password, config.modules.network.encryption.key, config.modules.network.encryption.iv), "INVALID_OVERRIDE_CODE")
            end
          end
        elseif module == "LOCKDOWN" then
          if command == "INIT" then
            if text == config.modules.lockdown.password then
              if component.isAvailable("os_doorcontroller") then
                for addr in component.list("os_doorcontroller") do
                  component.invoke(addr, "close")
                end
              else
                modem.broadcast(340, "OSU", "NETWORK", "RESPONSE", data.encrypt(config.modules.network.password, config.modules.network.encryption.key, config.modules.network.encryption.iv), "INVALID_LOCKDOWN_CODE")
              end
              if component.isAvailable("os_alarm") then
                for addr in component.list("os_alarm") do
                  component.invoke(addr, "activate")
                end
              end
              if component.isAvailable("os_rolldoorcontroller") then
                for addr in component.list("os_rolldoorcontroller") do
                  component.invoke(addr, "close")
                end
              end
            end
          elseif command == "STOP" then
            if text == config.modules.lockdown.password then
              if component.isAvailable("os_alarm") then
                for addr in component.list("os_alarm") do
                  component.invoke(addr, "deactivate")
                end
              else
                modem.broadcast(340, "OSU", "NETWORK", "RESPONSE", data.encrypt(config.modules.network.password, config.modules.network.encryption.key, config.modules.network.encryption.iv), "INVALID_LOCKDOWN_CODE")
              end
            end
          end
        elseif module == "NETWORK" then
          if command == "REBOOT_ALL" then
            if text == config.reboot_password then
              computer.shutdown(true)
            end
          end
        end
      end
    end
  end
end
local function unlockDoor(_, _, username, data, _, _, _)
  if data == config.modules.door.card then
    if not containsValue(config.modules.door.blacklist, username) then
      for addr in component.list("os_doorcontroller") do
        component.invoke(addr, "open")
      end
    else
      modem.broadcast(430, "OSU", "DOOR", "UNLOCK", data.encrypt(config.modules.network.password, config.modules.network.encryption.key, config.modules.network.encryption.iv), "Blacklisted user " .. username .. " tried to open the door attached to this computer, with correct card data!!")
      return
    end
  else
    if containsValue(config.modules.door.blacklist, username) then
      modem.broadcast(430, "OSU", "DOOR", "UNLOCK", data.encrypt(config.modules.network.password, config.modules.network.encryption.key, config.modules.network.encryption.iv), "Blacklisted user " .. username .. " tried to open the door attached to this computer, with incorrect card data " .. data .. "!")
      return
    else
      if containsValue(config.modules.door.whitelist, username) then
        for addr in component.list("os_doorcontroller") do
          component.invoke(addr, "open")
        end
      else
        modem.broadcast(430, "OSU", "DOOR", "UNLOCK", data.encrypt(config.modules.network.password, config.modules.network.encryption.key, config.modules.network.encryption.iv), "User " .. username .. " tried to open the door attached to this computer, with incorrect card data " .. data .. "!")
      return
      end
    end
  end
  os.sleep(config.modules.door.unlocktime)
  for addr, type in component.list("os_doorcontroller") do
    component.invoke(addr, "close")
  end
end
local function activateAlarms(_, _, _, _, username)
  if not containsValue(config.modules.alert.whitelist, username) then
    for addr, type in component.list("os_alarm") do
      component.invoke(addr, "activate")
    end
  else
    return
  end
end
if args[1] == "modules" then
  if args[2] == "cardwriter" then
    if args[3] == "write" then
      if args[4] == nil then
        io.write("Data: ")
        text = io.read()
      else
        text = args[4]
      end
      if args[5] == nil then
        io.write("Name: ")
        name = io.read()
      else
        name = args[5]
      end
      ok, why = pcall(component.os_cardwriter.write, text, name, true)
      if not ok then
        print("Error, operation failed. Reason: " .. why)
        return
      end
      modem.broadcast(430, "OSU", "CARDWRITER", "WRITE", data.encrypt(config.modules.network.password, config.modules.network.encryption.key, config.modules.network.encryption.iv), "A user wrote card with data " .. text .. " and name " .. name .. " on the cardwriter conected to this computer!")
    end
  elseif args[2] == "door" then
    if not component.isAvailable("os_doorcontroller") then
      print("Error, door controller not available. Exiting.")
      os.exit()
    end
    if args[3] == "override" then
      if args[4] == nil then
        io.write("Password: ")
        options = {}
        options.pwchar = " "
        pass = term.read(options)
      else
        pass = args[4]
      end
      if pass == config.modules.door.override then
        modem.broadcast(430, "OSU", "DOOR", "UNLOCKALL", data.encrypt(config.modules.network.password, config.modules.network.encryption.key, config.modules.network.encryption.iv), data.encrypt(config.modules.door.override, config.modules.network.encryption.key, config.modules.network.encryption.iv))
        for addr in component.list("os_doorcontroller") do
          component.invoke(addr, "open")
        end
      else
        print("Incorrect password!")
      end
    elseif args[3] == "override_lock" then
      if args[4] == nil then
        io.write("Password: ")
        options = {}
        options.pwchar = " "
        pass = term.read(options)
      else
        pass = args[4]
      end
      if pass == config.modules.door.override then
        for addr, type in component.list("os_doorcontroller") do
          component.invoke(addr, "close")
        end
      else
        print("Incorrect password!")
      end
    elseif args[3] == "start" then
      if not component.isAvailable("os_magreader") then
        print("Error, magnetic card reader not available. Exiting.")
        os.exit()
      end
      id_door, _, _, username, data, _, _, _ = event.listen("magData", unlockDoor)
    elseif args[3] == "stop" then
      pcall(event.cancel, id_door)
    end
  elseif args[2] == nil then
    print("Usage: osu modules [MODULE] [COMMAND]")
  elseif args[2] == "alert" then
    if args[3] == "start" then
      if not component.isAvailable("motion_sensor") then
        print("Error, motion sensor not available.")
        os.exit()
      end
      if not component.isAvailable("os_alarm") then
        print("Error, alarm not available.")
        os.exit()
      end
      id_alert, _, _, _, _, _, username = event.listen("motion", activateAlarms)
    elseif args[3] == "stop" then
      event.cancel(id_alert)
      for addr in component.list("os_alarm") do
        component.proxy(addr).deactivate()
      end
    end
  elseif args[2] == "network" then
    if args[3] == "start_client" then
      id_network, _, _, sender, port, _, program, module, command, password, data, args1, args2, args3 = event.listen("modem_message", onReceive)
    elseif args[3] == "stop_client" then
      event.cancel(id_network)
    elseif args[3] == "send_message" then
      io.write("Message: ")
      message = io.read()
      modem.broadcast(340, "OSU", "NETWORK", "SEND_MESSAGE", data.encrypt(config.modules.network.password, config.modules.network.encryption.key, config.modules.network.encryption.iv), message)
    elseif args[3] == "display" then
      term.clear()
      function printOutput()
        _, _, sender, port, _, program, module, command, password, data, args1, args2, args3 = event.pull("modem_message")
        if port == 430 then
          if program == "OSU" then
            password = data.decrypt(password, config.modules.network.encryption.key, config.modules.network.encryption.iv)
            if password == config.modules.network.password then
              print("Received message from " .. sender .. "'s module '" .. module .. "'. Data: " .. data)
            end
          end
        end
      end
    else
      print("Usage: osu modules network [COMMAND].")
      print("Commands:")
      print(" osu modules network start_client - listens for network messages from other clients / the main server")
      print(" osu modules network stop_client - stops listening for messages")
      print(" osu modules network send_message - sends a network message")
      print(" osu modules network display - displays all received OSU network messages")
    end
  else
    print("Error, not a valid module.")
    print("Valid modules: ")
    for k, v in pairs(config.modules) do
      print(k)
    end
  end
elseif args[1] == "components" then
  if args[2] == "list" then
    for address, type in component.list() do
      if type:match("os_") == "os_" then
        print(type:match("^.+_(.+)$"))
      end
    end
  else
    print("Usage: osu components [COMMAND]")
    print("Commands:")
    print("  list - lists all connected OpenSecurity components")
  end
else
  print("Usage: osu [COMMAND]")
  print("Commands:")
  print("  osu modules - module-related commands")
  print("  osu components - component-related commands")
end
