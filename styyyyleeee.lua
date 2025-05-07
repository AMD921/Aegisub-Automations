-- Script: Import Styles from ASS File
-- Author: Claude
-- Version: 1.0
-- Description: Imports styles from another ASS file into the current subtitle file

script_name = "Import Styles"
script_description = "Imports styles from another ASS file"
script_author = "Claude"
script_version = "1.0"

-- Include Aegisub libraries
local re = require 'aegisub.re'
local unicode = require 'aegisub.unicode'

-- Main function
function import_styles(subtitle, selected_lines)
    -- Get the file path of the ASS file to import styles from
    local source_file = aegisub.dialog.open('Select ASS file to import styles from', '', '', 'ASS files (*.ass)|*.ass', false, true)
    
    -- If no file was selected, exit the function
    if not source_file then
        aegisub.cancel()
    end
    
    -- Open the source file and read its contents
    local file = io.open(source_file, "r")
    if not file then
        aegisub.debug.out("Error: Could not open the selected file.\n")
        aegisub.cancel()
    end
    
    local content = file:read("*all")
    file:close()
    
    -- Create a table to store the styles
    local styles = {}
    
    -- Parse the styles from the source file
    -- Look for the [V4+ Styles] section
    local styles_section = content:match("%[V4%+ Styles%].-\n(.-)\n%[")
    
    -- If styles section wasn't found, try an alternative pattern
    if not styles_section then
        styles_section = content:match("%[V4%+ Styles%].-\n(.-)\n*$")
    end
    
    -- If still no styles section found, show error and exit
    if not styles_section then
        aegisub.debug.out("Error: Could not find styles in the selected file.\n")
        aegisub.cancel()
    end
    
    -- Extract styles from the styles section
    local style_count = 0
    for style_line in styles_section:gmatch("[^\n]+") do
        -- Check if the line starts with "Style: "
        if style_line:match("^Style: ") then
            table.insert(styles, style_line)
            style_count = style_count + 1
        end
    end
    
    -- If no styles were found, show error and exit
    if style_count == 0 then
        aegisub.debug.out("Error: No styles found in the selected file.\n")
        aegisub.cancel()
    end
    
    -- Find the [V4+ Styles] section in the current subtitle file
    local styles_index
    for i = 1, #subtitle do
        if subtitle[i].class == "info" and subtitle[i].key == "ScriptType" then
            -- Check if the current subtitle file is an ASS file
            if subtitle[i].value ~= "v4.00+" then
                aegisub.debug.out("Error: Current file is not an ASS file.\n")
                aegisub.cancel()
            end
        end
        
        if subtitle[i].class == "style" then
            styles_index = i
            break
        end
    end
    
    -- If no styles section was found, show error and exit
    if not styles_index then
        aegisub.debug.out("Error: Could not find styles section in current file.\n")
        aegisub.cancel()
    end
    
    -- Import styles
    local styles_added = 0
    local styles_updated = 0
    
    -- Get existing style names for comparison
    local existing_styles = {}
    for i = 1, #subtitle do
        if subtitle[i].class == "style" then
            existing_styles[subtitle[i].name] = i
        end
    end
    
    -- Process and import each style
    for _, style_line in ipairs(styles) do
        local style_name = style_line:match("^Style: ([^,]+)")
        
        -- Create a new style line
        local new_style = {class = "style"}
        
        -- Parse the style line
        local parts = {}
        for part in style_line:gmatch("[^,]+") do
            table.insert(parts, part)
        end
        
        -- Skip "Style: " prefix
        new_style.name = parts[1]:gsub("^Style: ", "")
        new_style.fontname = parts[2]
        new_style.fontsize = tonumber(parts[3])
        
        -- Colors and alphas (primary, secondary, outline, shadow)
        new_style.color1 = parts[4]
        new_style.color2 = parts[5]
        new_style.color3 = parts[6]
        new_style.color4 = parts[7]
        
        new_style.bold = (parts[8] == "-1")
        new_style.italic = (parts[9] == "-1")
        new_style.underline = (parts[10] == "-1")
        new_style.strikeout = (parts[11] == "-1")
        
        new_style.scale_x = tonumber(parts[12])
        new_style.scale_y = tonumber(parts[13])
        new_style.spacing = tonumber(parts[14])
        new_style.angle = tonumber(parts[15])
        
        new_style.borderstyle = tonumber(parts[16])
        new_style.outline = tonumber(parts[17])
        new_style.shadow = tonumber(parts[18])
        new_style.align = tonumber(parts[19])
        
        new_style.margin_l = tonumber(parts[20])
        new_style.margin_r = tonumber(parts[21])
        new_style.margin_t = tonumber(parts[22])
        new_style.margin_b = tonumber(parts[22]) -- ASS v4+ doesn't have bottom margin
        
        new_style.encoding = tonumber(parts[23])
        
        -- Check if style already exists
        if existing_styles[new_style.name] then
            -- Update existing style
            subtitle[existing_styles[new_style.name]] = new_style
            styles_updated = styles_updated + 1
        else
            -- Add new style
            subtitle.insert(styles_index, new_style)
            styles_index = styles_index + 1
            styles_added = styles_added + 1
        end
    end
    
    -- Inform the user about the result
    aegisub.debug.out(string.format("Successfully imported %d styles (%d new, %d updated).\n", 
                                    styles_added + styles_updated, styles_added, styles_updated))
    
    -- Force redrawing of subtitle grid
    aegisub.set_undo_point("Import styles")
    return selected_lines
end

-- Register the macro
aegisub.register_macro(script_name, script_description, import_styles)