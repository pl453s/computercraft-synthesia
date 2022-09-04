-- INSTRUMENTS AND PARTITIONS TABLES
instruments = {} -- instruments[channel] = {char, color, side, name}
partitions  = {} -- partitions[channel][line][column] = volume

-- MUSIC VARIABLES
delay    = 20  -- HUNDREDTHS OF SECONDS BETWEEN EACH LINE
measure  = 8   -- MEASURE LENGTH
shift    = 0   -- GLOBAL TONE SHIFT
length   = 0   -- PARTITION LENGTH
channels = 0   -- NUMBER OF CHANNELS

-- RUNNING VARIABLES
channel  = 0   -- CURRENT INSTRUMENT/CHANNEL (0=no channel --> 12 max)
scroll   = 0   -- SCROLLING VIEW SHIFT (0 --> ...)
volume   = 10  -- SELECTED VOLUME (0.1 -> 8.0)
keypos   = 7   -- BOTTOM KEYBOARD FIRST NOTE (1 -> 12)
keyupper = ""  -- KEYBOARD UPPER LINE LAYOUT (A -> Y)
keylower = ""  -- KEYBOARD LOWER LINE LAYOUT (A -> Y)

-- CONSTANTS AND SPEAKERS CONNECTIONS
palette  = "ce145d93ba26" -- CHANNELS COLOR PALETTE
speakerc = peripheral.wrap("top")
speakerl = peripheral.wrap("left")
speakerr = peripheral.wrap("right")










-- MAIN EVENTS LOOP
function mainloop()
	while true do
		event, button, mousex, mousey = os.pullEvent()

		-- KEYS EVENTS
		if event == "key" then

			-- MAIN MENU
			if button == keys.tab then
				out = mainmenu()
				if out then
					return
				end
				drawgui(false, false)
			end

			-- SAVE FILE
			if button == keys.enter then
				writefile()
			end

			-- PLAY FROM START OR FROM POSITION
			if button == keys.backspace then
				playfile(1)
				drawgui(false, true)
			end
			if button == keys.space then
				playfile(1+scroll)
				drawgui(false, true)
			end

			-- SWITCH INSTRUMENT/CHANNEL
			if button == keys.up and channel > 0 then
				channel = channel-1
				drawgui(false, false)
			end
			if button == keys.down and channel < channels then
				channel = channel+1
				drawgui(false, false)
			end

			-- CHANGE SELECTED VOLUME
			if button == keys.left and volume > 1 then
				volume = volume-1
				drawgui(true, false)
			end
			if button == keys.right and volume < 80 then
				volume = volume+1
				drawgui(true, false)
			end

		end

		-- CLICK AND DRAG EVENTS
		if event == "mouse_click" or event == "mouse_drag" then
			if mousex == 1 then

				-- MAIN MENU
				if event == "mouse_click" and button == 1 and mousey == 1 then
					out = mainmenu()
					if out then
						return
					end
					drawgui(false, false)
				end

				-- SWITCH INSTRUMENT/CHANNEL
				if event == "mouse_click" and button == 1 and mousey-3 >= 0 and mousey-3 <= channels and mousey-3 ~= channel then
					channel = mousey-3
					drawgui(false, false)
				end

				-- EDIT INSTRUMENT/CHANNEL
				if event == "mouse_click" and button == 2 and mousey-3 >= 1 and mousey-3 <= channels then
					out = chconfig(mousey-3)
					if out and mousey-3 == channel then
						channel = channel-1
					end
					drawgui(false, false)
				end

				-- ADD INSTRUMENT/CHANNEL
				if event == "mouse_click" and button == 1 and mousey-3 == channels+1 and channels < 12 then
					color = 1
					repeat
						used = false
						for i, instrument in ipairs(instruments) do
							if instrument[2] == string.sub(palette, color, color) then
								used = true
								color = color+1
								break
							end
						end
					until not used
					channels = channels+1
					table.insert(instruments, {"?", string.sub(palette, color, color), "d", ""})
					table.insert(partitions, {})
					for y = 1, length do
						table.insert(partitions[channels], {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0})
					end
					drawgui(true, false)
				end

			else
				if mousey < 18 then
					mousenote = math.floor(mousex/2)
					mousetime = mousey+scroll

					-- PLACE A NOTE
					if (event == "mouse_click" or event == "mouse_drag") and button == 1 and channel ~= 0 then
						for i, partition in ipairs(partitions) do
							for y = length+1, mousetime do
								table.insert(partition, {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0})
							end
						end
						if mousetime > length then
							if length == 0 then
								length = mousetime
								drawgui(false, false)
							else
								length = mousetime
							end
						end
						partitions[channel][mousetime][mousenote] = volume
						term.setCursorPos(mousenote*2, mousey)
						term.blit(tostring(math.floor(volume/10)), "f", instruments[channel][2])
						term.blit(tostring(volume-math.floor(volume/10)*10), "f", instruments[channel][2])
					end

					-- ERASE A NOTE
					if (event == "mouse_click" or event == "mouse_drag") and button == 2 and channel ~= 0 and mousetime <= length then
						partitions[channel][mousetime][mousenote] = 0
						term.setCursorPos(mousenote*2, mousey)
						other = false
						for i, partition in ipairs(partitions) do
							if partition[mousetime][mousenote] ~= 0 and i ~= channel then
								other = true
								break
							end
						end
						text = "  "
						if other then
							term.blit(text, "ff", "00")
						else
							if measure ~= 0 then
								if mousetime/measure == math.floor(mousetime/measure) then
									text = "__"
								end
							end
							term.blit(text, "00", "ff")
						end
					end

				else

					-- MANUALLY PLAY A NOTE
					if event == "mouse_click" and button == 1 and channel ~= 0 then
						playside = instruments[channel][3]
						playinst = instruments[channel][4]
						playloud = volume
						if mousey == 18 then playnote = string.byte(string.sub(keyupper, mousex-1, mousex-1))-64-1+shift end
						if mousey == 19 then playnote = string.byte(string.sub(keylower, mousex-1, mousex-1))-64-1+shift end
						if playloud ~= 0 and playnote >= 0 and playnote <= 24 and playside ~= "d" then
							if playside == "c" then playspkr = speakerc end
							if playside == "l" then playspkr = speakerl end
							if playside == "r" then playspkr = speakerr end
							playdone = 0
							for i = 0, playloud-10, 10 do
								playspkr.playNote(playinst, 1, playnote)
								playdone = playdone+10
							end
							playspkr.playNote(playinst, (playloud-playdone)/10, playnote)
						end
					end

				end
			end
		end

		-- SCROLL EVENTS
		if event == "mouse_scroll" and mousex ~= 1 then
			if mousey < 18 then
				-- SCROLL PARTITION
				if scroll+button >= 0 and scroll+button <= length then
					scroll = scroll+button
					drawgui(false, false)
				end
			else
				-- SCROLL KEYBOARD
				keypos = keypos+button
				if keypos < 1 then keypos = 12 end
				if keypos > 12 then keypos = 1 end
				drawgui(false, true)
			end
		end

	end
end










-- DRAW OR REDRAW SIDEBAR, KEYBOARD AND PARTITION
function drawgui(onlybar, onlykey)

	-- DRAW PARTITION
	if not onlybar and not onlykey then
		term.setBackgroundColor(colors.black)
		term.setTextColor(colors.white)
		term.clear()
		if length == 0 then

			term.setCursorPos(2, 1)
			term.write(" <-- Main menu (press TAB)")

			term.setCursorPos(2, 3)
			term.write("\\")
			term.setCursorPos(2, 4)
			term.write(" |")
			term.setCursorPos(2, 5)
			term.write(" |     Channels: Left click")
			term.setCursorPos(2, 6)
			term.write(" |     or UP/DOWN arrows")
			term.setCursorPos(2, 7)
			term.write(" |     to switch channel")
			term.setCursorPos(2, 8)
			term.write(" |     Right click to edit")
			term.setCursorPos(2, 9)
			term.write(" | <-- ")
			term.setCursorPos(2, 10)
			term.write(" |     First button is")
			term.setCursorPos(2, 11)
			term.write(" |     deselect channel")
			term.setCursorPos(2, 12)
			term.write(" |     Last button is")
			term.setCursorPos(2, 13)
			term.write(" |     create a channel")
			term.setCursorPos(2, 14)
			term.write(" |")
			term.setCursorPos(2, 15)
			term.write("/")

			term.setCursorPos(2, 16)
			term.write("     LEFT and RIGHT arrows")
			term.setCursorPos(2, 17)
			term.write(" L-- to change loudness")

			for y = 1, 17 do
				term.setCursorPos(30, y)
				term.write("|")
			end

			term.setCursorPos(32, 1)
			term.write("Left click to place")
			term.setCursorPos(32, 2)
			term.write("a note, of the")
			term.setCursorPos(32, 3)
			term.write("picked loudness, on")
			term.setCursorPos(32, 4)
			term.write("the current channel")
			term.setCursorPos(32, 5)
			term.write("Right click to erase")

			term.setCursorPos(32, 10)
			term.write("Play manually on the")
			term.setCursorPos(32, 11)
			term.write("keyboard, scroll to")
			term.setCursorPos(32, 12)
			term.write("shift the keyboard")
			term.setCursorPos(32, 13)
			term.write("(graphically only)")

			term.setCursorPos(41, 15)
			term.write("|")
			term.setCursorPos(41, 16)
			term.write("V")

		else
			for y = 1, 17 do
				if measure ~= 0 then
					if (y+scroll)/measure == math.floor((y+scroll)/measure) then
						term.setCursorPos(2, y)
						term.blit(string.rep("_", 50), string.rep("0", 50), string.rep("f", 50))
					end
				end
			end
			for i, partition in ipairs(partitions) do
				if i ~= channel then
					for y = 1, 17 do
						if y+scroll > length then
							break
						end
						for x = 1, 25 do
							if partition[y+scroll][x] ~= 0 then
								term.setCursorPos(x*2, y)
								term.blit("  ", "ff", "00")
							end
						end
					end
				end
			end
			if channel ~= 0 then
				for y = 1, 17 do
					if y+scroll > length then
						break
					end
					for x = 1, 25 do
						if partitions[channel][y+scroll][x] ~= 0 then
							term.setCursorPos(x*2, y)
							cell = partitions[channel][y+scroll][x]
							term.blit(tostring(math.floor(cell/10)), "f", instruments[channel][2])
							term.blit(tostring(cell-math.floor(cell/10)*10), "f", instruments[channel][2])
						end
					end
				end
			end
		end
	end

	-- DRAW SIDEBAR
	if (not onlybar and not onlykey) or onlybar then
		for y = 1, 19 do
			term.setCursorPos(1, y)
			if y == 1 then
				term.blit("=", "0", "7")
			elseif y == 3 then
				if channel == 0 then
					term.blit("ø", "f", "0")
				else
					term.blit("ø", "0", "7")
				end
			elseif y-3 >= 0 and y-3 <= channels then
				if y-3 == channel then
					term.blit(instruments[y-3][1], "f", instruments[y-3][2])
				else
					term.blit(instruments[y-3][1], instruments[y-3][2], "7")
				end
			elseif y-3 == channels+1 and channels < 12 then
				term.blit("+", "0", "7")
			elseif y == 18 then
				term.blit(tostring(math.floor(volume/10)), "0", "7")
			elseif y == 19 then
				term.blit(tostring(volume-math.floor(volume/10)*10), "0", "7")
			else
				term.blit(" ", "0", "7")
			end
		end
	end

	-- DRAW KEYBOARD
	if (not onlybar and not onlykey) or onlykey then
		keyupper = "AABBCCDDEEFFGGHHIIJJKKLLMMNNOOPPQQRRSSTTUUVVWWXXYY"
		if keypos == 01 then keylower = "AAACCCCEEEFFFHHHHJJJJLLLMMMOOOOQQQRRRTTTTVVVVXXXYY" end
		if keypos == 02 then keylower = "@BBBBDDDEEEGGGGIIIIKKKLLLNNNNPPPQQQSSSSUUUUWWWXXXZ" end
		if keypos == 03 then keylower = "AAACCCDDDFFFFHHHHJJJKKKMMMMOOOPPPRRRRTTTTVVVWWWYYY" end
		if keypos == 04 then keylower = "@BBBCCCEEEEGGGGIIIJJJLLLLNNNOOOQQQQSSSSUUUVVVXXXXZ" end
		if keypos == 05 then keylower = "AABBBDDDDFFFFHHHIIIKKKKMMMNNNPPPPRRRRTTTUUUWWWWYYY" end
		if keypos == 06 then keylower = "AAACCCCEEEEGGGHHHJJJJLLLMMMOOOOQQQQSSSTTTVVVVXXXYY" end
		if keypos == 07 then keylower = "@BBBBDDDDFFFGGGIIIIKKKLLLNNNNPPPPRRRSSSUUUUWWWXXXZ" end
		if keypos == 08 then keylower = "AAACCCCEEEFFFHHHHJJJKKKMMMMOOOOQQQRRRTTTTVVVWWWYYY" end
		if keypos == 09 then keylower = "@BBBBDDDEEEGGGGIIIJJJLLLLNNNNPPPQQQSSSSUUUVVVXXXXZ" end
		if keypos == 10 then keylower = "AAACCCDDDFFFFHHHIIIKKKKMMMMOOOPPPRRRRTTTUUUWWWWYYY" end
		if keypos == 11 then keylower = "@BBBCCCEEEEGGGHHHJJJJLLLLNNNOOOQQQQSSSTTTVVVVXXXXZ" end
		if keypos == 12 then keylower = "AABBBDDDDFFFGGGIIIIKKKKMMMNNNPPPPRRRSSSUUUUWWWWYYY" end
		term.setCursorPos(2, 18)
		if keypos == 01 then term.blit(string.rep(" ", 50), string.rep("f", 50), "00778877008877007788770088770077880077887700778800") end
		if keypos == 02 then term.blit(string.rep(" ", 50), string.rep("f", 50), "77007788007788770077880077887700887700778877008877") end
		if keypos == 03 then term.blit(string.rep(" ", 50), string.rep("f", 50), "00778800778877007788007788770088770077887700887700") end
		if keypos == 04 then term.blit(string.rep(" ", 50), string.rep("f", 50), "77008877007788770088770077880077887700778800778877") end
		if keypos == 05 then term.blit(string.rep(" ", 50), string.rep("f", 50), "00887700778877008877007788007788770077880077887700") end
		if keypos == 06 then term.blit(string.rep(" ", 50), string.rep("f", 50), "00778877007788007788770088770077887700887700778800") end
		if keypos == 07 then term.blit(string.rep(" ", 50), string.rep("f", 50), "77007788770088770077880077887700778800778877008877") end
		if keypos == 08 then term.blit(string.rep(" ", 50), string.rep("f", 50), "00778877008877007788007788770077880077887700887700") end
		if keypos == 09 then term.blit(string.rep(" ", 50), string.rep("f", 50), "77007788007788770088770077887700887700778800778877") end
		if keypos == 10 then term.blit(string.rep(" ", 50), string.rep("f", 50), "00778800778877008877007788770088770077880077887700") end
		if keypos == 11 then term.blit(string.rep(" ", 50), string.rep("f", 50), "77008877007788007788770077880077887700887700778877") end
		if keypos == 12 then term.blit(string.rep(" ", 50), string.rep("f", 50), "00887700778800778877007788007788770088770077887700") end
		term.setCursorPos(2, 19)
		if keypos == 01 then term.blit(string.rep(" ", 50), string.rep("f", 50), "00088880008880000888800088800008880008888000088800") end
		if keypos == 02 then term.blit(string.rep(" ", 50), string.rep("f", 50), "80000888000888800008880008888000888000088880008880") end
		if keypos == 03 then term.blit(string.rep(" ", 50), string.rep("f", 50), "00088800088880000888000888800088800008888000888000") end
		if keypos == 04 then term.blit(string.rep(" ", 50), string.rep("f", 50), "80008880000888800088800008880008888000088800088880") end
		if keypos == 05 then term.blit(string.rep(" ", 50), string.rep("f", 50), "00888000088880008880000888000888800008880008888000") end
		if keypos == 06 then term.blit(string.rep(" ", 50), string.rep("f", 50), "00088880000888000888800088800008888000888000088800") end
		if keypos == 07 then term.blit(string.rep(" ", 50), string.rep("f", 50), "80000888800088800008880008888000088800088880008880") end
		if keypos == 08 then term.blit(string.rep(" ", 50), string.rep("f", 50), "00088880008880000888000888800008880008888000888000") end
		if keypos == 09 then term.blit(string.rep(" ", 50), string.rep("f", 50), "80000888000888800088800008888000888000088800008880") end
		if keypos == 10 then term.blit(string.rep(" ", 50), string.rep("f", 50), "00088800088880008880000888800088800008880008888000") end
		if keypos == 11 then term.blit(string.rep(" ", 50), string.rep("f", 50), "80008880000888000888800008880008888000888000088880") end
		if keypos == 12 then term.blit(string.rep(" ", 50), string.rep("f", 50), "00888000088800088880000888000888800088800008888000") end
	end

end










-- MAIN MENU
function mainmenu()
	term.setCursorPos(11, 2)
	term.blit("        Main menu [TAB]        x", "ffffffffffffffffffbbbbbfffffffff", "8888888888888888888888888888888e")
	term.setCursorPos(11, 3)
	term.blit("                                ", "00000000000000000000000000000000", "77777777777777777777777777777777")
	term.setCursorPos(11, 4)
	term.blit("  Delay:    Measure:    Shift:  ", "00000000000000000000000000000000", "77777777777777777777777777777777")
	term.setCursorPos(11, 5)
	term.blit("                                ", "00000000000000000000000000000000", "77777777777777777777777777777777")
	term.setCursorPos(11, 6)
	term.blit("                                ", "00000000000000000000000000000000", "77777777777777777777777777777777")
	term.setCursorPos(11, 7)
	term.blit(" ------------------------------ ", "00000000000000000000000000000000", "77777777777777777777777777777777")
	term.setCursorPos(11, 8)
	term.blit("                                ", "00000000000000000000000000000000", "77777777777777777777777777777777")
	term.setCursorPos(11, 9)
	term.blit("  Play from start [BACKSPACE]   ", "00ffffffffffffffffbbbbbbbbbbbf00", "77888888888888888888888888888877")
	term.setCursorPos(11, 10)
	term.blit("                                ", "00000000000000000000000000000000", "77777777777777777777777777777777")
	term.setCursorPos(11, 11)
	term.blit("  Play from position [SPACE]    ", "00fffffffffffffffffffbbbbbbbff00", "77888888888888888888888888888877")
	term.setCursorPos(11, 12)
	term.blit("                                ", "00000000000000000000000000000000", "77777777777777777777777777777777")
	term.setCursorPos(11, 13)
	term.blit(" ------------------------------ ", "00000000000000000000000000000000", "77777777777777777777777777777777")
	term.setCursorPos(11, 14)
	term.blit("                                ", "00000000000000000000000000000000", "77777777777777777777777777777777")
	term.setCursorPos(11, 15)
	term.blit("  Save [ENTER]   Reload   Quit  ", "00fffffbbbbbbb000ffffff000ffff00", "77888888888888777888888777eeee77")
	term.setCursorPos(11, 16)
	term.blit("                                ", "00000000000000000000000000000000", "77777777777777777777777777777777")
	while true do
		text = tostring(delay)
		text = string.rep(" ", 6-#text)..text
		term.setCursorPos(13, 5)
		term.blit(text, string.rep("f", #text), string.rep("8", #text))
		text = tostring(measure)
		text = string.rep(" ", 6-#text)..text
		term.setCursorPos(24, 5)
		term.blit(text, string.rep("f", #text), string.rep("8", #text))
		text = tostring(shift)
		text = string.rep(" ", 6-#text)..text
		term.setCursorPos(35, 5)
		term.blit(text, string.rep("f", #text), string.rep("8", #text))
		event, button, mousex, mousey = os.pullEvent()
		if event == "key" then

			-- CLOSE MAIN MENU
			if button == keys.tab then
				return false
			end

			-- SAVE FILE
			if button == keys.enter then
				writefile()
				return false
			end

			-- PLAY FROM START OR FROM POSITION
			if button == keys.backspace then
				drawgui(false, false)
				playfile(1)
				return false
			end
			if button == keys.space then
				drawgui(false, false)
				playfile(1+scroll)
				return false
			end

		end
		if event == "mouse_click" and button == 1 then

			-- CLOSE MAIN MENU
			if mousex == 42 and mousey == 2 then
				return false
			end

			-- PLAY FROM START
			if mousex >= 13 and mousex <= 40 and mousey == 9 then
				drawgui(false, false)
				playfile(1)
				return false
			end

			-- PLAY FROM POSITION
			if mousex >= 13 and mousex <= 40 and mousey == 11 then
				drawgui(false, false)
				playfile(1+scroll)
				return false
			end

			-- SAVE FILE
			if mousex >= 13 and mousex <= 24 and mousey == 15 then
				-- #####TODO##### done or readonly
				writefile()
				return false
			end

			-- RELOAD FILE
			if mousex >= 28 and mousex <= 33 and mousey == 15 then
				-- #####TODO##### confirmation
				readfile()
				return false
			end

			-- QUIT SOFTWARE
			if mousex >= 37 and mousex <= 40 and mousey == 15 then
				-- #####TODO##### confirmation
				term.setBackgroundColor(colors.black)
				term.setTextColor(colors.white)
				term.clear()
				term.setCursorPos(1, 1)
				return true
			end

		end
		if event == "mouse_scroll" then

			-- CHANGE DELAY, MEASURE OR SHIFT
			if mousex >= 13 and mousex <= 18 and mousey == 5 and delay+button >= 0 and delay+button <= 100 then
				delay = delay+button
			end
			if mousex >= 24 and mousex <= 29 and mousey == 5 and measure+button >= 0 and measure+button <= 100 then
				measure = measure+button
			end
			if mousex >= 35 and mousex <= 40 and mousey == 5 and shift+button >= -20 and shift+button <= 20 then
				shift = shift+button
			end

		end
	end
	event = ""
end










-- CHANNEL CONFIGURATION
function chconfig(id)
	char  = instruments[id][1]
	color = instruments[id][2]
	side  = instruments[id][3]
	name  = instruments[id][4]
	term.setCursorPos(11, 2)
	term.blit("        Channel config.        x", "ffffffffffffffffffffffffffffffff", "8888888888888888888888888888888e")
	term.setCursorPos(11, 3)
	term.blit("                                ", "00000000000000000000000000000000", "77777777777777777777777777777777")
	term.setCursorPos(11, 4)
	term.blit("  Instrument:                   ", "00000000000000000000000000000000", "77777777777777777777777777777777")
	term.setCursorPos(11, 5)
	term.blit("                                ", "00000000000000000000000000000000", "77777777777777777777777777777777")
	term.setCursorPos(11, 6)
	term.blit(" ------------------------------ ", "00000000000000000000000000000000", "77777777777777777777777777777777")
	term.setCursorPos(11, 7)
	term.blit("                                ", "00000000000000000000000000000000", "77777777777777777777777777777777")
	term.setCursorPos(11, 8)
	term.blit("    Center    |   Disp char:    ", "00000000000000000000000000000000", "77777777777777777777777777777777")
	term.setCursorPos(11, 9)
	term.blit("    Left      |                 ", "00000000000000000000000000000000", "77777777777777777777777777777777")
	term.setCursorPos(11, 10)
	term.blit("    Right     |   Notes color:  ", "00000000000000000000000000000000", "77777777777777777777777777777777")
	term.setCursorPos(11, 11)
	term.blit("    Disable   |                 ", "00000000000000000000000000000000", "77777777777777777777777777777777")
	term.setCursorPos(11, 12)
	term.blit("                                ", "00000000000000000000000000000000", "77777777777777777777777777777777")
	term.setCursorPos(11, 13)
	term.blit(" ------------------------------ ", "00000000000000000000000000000000", "77777777777777777777777777777777")
	term.setCursorPos(11, 14)
	term.blit("                                ", "00000000000000000000000000000000", "77777777777777777777777777777777")
	term.setCursorPos(11, 15)
	term.blit("  Delete        Cancel   Apply  ", "00ffffff00000000ffffff000fffff00", "77eeeeee77777777888888777bbbbb77")
	term.setCursorPos(11, 16)
	term.blit("                                ", "00000000000000000000000000000000", "77777777777777777777777777777777")
	while true do
		term.setCursorPos(25, 4)
		term.blit(string.rep(" ", 16), string.rep("f", 16), string.rep("8", 16))
		term.setCursorPos(25, 4)
		term.blit(name, string.rep("f", #name), string.rep("8", #name))
		term.setCursorPos(13, 8)
		if side == "c" then term.blit("x", "f", "8") else term.blit(" ", "f", "8") end
		term.setCursorPos(13, 9)
		if side == "l" then term.blit("x", "f", "8") else term.blit(" ", "f", "8") end
		term.setCursorPos(13, 10)
		if side == "r" then term.blit("x", "f", "8") else term.blit(" ", "f", "8") end
		term.setCursorPos(13, 11)
		if side == "d" then term.blit("x", "f", "8") else term.blit(" ", "f", "8") end
		term.setCursorPos(40, 8)
		term.blit(char, "f", "8")
		for x = 1, 12 do
			term.setCursorPos(28+x, 11)
			if color == string.sub(palette, x, x) then
				term.blit("x", "f", string.sub(palette, x, x))
			else
				term.blit(" ", "f", string.sub(palette, x, x))
			end
		end
		event, button, mousex, mousey = os.pullEvent()
		-- #####TODO##### channel configuration
		if event == "mouse_click" and button == 1 then

			-- CLOSE CHANNEL CONFIG
			if mousex == 42 and mousey == 2 then
				return false
			end

		end
		if event == "key" then

			-- CLOSE MAIN MENU
			--if button == keys.tab then
			--	return false
			--end

		end
		if event == "char" then

			-- CLOSE MAIN MENU
			--if button == keys.tab then
			--	return false
			--end

		end
	end
	event = ""
end










-- FILL VARIABLES FROM THE FILE IN "PATH"
function readfile()

	-- CHECKS AND OPEN FILE
	if not fs.exists(path) then return nil end
	if fs.isDir(path) then return false end
	file = fs.open(path, "r")

	-- RESET VARIABLES
	instruments = {}
	partitions  = {}
	delay    = 20
	measure  = 8
	shift    = 0
	length   = 0
	channels = 0
	channel  = 0
	scroll   = 0

	state = nil
	while true do
		line = file.readLine()
		if not line then
			break
		end
		if line ~= "" and string.sub(line, 1, 2) ~= "--" then
			if state == nil then

				-- READ HEADER
				x1 = 0
				x2 = string.find(line, " ", x1+1)
				delay = tonumber(string.sub(line, x1+1, x2-1))
				x1 = x2
				x2 = string.find(line, " ", x1+1)
				measure = tonumber(string.sub(line, x1+1, x2-1))
				x1 = x2
				x2 = string.find(line, " ", x1+1)
				shift = tonumber(string.sub(line, x1+1, x2-1))
				state = false

			elseif state == false then

				-- READ INSTRUMENTS
				x = 0
				while string.sub(line, x+51, x+51) == "|" do
					char  = string.sub(line, x+1, x+1)
					color = string.sub(line, x+2, x+2)
					side  = string.sub(line, x+3, x+3)
					name  = string.sub(line, x+5, string.find(line, " ", x+5)-1)
					channels = channels+1
					table.insert(instruments, {char, color, side, name})
					table.insert(partitions, {})
					x = x+51
				end
				state = true

			else

				-- READ PARTITION
				length = length+1
				for i = 1, channels do
					table.insert(partitions[i], {})
					for x = i*51-50, i*51-1, 2 do
						cell = tonumber(string.sub(line, x, x+1))
						table.insert(partitions[i][length], cell)
					end
				end

			end
		end
	end

	-- CLOSE FILE AND RETURN
	file.close()
	return true

end










-- WRITE THE FILE IN "PATH" FROM VARIABLES
function writefile()

	-- CHECK READ ONLY
	if fs.isReadOnly then
		return false
	end

	-- CALCULATE REAL LENGTH
	real = 0
	for y = 1, length do
		for i = 1, channels do
			for x = 1, 25 do
				if partitions[i][y][x] ~= 0 then
					real = y
				end
			end
		end
	end

	-- OPEN FILE
	file = fs.open(path, "w")

	-- WRITE HEADER
	file.writeLine(delay.." "..measure.." "..shift.." ")

	-- WRITE INSTRUMENTS
	line = string.rep(string.rep("-", 50).."+", channels)
	file.writeLine(line)
	line = ""
	for i, instrument in ipairs(instruments) do
		entry = instrument[1]..instrument[2]..instrument[3].." "..instrument[4]
		entry = entry..string.rep(" ", 50-#entry)
		line = line..entry.."|"
	end
	file.writeLine(line)
	line = string.rep(string.rep("-", 50).."+", channels)
	file.writeLine(line)

	-- WRITE PARTITION
	for y = 1, real do
		line = ""
		for i = 1, channels do
			for x = 1, 25 do
				cell = partitions[i][y][x]
				line = line..tostring(math.floor(cell/10))
				line = line..tostring(cell-math.floor(cell/10)*10)
			end
			line = line.."|"
		end
		file.writeLine(line)
		if y/measure == math.floor(y/measure) then
			line = string.rep(string.rep("-", 50).."+", channels)
			file.writeLine(line)
		end
	end

	-- CLOSE FILE AND RETURN
	file.close()
	return true

end










-- PLAY THE CURRENT PARTITION FROM LINE "START"
function playfile(start)
	term.setCursorPos(2, 18)
	term.blit(string.rep(" ", 50), string.rep("f", 50), string.rep("8", 50))
	term.setCursorPos(2, 19)
	term.blit(string.rep(" ", 50), string.rep("f", 50), string.rep("8", 50))
	text = "Playing \""..fs.getName(path).."\"..."
	term.setCursorPos(2+(50-#text)/2, 18)
	term.blit(text, string.rep("f", #text), string.rep("8", #text))
	text = "Press any key to stop"
	term.setCursorPos(2+(50-#text)/2, 19)
	term.blit(text, string.rep("f", #text), string.rep("8", #text))
	for y = start, length do
		os.startTimer(delay/100)
		for i, partition in ipairs(partitions) do
			playside = instruments[i][3]
			playinst = instruments[i][4]
			for x = 1, 25 do
				playloud = partition[y][x]
				playnote = x-1+shift
				if playloud ~= 0 and playnote >= 0 and playnote <= 24 and playside ~= "d" then
					if playside == "c" then playspkr = speakerc end
					if playside == "l" then playspkr = speakerl end
					if playside == "r" then playspkr = speakerr end
					playdone = 0
					for i = 0, playloud-10, 10 do
						playspkr.playNote(playinst, 1, playnote)
						playdone = playdone+10
					end
					playspkr.playNote(playinst, (playloud-playdone)/10, playnote)
				end
			end
		end
		repeat
			event = os.pullEvent()
			if event == "key" then
				return false
			end
		until event == "timer"
	end
	event = ""
	return true
end










-- INITIALIZATION
args = {...}
if #args < 1 then
	print("Usage: score <path>")
	return
end
path = args[1]
out = readfile()
if out == false then
	print("Cannot edit a directory.")
	return
end
drawgui(false, false)
mainloop()
