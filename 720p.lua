script_name = "720 Cleanup"
script_description = [[Rescale script resolution to 720p, set color matrix to TV.709, and remove unused styles, accounting for \move, \clip, \iclip, shapes, and style margins]]
script_author = "Amin Mohammad Davoudi ft. GPT 4o --contact: t.me/amd921"
script_version = "0.0"

include("karaskel.lua")

-- Target resolution: 720p
target_x = 1280
target_y = 720

-- Main function
function transform_resolution(subtitles, selected_lines, active_line)
    -- Get current resolution from script info
    local meta, styles = karaskel.collect_head(subtitles)

    -- Read the original resolution from the script
    local original_x = tonumber(meta.res_x) or 0
    local original_y = tonumber(meta.res_y) or 0

    -- Check if the original resolution is valid
    if original_x == 0 or original_y == 0 then
        aegisub.debug.out("Error: Original resolution is invalid.\n")
        return
    end

    -- Calculate scaling factor for x and y
    local scale_x = target_x / original_x
    local scale_y = target_y / original_y

    -- Calculate the scale for shad, blur, be, bord
    local scale_shad_blur_bord = (scale_x + scale_y)/2

    -- Step 1: Transform resolution and rescale everything
    for i = 1, #subtitles do
        local line = subtitles[i]

        -- Transform script info
        if line.class == "info" then
            if line.key == "PlayResX" then
                line.value = tostring(target_x)
            elseif line.key == "PlayResY" then
                line.value = tostring(target_y)
            elseif line.key == "YCbCr Matrix" then
                line.value = "TV.709"
            end
            subtitles[i] = line
        end

        -- Transform styles
        if line.class == "style" then
            -- Scale font size, outline, shadow
            line.fontsize = math.floor(line.fontsize * scale_y)
            line.outline = math.floor(line.outline * scale_shad_blur_bord)
            line.shadow = math.floor(line.shadow * scale_shad_blur_bord)

            -- Scale style margins (left, right, vertical, top, bottom)
            line.margin_l = math.floor((line.margin_l or 0) * scale_x)
            line.margin_r = math.floor((line.margin_r or 0) * scale_x)
            line.margin_v = math.floor((line.margin_v or 0) * scale_y)
            line.margin_t = math.floor((line.margin_t or 0) * scale_y)  -- Scale top margin
            line.margin_b = math.floor((line.margin_b or 0) * scale_y)  -- Scale bottom margin

            subtitles[i] = line
        end

        -- Transform dialogues
        if line.class == "dialogue" then
            -- Initialize margins to avoid nil values
            line.margin_l = line.margin_l or 0
            line.margin_r = line.margin_r or 0
            line.margin_v = line.margin_v or 0
            line.margin_t = line.margin_t or 0  -- Top margin
            line.margin_b = line.margin_b or 0  -- Bottom margin
            
            line.margin_l = math.floor(line.margin_l * scale_x)
            line.margin_r = math.floor(line.margin_r * scale_x)
            line.margin_t = math.floor(line.margin_t * scale_y)  -- Scale top margin
            line.margin_b = math.floor(line.margin_b * scale_y)  -- Scale bottom margin
            line.margin_v = math.floor(line.margin_v * scale_y)  -- Scale vertical margin

            -- Scale \pos(x, y)
            line.text = line.text:gsub("\\pos%((%d+%.?%d*),(%d+%.?%d*)%)", function(x, y)
                local new_x = math.floor(tonumber(x) * scale_x)
                local new_y = math.floor(tonumber(y) * scale_y)
                return "\\pos(" .. new_x .. "," .. new_y .. ")"
            end)

            -- Scale \move(x1, y1, x2, y2)
            line.text = line.text:gsub("\\move%((%d+%.?%d*),(%d+%.?%d*),(%d+%.?%d*),(%d+%.?%d*)%)", function(x1, y1, x2, y2)
                local new_x1 = math.floor(tonumber(x1) * scale_x)
                local new_y1 = math.floor(tonumber(y1) * scale_y)
                local new_x2 = math.floor(tonumber(x2) * scale_x)
                local new_y2 = math.floor(tonumber(y2) * scale_y)
                return "\\move(" .. new_x1 .. "," .. new_y1 .. "," .. new_x2 .. "," .. new_y2 .. ")"
            end)

            -- Scale \clip and \iclip (rectangular clips)
            line.text = line.text:gsub("\\i?clip%((%d+%.?%d*),(%d+%.?%d*),(%d+%.?%d*),(%d+%.?%d*)%)", function(x1, y1, x2, y2)
                local new_x1 = math.floor(tonumber(x1) * scale_x)
                local new_y1 = math.floor(tonumber(y1) * scale_y)
                local new_x2 = math.floor(tonumber(x2) * scale_x)
                local new_y2 = math.floor(tonumber(y2) * scale_y)
                return "\\clip(" .. new_x1 .. "," .. new_y1 .. "," .. new_x2 .. "," .. new_y2 .. ")"
            end)

            -- Scale \clip and \iclip (vectorial clips and shapes)
            line.text = line.text:gsub("\\i?clip%(m ([%d%s%-l%.]+)%)", function(shape)
                local scaled_shape = shape:gsub("([%-]?%d+%.?%d*)%s*([%-l]?%d+%.?%d*)", function(x, y)
                    local new_x = math.floor(tonumber(x) * scale_x)
                    local new_y = math.floor(tonumber(y) * scale_y)
                    return new_x .. " " .. new_y
                end)
                return "\\clip(m " .. scaled_shape .. ")"
            end)

            -- Scale font size (\fs)
            line.text = line.text:gsub("\\fs(%d+%.?%d*)", function(fs)
                local new_fs = math.floor(tonumber(fs) * scale_y)
                return "\\fs" .. new_fs
            end)

            -- Scale bord, shad, blur, be based on scale_shad_blur_bord
            line.text = line.text
                :gsub("\\bord(%d+%.?%d*)", function(bord)
                    return "\\bord" .. math.floor(tonumber(bord) * scale_shad_blur_bord)
                end)
                :gsub("\\shad(%d+%.?%d*)", function(shad)
                    return "\\shad" .. math.floor(tonumber(shad) * scale_shad_blur_bord)
                end)
                :gsub("\\blur(%d+%.?%d*)", function(blur)
                    return "\\blur" .. math.floor(tonumber(blur) * scale_shad_blur_bord)
                end)
                :gsub("\\be(%d+%.?%d*)", function(be)
                    return "\\be" .. math.floor(tonumber(be) * scale_shad_blur_bord)
                end)
                -- Scale fscx, fscy, fsc, xbord, ybord, xshad, yshad based on their respective scale
                :gsub("\\fscx(%d+%.?%d*)", function(fscx)
                    return "\\fscx" .. math.floor(tonumber(fscx) * scale_x)
                end)
                :gsub("\\fscy(%d+%.?%d*)", function(fscy)
                    return "\\fscy" .. math.floor(tonumber(fscy) * scale_y)
                end)
                :gsub("\\fsc(%d+%.?%d*)", function(fsc)
                    return "\\fsc" .. math.floor(tonumber(fsc) * scale_y)
                end)
                :gsub("\\xbord(%d+%.?%d*)", function(xbord)
                    return "\\xbord" .. math.floor(tonumber(xbord) * scale_x)
                end)
                :gsub("\\ybord(%d+%.?%d*)", function(ybord)
                    return "\\ybord" .. math.floor(tonumber(ybord) * scale_y)
                end)
                :gsub("\\xshad(%d+%.?%d*)", function(xshad)
                    return "\\xshad" .. math.floor(tonumber(xshad) * scale_x)
                end)
                :gsub("\\yshad(%d+%.?%d*)", function(yshad)
                    return "\\yshad" .. math.floor(tonumber(yshad) * scale_y)
                end)

            subtitles[i] = line
        end
    end

    -- Step 2: Remove unused styles
    -- Collect all used styles from the dialogue lines
    local used_styles = {}
    for i = 1, #subtitles do
        local line = subtitles[i]
        if line.class == "dialogue" then
            used_styles[line.style] = true
        end
    end

    -- Remove unused styles
    for i = #subtitles, 1, -1 do
        local line = subtitles[i]
        if line.class == "style" then
            if not used_styles[line.name] then
                aegisub.log("Removing unused style: " .. line.name .. "\n")
                subtitles.delete(i)  -- Correctly using subtitles.delete to remove unused styles
            end
        end
    end

    -- Notify the user
    aegisub.set_undo_point("Transform Resolution to 720p and Remove Unused Styles")
end

-- Register the automation in Aegisub
aegisub.register_macro(script_name, script_description, transform_resolution)
