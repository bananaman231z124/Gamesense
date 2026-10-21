--[[
    LegendUI
    A tabbed UI library with draggable sections.

    Elements: Toggle (with keybind / colour), Button, Slider, Dropdown,
    MultiDropdown, Colorpicker, Textbox, Keybind, Image, Label, Separator.

    HUD: Keybind List and Watermark (window:CreateKeybindList / window:CreateWatermark).

    Sections (boxes) can be dragged anywhere, including off the window.
    Dropping one back over the window returns it to its original slot.

    Running the script again removes every trace of the previous run.

    Usage:
        local LegendUI = loadstring(readfile("LegendUI.lua"))()
        local window = LegendUI:CreateWindow({
            Title = "LegendUI",
            PatternColor = Color3.fromRGB(120, 80, 255),
            PatternStyle = "Stars",
            PatternAnimation = "PulseDrift",
        })

        local keybinds = window:CreateKeybindList({ Title = "Active Keybinds" })
        local watermark = window:CreateWatermark({ Title = "LegendUI" })

    PatternStyle: Dots, Circles, Squares, Diamonds, Crosses, Lines, Rings, Stars, Text
    PatternText: Single repeating text (default: "nilhub is pasted")
    PatternTexts: List of separate text strings or tables with Text, Color, TextSize, Transparency
    PatternAnimation: None, Pulse, Drift, PulseDrift, Rotate
]]

local GENV = (getgenv and getgenv()) or _G
local CLEANUP_KEY = "__legendui_cleanup"
local OWNER_ATTRIBUTE = "LegendUIOwner"

-- tear down the previous run before anything new is created
local previous_cleanup = GENV[CLEANUP_KEY]
if previous_cleanup then
    pcall(previous_cleanup)
    GENV[CLEANUP_KEY] = nil
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local StatsService = game:GetService("Stats")

local LocalPlayer = Players.LocalPlayer

----------------------------------------------------------
-- THEME
----------------------------------------------------------

local THEME = {
    window = Color3.fromRGB(24, 24, 28),
    divider = Color3.fromRGB(40, 40, 47),
    card = Color3.fromRGB(30, 30, 35),
    card_stroke = Color3.fromRGB(46, 46, 54),
    field = Color3.fromRGB(38, 38, 44),
    field_hover = Color3.fromRGB(49, 49, 57),
    popup = Color3.fromRGB(28, 28, 33),
    selected = Color3.fromRGB(40, 40, 47),
    text = Color3.fromRGB(242, 242, 246),
    text_dim = Color3.fromRGB(150, 150, 160),
    accent = Color3.fromRGB(52, 199, 89),
    pattern_color = Color3.fromRGB(52, 199, 89),
}

local FONT = Enum.Font.GothamMedium
local FONT_BOLD = Enum.Font.GothamBold

local TWEEN_FAST = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_MEDIUM = TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local TWEEN_POP = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local SIDEBAR_WIDTH = 176
local TABBAR_HEIGHT = 48
local COLUMN_GAP = 14

----------------------------------------------------------
-- TYPES
----------------------------------------------------------

type Maid = {
    connect: (RBXScriptSignal, (...any) -> ()) -> RBXScriptConnection,
    add: (any) -> any,
    clean: () -> (),
}

type KeyBinding = {
    get_key: () -> Enum.KeyCode?,
    on_press: () -> (),
    on_release: (() -> ())?,
}

type ActiveDrag = {
    start: Vector2,
    on_move: (Vector2, Vector2) -> (),
    on_end: (() -> ())?,
}

----------------------------------------------------------
-- MAID
----------------------------------------------------------

local function new_maid(): Maid
    local items: { any } = {}
    local maid: any = {}

    function maid.connect(signal: RBXScriptSignal, handler: (...any) -> ())
        local connection = signal:Connect(handler)
        table.insert(items, connection)
        return connection
    end

    function maid.add(item: any)
        table.insert(items, item)
        return item
    end

    function maid.clean()
        local pending = items
        items = {}

        for _, item in pending do
            local kind = typeof(item)

            if kind == "RBXScriptConnection" then
                item:Disconnect()
            elseif kind == "Instance" then
                item:Destroy()
            elseif kind == "function" then
                pcall(item)
            elseif kind == "thread" then
                pcall(task.cancel, item)
            end
        end
    end

    return maid
end

local root_maid = new_maid()

GENV[CLEANUP_KEY] = function()
    root_maid.clean()
end

----------------------------------------------------------
-- HELPERS
----------------------------------------------------------

local function safe_call(callback: ((...any) -> ())?, ...: any)
    if not callback then
        return
    end

    local ok, err = pcall(callback, ...)
    if not ok then
        warn("[LegendUI] callback error: " .. tostring(err))
    end
end

local function tween(instance: Instance, info: TweenInfo, properties: { [string]: any }): Tween
    local playing = TweenService:Create(instance, info, properties)
    playing:Play()
    return playing
end

-- properties are applied first and Parent last, which is cheaper than parenting early
local function create(class_name: string, properties: { [string]: any }?, children: { Instance }?): any
    local instance = Instance.new(class_name)
    local parent = nil

    for key, value in properties or {} do
        if key == "Parent" then
            parent = value
        else
            instance[key] = value
        end
    end

    for _, child in children or {} do
        child.Parent = instance
    end

    if parent then
        instance.Parent = parent
    end

    return instance
end

local function corner(radius: number): UICorner
    return create("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function stroke(color: Color3, thickness: number?, transparency: number?): UIStroke
    return create("UIStroke", {
        Color = color,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
end

local function padding(top: number, bottom: number, left: number, right: number): UIPadding
    return create("UIPadding", {
        PaddingTop = UDim.new(0, top),
        PaddingBottom = UDim.new(0, bottom),
        PaddingLeft = UDim.new(0, left),
        PaddingRight = UDim.new(0, right),
    })
end

local function list_layout(
    gap: number,
    direction: Enum.FillDirection?,
    horizontal: Enum.HorizontalAlignment?,
    vertical: Enum.VerticalAlignment?
): UIListLayout
    return create("UIListLayout", {
        Padding = UDim.new(0, gap),
        FillDirection = direction or Enum.FillDirection.Vertical,
        HorizontalAlignment = horizontal or Enum.HorizontalAlignment.Left,
        VerticalAlignment = vertical or Enum.VerticalAlignment.Top,
        SortOrder = Enum.SortOrder.LayoutOrder,
    })
end

local function is_press(input: InputObject): boolean
    return input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
end

-- Convert pointer coordinates into the same coordinate space used by this library's
-- ScreenGuis (IgnoreGuiInset = true / ScreenInsets.None). GetMouseLocation includes
-- the GUI inset on Roblox clients, so subtract it or the picker cursor sits too low.
local function pointer_position(input: InputObject): Vector2
    if input.UserInputType == Enum.UserInputType.Touch then
        local inset = GuiService:GetGuiInset()
        return Vector2.new(input.Position.X - inset.X, input.Position.Y - inset.Y)
    end

    local mouse = UserInputService:GetMouseLocation()
    local inset = GuiService:GetGuiInset()
    return Vector2.new(mouse.X - inset.X, mouse.Y - inset.Y)
end

local function center_inside(frame: GuiObject, container: GuiObject): boolean
    local center = frame.AbsolutePosition + frame.AbsoluteSize / 2
    local min = container.AbsolutePosition
    local max = min + container.AbsoluteSize

    return center.X >= min.X and center.X <= max.X and center.Y >= min.Y and center.Y <= max.Y
end

local function decimals_of(increment: number): number
    local count = 0
    local scaled = increment

    while count < 6 and math.abs(scaled - math.floor(scaled + 0.5)) > 1e-6 do
        scaled *= 10
        count += 1
    end

    return count
end

-- accepts either a config table or positional arguments in the order of `names`
local function parse_args(names: { string }, ...: any): { [string]: any }
    local first = ...
    if select("#", ...) == 1 and type(first) == "table" then
        return first
    end

    local values = table.pack(...)
    local config = {}

    for index, name in names do
        config[name] = values[index]
    end

    -- (text, default, callback) style shortcuts
    if config.Callback == nil then
        for _, name in names do
            if type(config[name]) == "function" then
                config.Callback = config[name]
                config[name] = nil
                break
            end
        end
    end

    return config
end

local KEY_ALIASES = {
    LeftShift = "LShift",
    RightShift = "RShift",
    LeftControl = "LCtrl",
    RightControl = "RCtrl",
    LeftAlt = "LAlt",
    RightAlt = "RAlt",
    Return = "Enter",
    Backspace = "Bksp",
    Escape = "Esc",
    Insert = "Ins",
    Delete = "Del",
    PageUp = "PgUp",
    PageDown = "PgDn",
    CapsLock = "Caps",
    Zero = "0",
    One = "1",
    Two = "2",
    Three = "3",
    Four = "4",
    Five = "5",
    Six = "6",
    Seven = "7",
    Eight = "8",
    Nine = "9",
}

local function key_name(key: Enum.KeyCode?): string
    if not key then
        return "None"
    end

    return KEY_ALIASES[key.Name] or key.Name
end

local function color_to_hex(color: Color3): string
    return string.format(
        "#%02X%02X%02X",
        math.floor(color.R * 255 + 0.5),
        math.floor(color.G * 255 + 0.5),
        math.floor(color.B * 255 + 0.5)
    )
end

local function hex_to_color(text: string): Color3?
    local hex = text:gsub("#", ""):gsub("%s", "")
    if not hex:match("^%x%x%x%x%x%x$") then
        return nil
    end

    return Color3.fromRGB(
        tonumber(hex:sub(1, 2), 16) :: number,
        tonumber(hex:sub(3, 4), 16) :: number,
        tonumber(hex:sub(5, 6), 16) :: number
    )
end

-- puts the gui in the safest parent the executor offers
local function mount_gui(gui: ScreenGui)
    gui:SetAttribute(OWNER_ATTRIBUTE, true)

    pcall(function()
        if syn and syn.protect_gui then
            syn.protect_gui(gui)
        end
    end)

    local parents = {}

    pcall(function()
        if gethui then
            table.insert(parents, gethui())
        end
    end)

    table.insert(parents, CoreGui)

    local player_gui = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if player_gui then
        table.insert(parents, player_gui)
    end

    for _, parent in parents do
        local ok = pcall(function()
            gui.Parent = parent
        end)

        if ok and gui.Parent == parent then
            return
        end
    end
end

-- removes guis left behind by runs whose cleanup function was lost
local function purge_stale_guis()
    local parents = { CoreGui }

    local player_gui = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if player_gui then
        table.insert(parents, player_gui)
    end

    pcall(function()
        if gethui then
            table.insert(parents, gethui())
        end
    end)

    for _, parent in parents do
        pcall(function()
            for _, child in parent:GetChildren() do
                if child:GetAttribute(OWNER_ATTRIBUTE) then
                    child:Destroy()
                end
            end
        end)
    end
end

purge_stale_guis()

----------------------------------------------------------
-- INPUT: DRAGGING, KEYBINDS, KEY CAPTURE
----------------------------------------------------------

local active_drag: ActiveDrag? = nil
local key_bindings: { [KeyBinding]: boolean } = {}
local key_capture: ((InputObject) -> ())? = nil

local function finish_drag()
    local drag = active_drag
    active_drag = nil

    if drag and drag.on_end then
        safe_call(drag.on_end)
    end
end

local function start_drag(input: InputObject, on_move: (Vector2, Vector2) -> (), on_end: (() -> ())?)
    if active_drag then
        finish_drag()
    end

    active_drag = {
        start = pointer_position(input),
        on_move = on_move,
        on_end = on_end,
    }
end

local function register_binding(binding: KeyBinding)
    key_bindings[binding] = true
end

root_maid.connect(UserInputService.InputChanged, function(input: InputObject)
    local drag = active_drag
    if not drag then
        return
    end

    local kind = input.UserInputType
    if kind ~= Enum.UserInputType.MouseMovement and kind ~= Enum.UserInputType.Touch then
        return
    end

    safe_call(drag.on_move, pointer_position(input), drag.start)
end)

root_maid.connect(UserInputService.InputEnded, function(input: InputObject)
    if active_drag and is_press(input) then
        finish_drag()
    end

    if input.UserInputType ~= Enum.UserInputType.Keyboard then
        return
    end

    for binding in key_bindings do
        if binding.on_release and binding.get_key() == input.KeyCode then
            safe_call(binding.on_release)
        end
    end
end)

root_maid.connect(UserInputService.InputBegan, function(input: InputObject, processed: boolean)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then
        return
    end

    -- a keybind button is waiting for the next key
    local capture = key_capture
    if capture then
        key_capture = nil
        capture(input)
        return
    end

    if processed then
        return
    end

    for binding in key_bindings do
        if binding.get_key() == input.KeyCode then
            safe_call(binding.on_press)
        end
    end
end)

root_maid.add(function()
    active_drag = nil
    key_capture = nil
    table.clear(key_bindings)
end)

----------------------------------------------------------
-- CLASSES
----------------------------------------------------------

local Library = { Version = "1.1.0" }

local Window = {}
Window.__index = Window

local Nav = {}
Nav.__index = Nav

local Page = {}
Page.__index = Page

local Column = {}
Column.__index = Column

local Box = {}
Box.__index = Box

----------------------------------------------------------
-- SHARED CONTROLS
----------------------------------------------------------

local function new_right(row: Frame): Frame
    return create("Frame", {
        Name = "Right",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(0, 22),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        ZIndex = 3,
        Parent = row,
    }, {
        list_layout(6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center),
    })
end

local function new_label(parent: Instance, text: string, properties: { [string]: any }?): TextLabel
    local label = create("TextLabel", {
        BackgroundTransparency = 1,
        Text = text,
        Font = FONT,
        TextSize = 13,
        TextColor3 = THEME.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })

    for key, value in properties or {} do
        label[key] = value
    end

    label.Parent = parent
    return label
end

-- a small button that waits for a key press. Escape and Backspace clear the bind
local function build_keybind_button(parent: Instance, initial: Enum.KeyCode?, on_change: ((Enum.KeyCode?) -> ())?)
    local key = initial
    local listening = false
    local control: any = {}

    local button = create("TextButton", {
        Name = "Keybind",
        Size = UDim2.fromOffset(0, 20),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = THEME.field,
        AutoButtonColor = false,
        Font = FONT,
        TextSize = 11,
        TextColor3 = THEME.text_dim,
        Text = key_name(key),
        Parent = parent,
    }, {
        corner(4),
        stroke(THEME.card_stroke),
        padding(0, 0, 7, 7),
    })

    local function refresh()
        button.Text = listening and "..." or key_name(key)
        tween(button, TWEEN_FAST, { TextColor3 = listening and THEME.accent or THEME.text_dim })
    end

    function control.get(): Enum.KeyCode?
        return key
    end

    function control.set(new_key: Enum.KeyCode?, silent: boolean?)
        key = new_key
        listening = false
        refresh()

        if not silent then
            safe_call(on_change, key)
        end
    end

    button.MouseButton1Click:Connect(function()
        if listening then
            listening = false
            key_capture = nil
            refresh()
            return
        end

        listening = true
        refresh()

        key_capture = function(input: InputObject)
            if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.Backspace then
                control.set(nil)
            else
                control.set(input.KeyCode)
            end
        end
    end)

    button.MouseButton2Click:Connect(function()
        control.set(nil)
    end)

    control.button = button
    return control
end

-- Shared colour copied from any swatch; right-click another swatch to paste it.
local copied_swatch_color: Color3? = nil

-- a colour swatch that opens the colour picker popup
local function build_swatch(parent: Instance, window: any, initial: Color3, on_change: ((Color3) -> ())?)
    local color = initial
    local control: any = {}

    local swatch = create("TextButton", {
        Name = "Swatch",
        Size = UDim2.fromOffset(24, 14),
        BackgroundColor3 = color,
        Text = "",
        AutoButtonColor = false,
        Parent = parent,
    }, {
        corner(4),
        stroke(Color3.new(1, 1, 1), 1, 0.85),
    })

    function control.get(): Color3
        return color
    end

    function control.set(new_color: Color3, silent: boolean?, instant: boolean?)
        color = new_color

        if instant then
            swatch.BackgroundColor3 = color
        else
            tween(swatch, TWEEN_FAST, { BackgroundColor3 = color })
        end

        if not silent then
            safe_call(on_change, color)
        end
    end

    swatch.MouseButton1Click:Connect(function()
        window:_open_color_popup(swatch, control.get, function(picked: Color3)
            control.set(picked, false, true)
        end)
    end)

    -- Right-click a swatch to copy its colour or paste a previously copied one.
    swatch.MouseButton2Click:Connect(function()
        window:_open_popup(swatch, Vector2.new(132, 62), "right", function(popup, close)
            local function menu_button(text: string, y: number, enabled: boolean, callback: () -> ())
                local button = create("TextButton", {
                    Name = text:gsub("%s+", ""),
                    Position = UDim2.fromOffset(6, y),
                    Size = UDim2.new(1, -12, 0, 24),
                    BackgroundColor3 = THEME.field,
                    TextColor3 = enabled and THEME.text or THEME.text_dim,
                    Text = text,
                    Font = FONT,
                    TextSize = 12,
                    AutoButtonColor = enabled,
                    Active = enabled,
                    Parent = popup,
                }, { corner(5) })
                button.MouseButton1Click:Connect(function()
                    if enabled then
                        callback()
                        close()
                    end
                end)
            end

            menu_button("Copy colour", 6, true, function()
                copied_swatch_color = control.get()
            end)
            menu_button("Paste colour", 32, copied_swatch_color ~= nil, function()
                if copied_swatch_color then
                    control.set(copied_swatch_color, false, true)
                end
            end)
        end)
    end)

    control.button = swatch
    return control
end

----------------------------------------------------------
-- POPUPS
----------------------------------------------------------

-- opens one popup at a time below (or above) the anchor.
-- build(popup, close) fills it. The popup grows open and shrinks closed.
function Window:_open_popup(
    anchor: GuiObject,
    size: Vector2,
    align: string,
    build: (Frame, () -> ()) -> (),
    on_close: (() -> ())?
)
    self:_close_popup()

    local maid = new_maid()
    local closing = false

    local blocker = create("TextButton", {
        Name = "Blocker",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 1,
        Parent = self.overlay,
    })

    local popup = create("Frame", {
        Name = "Popup",
        Size = UDim2.fromOffset(size.X, 0),
        BackgroundColor3 = THEME.popup,
        ClipsDescendants = true,
        ZIndex = 2,
        Parent = self.overlay,
    }, {
        corner(8),
        stroke(THEME.card_stroke),
    })

    maid.add(blocker)
    maid.add(popup)

    local function close()
        if closing then
            return
        end

        closing = true

        if self.popup_close == close then
            self.popup_close = nil
        end

        blocker.Visible = false
        tween(popup, TWEEN_FAST, { Size = UDim2.fromOffset(size.X, 0) })
        safe_call(on_close)

        task.delay(0.18, function()
            maid.clean()
        end)
    end

    local viewport = self.overlay.AbsoluteSize
    local origin = anchor.AbsolutePosition
    local anchor_size = anchor.AbsoluteSize
    local below_end = origin.Y + anchor_size.Y + 4 + size.Y
    local above = below_end > viewport.Y - 4 and origin.Y - size.Y - 4 > 4

    local function reposition()
        if not anchor:IsDescendantOf(game) then
            close()
            return
        end

        local position = anchor.AbsolutePosition
        local extent = anchor.AbsoluteSize
        local x = align == "right" and (position.X + extent.X - size.X) or position.X
        x = math.clamp(x, 4, math.max(viewport.X - size.X - 4, 4))

        local y = position.Y + extent.Y + 4
        if above then
            y = position.Y - popup.Size.Y.Offset - 4
        end

        popup.Position = UDim2.fromOffset(x, y)
    end

    reposition()
    maid.connect(RunService.RenderStepped, reposition)
    blocker.MouseButton1Click:Connect(close)

    self.popup_close = close

    build(popup, close)
    tween(popup, TWEEN_MEDIUM, { Size = UDim2.fromOffset(size.X, size.Y) })
end

function Window:_close_popup()
    local close = self.popup_close
    if close then
        close()
    end
end

-- options, is_selected(option), on_pick(option), keep_open, multi, on_close
function Window:_open_list_popup(field: GuiObject, config: { [string]: any }, row: Frame?, top: number?)
    local options = config.options
    local item_height = 26
    local searchable = config.searchable == true
    local search_height = searchable and 32 or 0
    local height = math.clamp(#options * item_height + 8, 34, 200) + search_height
    local width = math.max(field.AbsoluteSize.X, 120)

    -- builds the option buttons into `list` (shared by inline + floating modes)
    local function build_items(list: ScrollingFrame, close: () -> ())
        local refreshers = {}

        for index, option in options do
            local option_text = tostring(option)
            local item = create("TextButton", {
                Name = tostring(option),
                Size = UDim2.new(1, 0, 0, item_height),
                BackgroundColor3 = THEME.field_hover,
                BackgroundTransparency = 1,
                Text = "",
                AutoButtonColor = false,
                LayoutOrder = index,
                Parent = list,
            }, { corner(5) })

            local text_x = config.multi and 28 or 10

            local label = new_label(item, option_text, {
                Position = UDim2.fromOffset(text_x, 0),
                Size = UDim2.new(1, -text_x - 8, 1, 0),
                TextColor3 = THEME.text_dim,
                RichText = true,
            })

            local mark = create("Frame", {
                Name = "Mark",
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = config.multi and UDim2.fromOffset(16, item_height / 2) or UDim2.new(1, -14, 0.5, 0),
                Size = UDim2.fromOffset(0, 0),
                BackgroundColor3 = THEME.accent,
                Parent = item,
            }, { corner(config.multi and 3 or 4) })

            local mark_size = config.multi and 12 or 6

            local function refresh()
                local selected = config.is_selected(option)

                tween(label, TWEEN_FAST, {
                    TextColor3 = selected and THEME.text or THEME.text_dim,
                })

                tween(mark, TWEEN_POP, {
                    Size = selected and UDim2.fromOffset(mark_size, mark_size) or UDim2.fromOffset(0, 0),
                })
            end

            table.insert(refreshers, refresh)
            refresh()
            item:SetAttribute("SearchText", option_text:lower())

            item.MouseEnter:Connect(function()
                tween(item, TWEEN_FAST, { BackgroundTransparency = 0 })
            end)

            item.MouseLeave:Connect(function()
                tween(item, TWEEN_FAST, { BackgroundTransparency = 1 })
            end)

            item.MouseButton1Click:Connect(function()
                config.on_pick(option)

                if config.keep_open then
                    for _, refresh_item in refreshers do
                        refresh_item()
                    end
                else
                    close()
                end
            end)
        end
    end

    local function new_list(parent: Instance, size: UDim2, position: UDim2?): ScrollingFrame
        return create("ScrollingFrame", {
            Name = "List",
            Position = position or UDim2.new(),
            Size = size,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = THEME.card_stroke,
            CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            Parent = parent,
        }, {
            padding(4, 4, 4, 4),
            list_layout(0),
        })
    end

    ------------------------------------------------------
    -- inline mode: grows the row and pushes the rest down
    ------------------------------------------------------
    if row then
        self:_close_popup() -- only one dropdown open at a time

        local maid = new_maid()
        local closing = false

        local field_bottom = (top or 0) + field.Size.Y.Offset
        local base_height = field_bottom
        local list_top = field_bottom + 4

        -- the card that holds the options
        local holder = create("Frame", {
            Name = "InlineDropdown",
            Position = UDim2.fromOffset(0, list_top),
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundColor3 = THEME.popup,
            BorderSizePixel = 0,
            ClipsDescendants = true,
            Parent = row,
        }, {
            corner(6),
            stroke(THEME.card_stroke),
        })
        maid.add(holder)

        local list = new_list(holder, UDim2.new(1, 0, 1, -search_height), UDim2.fromOffset(0, search_height))
        local search_box = nil
        if searchable then
            search_box = create("TextBox", { Name = "Search", Position = UDim2.fromOffset(6, 5), Size = UDim2.new(1, -12, 0, 22), BackgroundColor3 = THEME.field, TextColor3 = THEME.text, PlaceholderText = "Search options...", PlaceholderColor3 = THEME.text_dim, Text = "", ClearTextOnFocus = false, Font = FONT, TextSize = 12, ZIndex = 4, Parent = holder }, { corner(5), padding(0, 0, 7, 7) })
            search_box:GetPropertyChangedSignal("Text"):Connect(function()
                local query = search_box.Text:lower()
                for _, item in ipairs(list:GetChildren()) do
                    if item:IsA("TextButton") then
                        local value = item:GetAttribute("SearchText") or ""
                        item.Visible = query == "" or string.find(value, query, 1, true) ~= nil
                        local label = item:FindFirstChildWhichIsA("TextLabel")
                        if label then
                            local raw = item.Name
                            local start_at, end_at = string.find(raw:lower(), query, 1, true)
                            if query ~= "" and start_at then
                                label.Text = string.sub(raw, 1, start_at - 1) .. '<font color="#34C759">' .. string.sub(raw, start_at, end_at) .. '</font>' .. string.sub(raw, end_at + 1)
                            else label.Text = raw end
                        end
                    end
                end
            end)
        end

        local function resize_row(target: number, info: TweenInfo)
            tween(row, info, { Size = UDim2.new(1, 0, 0, target) })
        end

        local function close()
            if closing then
                return
            end

            closing = true

            if self.popup_close == close then
                self.popup_close = nil
            end

            tween(holder, TWEEN_FAST, { Size = UDim2.new(1, 0, 0, 0) })
            resize_row(base_height, TWEEN_FAST)
            safe_call(config.on_close)

            task.delay(0.2, function()
                maid.clean()
            end)
        end

        -- clicking anywhere outside the field / list closes it
        maid.connect(UserInputService.InputBegan, function(input: InputObject)
            if closing or not is_press(input) then
                return
            end

            local point = pointer_position(input)

            local function inside(gui: GuiObject): boolean
                local position = gui.AbsolutePosition
                local size = gui.AbsoluteSize
                return point.X >= position.X
                    and point.X <= position.X + size.X
                    and point.Y >= position.Y
                    and point.Y <= position.Y + size.Y
            end

            if not inside(holder) and not inside(field) then
                close()
            end
        end)

        self.popup_close = close
        build_items(list, close)

        tween(holder, TWEEN_MEDIUM, { Size = UDim2.new(1, 0, 0, height) })
        resize_row(list_top + height, TWEEN_MEDIUM)

        return close
    end

    ------------------------------------------------------
    -- floating fallback (no row supplied)
    ------------------------------------------------------
    self:_open_popup(field, Vector2.new(width, height), "left", function(popup, close)
        local list = new_list(popup, UDim2.new(1, 0, 1, -search_height), UDim2.fromOffset(0, search_height))
        if searchable then
            local search_box = create("TextBox", { Name = "Search", Position = UDim2.fromOffset(6, 5), Size = UDim2.new(1, -12, 0, 22), BackgroundColor3 = THEME.field, TextColor3 = THEME.text, PlaceholderText = "Search options...", PlaceholderColor3 = THEME.text_dim, Text = "", ClearTextOnFocus = false, Font = FONT, TextSize = 12, ZIndex = 4, Parent = popup }, { corner(5), padding(0, 0, 7, 7) })
            search_box:GetPropertyChangedSignal("Text"):Connect(function()
                local query = search_box.Text:lower()
                for _, item in ipairs(list:GetChildren()) do if item:IsA("TextButton") then item.Visible = query == "" or string.find((item:GetAttribute("SearchText") or ""), query, 1, true) ~= nil end end
            end)
        end
        build_items(list, close)
    end, config.on_close)

    return self.popup_close
end

-- saturation/value square, hue bar, hex box, and explicit Apply/Cancel controls.
-- Colour edits are previewed inside the popup and committed only when Apply is clicked.
function Window:_open_color_popup(anchor: GuiObject, get_color: () -> Color3, set_color: (Color3) -> ())
    local hue, saturation, value = get_color():ToHSV()
    local original_color = get_color()

    self:_open_popup(anchor, Vector2.new(200, 206), "right", function(popup, close)
        local square = create("TextButton", {
            Name = "Square",
            Position = UDim2.fromOffset(8, 8),
            Size = UDim2.fromOffset(184, 100),
            BackgroundColor3 = Color3.fromHSV(hue, 1, 1),
            Text = "",
            AutoButtonColor = false,
            ClipsDescendants = true,
            Active = true,
            Parent = popup,
        }, { corner(4) })

        create("Frame", {
            Name = "White",
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
            Active = false,
            Parent = square,
        }, {
            create("UIGradient", {
                Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0),
                    NumberSequenceKeypoint.new(1, 1),
                }),
            }),
        })

        create("Frame", {
            Name = "Black",
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Color3.new(0, 0, 0),
            BorderSizePixel = 0,
            Active = false,
            Parent = square,
        }, {
            create("UIGradient", {
                Rotation = 90,
                Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 1),
                    NumberSequenceKeypoint.new(1, 0),
                }),
            }),
        })

        local square_cursor = create("Frame", {
            Name = "Cursor",
            AnchorPoint = Vector2.new(0.5, 0.5),
            Size = UDim2.fromOffset(10, 10),
            BackgroundTransparency = 1,
            Active = false,
            Parent = square,
        }, {
            corner(5),
            stroke(Color3.new(1, 1, 1), 2),
        })

        local hue_bar = create("TextButton", {
            Name = "Hue",
            Position = UDim2.fromOffset(8, 116),
            Size = UDim2.fromOffset(184, 12),
            BackgroundColor3 = Color3.new(1, 1, 1),
            Text = "",
            AutoButtonColor = false,
            Active = true,
            Parent = popup,
        }, {
            corner(6),
            create("UIGradient", {
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
                    ColorSequenceKeypoint.new(1 / 6, Color3.fromHSV(1 / 6, 1, 1)),
                    ColorSequenceKeypoint.new(2 / 6, Color3.fromHSV(2 / 6, 1, 1)),
                    ColorSequenceKeypoint.new(3 / 6, Color3.fromHSV(3 / 6, 1, 1)),
                    ColorSequenceKeypoint.new(4 / 6, Color3.fromHSV(4 / 6, 1, 1)),
                    ColorSequenceKeypoint.new(5 / 6, Color3.fromHSV(5 / 6, 1, 1)),
                    ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1)),
                }),
            }),
        })

        local hue_cursor = create("Frame", {
            Name = "Cursor",
            AnchorPoint = Vector2.new(0.5, 0.5),
            Size = UDim2.fromOffset(6, 16),
            BackgroundColor3 = Color3.new(1, 1, 1),
            Active = false,
            Parent = hue_bar,
        }, {
            corner(3),
            stroke(Color3.new(0, 0, 0), 1, 0.6),
        })

        local hex_box = create("TextBox", {
            Name = "Hex",
            Position = UDim2.fromOffset(8, 144),
            Size = UDim2.fromOffset(184, 24),
            BackgroundColor3 = THEME.field,
            Font = FONT,
            TextSize = 13,
            TextColor3 = THEME.text,
            ClearTextOnFocus = false,
            Text = "",
            Parent = popup,
        }, {
            corner(5),
            stroke(THEME.card_stroke),
        })

        local function current_color(): Color3
            return Color3.fromHSV(hue, saturation, value)
        end

        local function refresh()
            square.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
            square_cursor.Position = UDim2.fromScale(saturation, 1 - value)
            hue_cursor.Position = UDim2.fromScale(hue, 0.5)

            if not hex_box:IsFocused() then
                hex_box.Text = color_to_hex(current_color())
            end
        end

        -- Use the current pointer coordinates for every update. Clamping prevents
        -- the cursor jumping outside the picker if the mouse moves quickly.
        local function update_square(position: Vector2)
            local absolute = square.AbsolutePosition
            local size = square.AbsoluteSize
            if size.X <= 0 or size.Y <= 0 then
                return
            end
            local relative = (position - absolute) / size
            saturation = math.clamp(relative.X, 0, 1)
            value = 1 - math.clamp(relative.Y, 0, 1)
            refresh()
        end

        local function update_hue(position: Vector2)
            local width = hue_bar.AbsoluteSize.X
            if width <= 0 then
                return
            end
            hue = math.clamp((position.X - hue_bar.AbsolutePosition.X) / width, 0, 1)
            refresh()
        end

        square.InputBegan:Connect(function(input: InputObject)
            if not is_press(input) then
                return
            end
            update_square(pointer_position(input))
            start_drag(input, function(position: Vector2)
                update_square(position)
            end)
        end)

        hue_bar.InputBegan:Connect(function(input: InputObject)
            if not is_press(input) then
                return
            end
            update_hue(pointer_position(input))
            start_drag(input, function(position: Vector2)
                update_hue(position)
            end)
        end)

        hex_box.FocusLost:Connect(function()
            local parsed = hex_to_color(hex_box.Text)
            if parsed then
                hue, saturation, value = parsed:ToHSV()
            end
            refresh()
        end)

        local cancel_button = create("TextButton", {
            Name = "Cancel",
            Position = UDim2.fromOffset(8, 174),
            Size = UDim2.fromOffset(88, 24),
            BackgroundColor3 = THEME.field,
            TextColor3 = THEME.text,
            Text = "Cancel",
            Font = FONT,
            TextSize = 12,
            AutoButtonColor = true,
            Parent = popup,
        }, { corner(5), stroke(THEME.card_stroke) })

        local apply_button = create("TextButton", {
            Name = "Apply",
            Position = UDim2.fromOffset(104, 174),
            Size = UDim2.fromOffset(88, 24),
            BackgroundColor3 = THEME.accent,
            TextColor3 = Color3.new(1, 1, 1),
            Text = "Confirm",
            Font = FONT,
            TextSize = 12,
            AutoButtonColor = true,
            Parent = popup,
        }, { corner(5) })

        cancel_button.MouseButton1Click:Connect(function()
            -- No changes have been committed, so closing is a true cancel.
            close()
        end)

        apply_button.MouseButton1Click:Connect(function()
            set_color(current_color())
            close()
        end)

        refresh()
    end)
end

----------------------------------------------------------
-- WINDOW
----------------------------------------------------------

function Library.CreateWindow(_library: any, config: { [string]: any }?)
    config = config or {}

    if config.Accent then
        THEME.accent = config.Accent
    end

    local pattern_color = config.PatternColor or THEME.pattern_color or THEME.accent
    local pattern_style = config.PatternStyle or "Stars"
    local pattern_animation = config.PatternAnimation or "None"
    local pattern_transparency = math.clamp(config.PatternTransparency or 0.88, 0, 1)
    local pattern_spacing = math.clamp(config.PatternSpacing or 24, 8, 80)
    local pattern_size = math.clamp(config.PatternSize or 2, 1, 12)
    local pattern_speed = math.clamp(config.PatternSpeed or 3, 0.5, 12)
    local pattern_text = tostring(config.PatternText or "nilhub is pasted")
    local pattern_text_size = math.clamp(config.PatternTextSize or math.max(10, pattern_size * 5), 8, 36)
    local pattern_texts = config.PatternTexts

    if type(pattern_texts) ~= "table" or #pattern_texts == 0 then
        pattern_texts = { pattern_text }
    end

    local self = setmetatable({}, Window)
    self.navs = {}
    self.selected_nav = nil
    self.visible = true
    self.toggle_key = config.ToggleKey or Enum.KeyCode.RightShift
    self.float_order = 0
    self.popup_close = nil
    self.button_gui = nil
    self.keybind_registry = {}
    self.keybind_list = nil
    self.watermark = nil
    self.elements = {}
    self.recent_actions = {}
    self.profiles_folder = tostring(config.ConfigFolder or "LegendUI/Configs")
    self.config_name = tostring(config.ConfigName or "Default")
    self.auto_save = config.AutoSave == true
    self.auto_load = config.AutoLoad == true
    self.command_key = config.CommandKey or Enum.KeyCode.K
    self.command_palette = nil
    self.notifications = {}
    self.toast_gui = nil

    local camera = workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
    local requested = config.Size or Vector2.new(720, 560)
    local width = math.min(requested.X, viewport.X - 24)
    local height = math.min(requested.Y, viewport.Y - 24)

    local gui = create("ScreenGui", {
        Name = HttpService:GenerateGUID(false),
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 1000,
    })

    pcall(function()
        gui.ScreenInsets = Enum.ScreenInsets.None
    end)

    mount_gui(gui)
    root_maid.add(gui)
    self.gui = gui

    ------------------------------------------------------
    -- main frame
    ------------------------------------------------------

    local main = create("Frame", {
        Name = "Window",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(width, height),
        BackgroundColor3 = THEME.window,
        BorderSizePixel = 0,
        Active = true,
        ClipsDescendants = true,
        Parent = gui,
    }, {
        corner(8),
        stroke(THEME.divider),
    })

    ------------------------------------------------------
    -- configurable background pattern
    ------------------------------------------------------

    local background_pattern = create("Frame", {
        Name = "BackgroundPattern",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Active = false,
        ZIndex = 1,
        Parent = main,
    })

    local pattern_items = {}
    local pattern_star_labels = {}
    local pattern_text_labels = {}
    local pattern_tweens = {}

    local function add_pattern_shape(name: string, x: number, y: number, size_x: number, size_y: number, rotation: number?, round: boolean?)
        local shape = create("Frame", {
            Name = name,
            Position = UDim2.fromOffset(x, y),
            Size = UDim2.fromOffset(size_x, size_y),
            Rotation = rotation or 0,
            BackgroundColor3 = pattern_color,
            BackgroundTransparency = pattern_transparency,
            BorderSizePixel = 0,
            Active = false,
            ZIndex = 1,
            Parent = background_pattern,
        })

        if round then
            corner(math.max(1, math.floor(math.min(size_x, size_y) / 2))).Parent = shape
        end

        table.insert(pattern_items, shape)
        return shape
    end

    local shape_size = pattern_size
    local text_tile_width = 0
    local text_tile_height = pattern_text_size + 10
    local pattern_step_x = pattern_spacing
    local pattern_step_y = pattern_spacing

    if pattern_style == "Text" then
        -- Size every label for the longest phrase so separate labels never
        -- collide, even when PatternTexts contains phrases of different lengths.
        local longest_width = 0
        local largest_text_size = pattern_text_size
        for _, entry in ipairs(pattern_texts) do
            local entry_text = type(entry) == "table" and (entry.Text or entry.text or pattern_text) or entry
            local entry_size = type(entry) == "table" and (entry.TextSize or entry.Size or pattern_text_size) or pattern_text_size
            entry_size = math.clamp(tonumber(entry_size) or pattern_text_size, 8, 36)
            largest_text_size = math.max(largest_text_size, entry_size)
            longest_width = math.max(longest_width, #tostring(entry_text) * entry_size * 0.62)
        end
        text_tile_width = math.ceil(longest_width + 16)
        text_tile_height = math.ceil(largest_text_size + 12)
        pattern_step_x = text_tile_width + pattern_spacing
        pattern_step_y = text_tile_height + pattern_spacing
    end

    -- Start at the top-left and extend past the right/bottom edges. Text labels
    -- use their own measured cell size rather than oversized overlapping tiles.
    for x = 0, width + pattern_step_x, pattern_step_x do
        for y = 0, height + pattern_step_y, pattern_step_y do
            if pattern_style == "Text" then
                -- Each cell gets its own TextLabel. Cycle through PatternTexts so
                -- every entry stays separate and multiple phrases can be mixed.
                -- Use the actual grid cell size; start_offset is not defined
                -- in this version of the pattern renderer.
                local cell_x = math.floor(x / math.max(1, pattern_step_x))
                local cell_y = math.floor(y / math.max(1, pattern_step_y))
                local text_index = ((cell_x + cell_y * 2) % #pattern_texts) + 1
                local text_entry = pattern_texts[text_index]
                local entry_text = text_entry
                local entry_color = pattern_color
                local entry_size = pattern_text_size
                local entry_transparency = math.clamp(pattern_transparency - 0.05, 0, 1)

                if type(text_entry) == "table" then
                    entry_text = text_entry.Text or text_entry.text or pattern_text
                    entry_color = text_entry.Color or text_entry.color or pattern_color
                    entry_size = math.clamp(text_entry.TextSize or text_entry.Size or pattern_text_size, 8, 36)
                    entry_transparency = math.clamp(text_entry.Transparency or pattern_transparency - 0.05, 0, 1)
                end

                local text_label = create("TextLabel", {
                    Name = "PatternText_" .. tostring(text_index),
                    Position = UDim2.fromOffset(x, y),
                    Size = UDim2.fromOffset(text_tile_width, text_tile_height),
                    BackgroundTransparency = 1,
                    BorderSizePixel = 0,
                    Text = tostring(entry_text),
                    TextColor3 = entry_color,
                    TextTransparency = entry_transparency,
                    TextSize = entry_size,
                    TextWrapped = false,
                    TextScaled = false,
                    Font = Enum.Font.GothamBold,
                    TextXAlignment = Enum.TextXAlignment.Center,
                    TextYAlignment = Enum.TextYAlignment.Center,
                    Rotation = ((math.floor(x / pattern_spacing) + math.floor(y / pattern_spacing)) % 3 - 1) * 8,
                    Active = false,
                    ZIndex = 1,
                    Parent = background_pattern,
                })
                table.insert(pattern_text_labels, text_label)
            elseif pattern_style == "Stars" then
                local star = create("TextLabel", {
                    Name = "PatternStar",
                    Position = UDim2.fromOffset(x - shape_size, y - shape_size),
                    Size = UDim2.fromOffset(shape_size * 4, shape_size * 4),
                    BackgroundTransparency = 1,
                    BorderSizePixel = 0,
                    Text = ((math.floor(x / pattern_spacing) + math.floor(y / pattern_spacing)) % 2 == 0) and "✦" or "✧",
                    TextColor3 = pattern_color,
                    TextTransparency = math.clamp(pattern_transparency - 0.08, 0, 1),
                    TextSize = math.max(8, shape_size * 4),
                    Font = Enum.Font.GothamBold,
                    TextXAlignment = Enum.TextXAlignment.Center,
                    TextYAlignment = Enum.TextYAlignment.Center,
                    Rotation = (math.floor(x + y) % 30) - 15,
                    Active = false,
                    ZIndex = 1,
                    Parent = background_pattern,
                })
                table.insert(pattern_star_labels, star)
            elseif pattern_style == "Circles" then
                add_pattern_shape("PatternCircle", x, y, shape_size * 2, shape_size * 2, 0, true)
            elseif pattern_style == "Squares" then
                add_pattern_shape("PatternSquare", x, y, shape_size * 2, shape_size * 2)
            elseif pattern_style == "Diamonds" then
                add_pattern_shape("PatternDiamond", x, y, shape_size * 2, shape_size * 2, 45)
            elseif pattern_style == "Crosses" then
                local arm = math.max(1, shape_size)
                add_pattern_shape("PatternCrossHorizontal", x - arm, y, arm * 2 + 1, arm)
                add_pattern_shape("PatternCrossVertical", x, y - arm, arm, arm * 2 + 1)
            elseif pattern_style == "Lines" then
                add_pattern_shape("PatternLine", x, y, shape_size, shape_size * 3, 0, true)
            elseif pattern_style == "Rings" then
                local ring = add_pattern_shape("PatternRing", x, y, shape_size * 3, shape_size * 3, 0, true)
                ring.BackgroundTransparency = 1
                local ring_stroke = stroke(pattern_color, math.max(1, shape_size / 2), pattern_transparency)
                ring_stroke.Parent = ring
            else
                add_pattern_shape("PatternDot", x, y, shape_size, shape_size, 0, true)
            end
        end
    end

    -- Stars use text glyphs so the sparkle effect works without requiring
    -- an externally hosted GIF or a Roblox-uploaded image asset.
    if pattern_style == "Stars" then
        for index, star in ipairs(pattern_star_labels) do
            local twinkle = TweenService:Create(star, TweenInfo.new(
                pattern_speed * 0.65,
                Enum.EasingStyle.Sine,
                Enum.EasingDirection.InOut,
                -1,
                true,
                (index % 17) * 0.06
            ), {
                TextTransparency = math.clamp(pattern_transparency + 0.08, 0, 0.95),
                Rotation = star.Rotation + ((index % 2 == 0) and 18 or -18),
            })
            table.insert(pattern_tweens, twinkle)
            twinkle:Play()
        end
    end

    if pattern_animation == "Pulse" or pattern_animation == "PulseDrift" then
        for index, text_label in ipairs(pattern_text_labels) do
            local base_transparency = text_label.TextTransparency
            local pulse_text = TweenService:Create(text_label, TweenInfo.new(
                pattern_speed * 1.4,
                Enum.EasingStyle.Sine,
                Enum.EasingDirection.InOut,
                -1,
                true,
                (index % 9) * 0.12
            ), {
                TextTransparency = math.clamp(base_transparency + 0.14, 0, 0.98),
            })
            table.insert(pattern_tweens, pulse_text)
            pulse_text:Play()
        end

        for index, shape in ipairs(pattern_items) do
            local pulse_target = shape
            local pulse_property = "BackgroundTransparency"
            if shape.Name == "PatternRing" then
                pulse_target = shape:FindFirstChildOfClass("UIStroke")
                pulse_property = "Transparency"
            end
            if pulse_target then
                local pulse = TweenService:Create(pulse_target, TweenInfo.new(
                    pattern_speed * 1.4,
                    Enum.EasingStyle.Sine,
                    Enum.EasingDirection.InOut,
                    -1,
                    true,
                    (index % 9) * 0.12
                ), {
                    [pulse_property] = math.clamp(pattern_transparency + 0.14, 0, 0.98),
                })
                table.insert(pattern_tweens, pulse)
                pulse:Play()
            end
        end
    end

    if pattern_animation == "Drift" or pattern_animation == "PulseDrift" then
        -- Move each text independently by a few pixels. The old whole-frame
        -- tween made the entire pattern slide back and forth abruptly.
        for index, text_label in ipairs(pattern_text_labels) do
            local original_position = text_label.Position
            local drift = TweenService:Create(text_label, TweenInfo.new(
                pattern_speed * 2.8,
                Enum.EasingStyle.Sine,
                Enum.EasingDirection.InOut,
                -1,
                true,
                (index % 11) * 0.09
            ), {
                Position = UDim2.fromOffset(original_position.X.Offset + ((index % 2 == 0) and 4 or -4), original_position.Y.Offset + ((index % 3 == 0) and 5 or -5)),
            })
            table.insert(pattern_tweens, drift)
            drift:Play()
        end
    elseif pattern_animation == "Rotate" then
        for index, text_label in ipairs(pattern_text_labels) do
            local rotation = TweenService:Create(text_label, TweenInfo.new(
                pattern_speed * 3,
                Enum.EasingStyle.Sine,
                Enum.EasingDirection.InOut,
                -1,
                true,
                (index % 9) * 0.1
            ), {
                Rotation = text_label.Rotation + ((index % 2 == 0) and 3 or -3),
            })
            table.insert(pattern_tweens, rotation)
            rotation:Play()
        end
    end

    if #pattern_tweens > 0 then
        root_maid.add(function()
            for _, pattern_tween in ipairs(pattern_tweens) do
                pcall(function()
                    pattern_tween:Cancel()
                    pattern_tween:Destroy()
                end)
            end
        end)
    end

    local scale = create("UIScale", {
        Name = "UserUIScale",
        Scale = 1,
        Parent = main
    })

    self.main = main
    self.scale = scale
    self.user_scale = scale

    ------------------------------------------------------
    -- sidebar
    ------------------------------------------------------

    local sidebar = create("Frame", {
        Name = "Sidebar",
        Size = UDim2.new(0, SIDEBAR_WIDTH, 1, 0),
        BackgroundTransparency = 1,
        Parent = main,
    })

    create("Frame", {
        Name = "Divider",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.fromScale(1, 0),
        Size = UDim2.new(0, 1, 1, 0),
        BackgroundColor3 = THEME.divider,
        BorderSizePixel = 0,
        Parent = sidebar,
    })

    local header = create("Frame", {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, 64),
        BackgroundTransparency = 1,
        Active = true,
        Parent = sidebar,
    })

    new_label(header, config.Title or "LegendUI", {
        Position = UDim2.fromOffset(18, 0),
        Size = UDim2.new(1, -36, 1, 0),
        Font = FONT_BOLD,
        TextSize = 18,
    })

    self.nav_list = create("Frame", {
        Name = "Navs",
        Position = UDim2.fromOffset(0, 64),
        Size = UDim2.new(1, 0, 1, -64 - 56),
        BackgroundTransparency = 1,
        Parent = sidebar,
    }, {
        padding(0, 0, 10, 10),
        list_layout(4),
    })

    local footer = create("Frame", {
        Name = "Footer",
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(1, 0, 0, 56),
        BackgroundTransparency = 1,
        Parent = sidebar,
    })

    create("Frame", {
        Name = "Line",
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = THEME.divider,
        BorderSizePixel = 0,
        Parent = footer,
    })

    new_label(footer, config.SubText or LocalPlayer.Name, {
        Position = UDim2.fromOffset(18, 12),
        Size = UDim2.new(1, -36, 0, 16),
        Font = FONT_BOLD,
        TextSize = 12,
    })

    new_label(footer, config.SubText2 or "session", {
        Position = UDim2.fromOffset(18, 30),
        Size = UDim2.new(1, -36, 0, 14),
        TextSize = 11,
        TextColor3 = THEME.text_dim,
    })

    ------------------------------------------------------
    -- content area
    ------------------------------------------------------

    local content = create("Frame", {
        Name = "Content",
        Position = UDim2.fromOffset(SIDEBAR_WIDTH, 0),
        Size = UDim2.new(1, -SIDEBAR_WIDTH, 1, 0),
        BackgroundTransparency = 1,
        Parent = main,
    })

    self.tabbar = create("Frame", {
        Name = "Tabs",
        Size = UDim2.new(1, 0, 0, TABBAR_HEIGHT),
        BackgroundTransparency = 1,
        Active = true,
        Parent = content,
    })

    self.underline = create("Frame", {
        Name = "Underline",
        Position = UDim2.fromOffset(0, 40),
        Size = UDim2.fromOffset(0, 2),
        BackgroundColor3 = THEME.text,
        BorderSizePixel = 0,
        Parent = self.tabbar,
    }, { corner(1) })

    self.pages_holder = create("Frame", {
        Name = "Pages",
        Position = UDim2.fromOffset(0, TABBAR_HEIGHT),
        Size = UDim2.new(1, 0, 1, -TABBAR_HEIGHT),
        BackgroundTransparency = 1,
        Parent = content,
    })

    ------------------------------------------------------
    -- layers above the window: floating sections, then popups
    ------------------------------------------------------

    -- Floating boxes live in their own ScreenGui so hiding the main window
    -- does not hide a box that has been dragged outside the window.
    local float_gui = create("ScreenGui", {
        Name = HttpService:GenerateGUID(false),
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 1001,
    })

    pcall(function()
        float_gui.ScreenInsets = Enum.ScreenInsets.None
    end)

    mount_gui(float_gui)
    root_maid.add(float_gui)
    self.float_gui = float_gui

    self.float_layer = create("Frame", {
        Name = "Floating",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        ZIndex = 10,
        Parent = float_gui,
    })

    self.overlay = create("Frame", {
        Name = "Overlay",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        ZIndex = 20,
        Parent = gui,
    })

    ------------------------------------------------------
    -- dragging the window by its header and tab bar
    ------------------------------------------------------

    local function make_window_handle(handle: GuiObject)
        handle.InputBegan:Connect(function(input: InputObject)
            if not is_press(input) then
                return
            end

            self:_close_popup()

            local origin = main.Position

            start_drag(input, function(position: Vector2, start: Vector2)
                local delta = position - start
                main.Position = UDim2.new(
                    origin.X.Scale,
                    origin.X.Offset + delta.X,
                    origin.Y.Scale,
                    origin.Y.Offset + delta.Y
                )
            end)
        end)
    end

    make_window_handle(header)
    make_window_handle(self.tabbar)

    ------------------------------------------------------
    -- menu key and open animation
    ------------------------------------------------------

    register_binding({
        get_key = function()
            return self.toggle_key
        end,
        on_press = function()
            self:Toggle()
        end,
    })

    tween(scale, TWEEN_MEDIUM, { Scale = 1 })
    self:EnableCommandPalette(self.command_key)
    if self.auto_load then task.defer(function() self:LoadConfig(self.config_name) end) end

    return self
end

-- Element registry powers global search, command actions, and profile serialization.
function Window:_register_element(element: any, label: string, page_name: string?, box_name: string?, id: string?)
    element.Label = label
    local base_id = tostring(id or (tostring(page_name or "Page") .. "/" .. tostring(box_name or "Section") .. "/" .. label))
    local candidate, suffix = base_id, 2
    local occupied = {}
    for _, existing in ipairs(self.elements) do occupied[existing.Id] = true end
    while occupied[candidate] do candidate = base_id .. "#" .. tostring(suffix); suffix += 1 end
    element.Id = candidate
    element.PageName = page_name or ""
    element.BoxName = box_name or ""
    table.insert(self.elements, element)
    if element.Set and not element._legendWrapped then
        local original_set = element.Set
        element.Set = function(control, ...)
            local result = original_set(control, ...)
            if self.auto_save and not self._loading_config then task.defer(function() self:SaveConfig() end) end
            return result
        end
        element._legendWrapped = true
    end
    return element
end

function Window:_record_action(text: string)
    table.insert(self.recent_actions, 1, { Text = text, Time = os.time() })
    while #self.recent_actions > 12 do table.remove(self.recent_actions) end
end

function Window:SetVisible(visible: boolean)
    if self.visible == visible then
        return
    end

    self.visible = visible
    self:_close_popup()

    if visible then
        self.gui.Enabled = true
        self.scale.Scale = self.user_scale.Scale
        return
    end

    self.gui.Enabled = false

    task.delay(0.16, function()
        if not self.visible then
            self.gui.Enabled = false
        end
    end)
end

function Window:Toggle()
    self:SetVisible(not self.visible)
end

-- Accepts either a multiplier (1.25) or a percentage number (125).
function Window:SetUIScale(value: number)
    local scale_value = value > 10 and value / 100 or value
    self.user_scale.Scale = math.clamp(scale_value, 0.5, 2.5)
end

function Window:GetUIScale(): number
    return self.user_scale.Scale
end

function Window:SetToggleKey(key: Enum.KeyCode)
    self.toggle_key = key
end

function Window:GetToggleKey(): Enum.KeyCode
    return self.toggle_key
end

-- a small round button that opens and closes the window (useful on mobile)
function Window:SetToggleButtonVisible(visible: boolean)
    if not visible then
        if self.button_gui then
            self.button_gui:Destroy()
            self.button_gui = nil
        end

        return
    end

    if self.button_gui then
        return
    end

    local button_gui = create("ScreenGui", {
        Name = HttpService:GenerateGUID(false),
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 999,
    })

    pcall(function()
        button_gui.ScreenInsets = Enum.ScreenInsets.None
    end)

    mount_gui(button_gui)
    root_maid.add(button_gui)
    self.button_gui = button_gui

    local button = create("TextButton", {
        Name = "Toggle",
        Position = UDim2.fromOffset(16, 64),
        Size = UDim2.fromOffset(40, 40),
        BackgroundColor3 = THEME.window,
        AutoButtonColor = false,
        Text = "L",
        Font = FONT_BOLD,
        TextSize = 18,
        TextColor3 = THEME.text,
        Parent = button_gui,
    }, {
        corner(20),
        stroke(THEME.card_stroke),
    })

    button.MouseEnter:Connect(function()
        tween(button, TWEEN_FAST, { BackgroundColor3 = THEME.field_hover })
    end)

    button.MouseLeave:Connect(function()
        tween(button, TWEEN_FAST, { BackgroundColor3 = THEME.window })
    end)

    button.MouseButton1Click:Connect(function()
        self:Toggle()
    end)
end

function Window:Destroy()
    self:_close_popup()

    if self.button_gui then
        self.button_gui:Destroy()
        self.button_gui = nil
    end

    if self.float_gui then
        self.float_gui:Destroy()
        self.float_gui = nil
    end

    if self.toast_gui then
        self.toast_gui:Destroy()
        self.toast_gui = nil
    end

    if self.keybind_list then
        self.keybind_list:Destroy()
    end

    if self.watermark then
        self.watermark:Destroy()
    end

    self.gui:Destroy()
end

----------------------------------------------------------
-- NAV TABS AND PAGE TABS
----------------------------------------------------------

function Window:AddNavTab(name: string)
    local nav = setmetatable({
        window = self,
        name = name,
        pages = {},
        selected_page = nil,
    }, Nav)

    nav.button = create("TextButton", {
        Name = name,
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = THEME.selected,
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Text = name,
        Font = FONT,
        TextSize = 14,
        TextColor3 = THEME.text_dim,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = #self.navs + 1,
        Parent = self.nav_list,
    }, {
        corner(6),
        padding(0, 0, 14, 8),
    })

    nav.strip = create("Frame", {
        Name = name .. "Tabs",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Visible = false,
        Parent = self.tabbar,
    }, {
        padding(8, 0, 12, 0),
        list_layout(4, Enum.FillDirection.Horizontal),
    })

    nav.button.MouseEnter:Connect(function()
        if self.selected_nav ~= nav then
            tween(nav.button, TWEEN_FAST, { TextColor3 = THEME.text })
        end
    end)

    nav.button.MouseLeave:Connect(function()
        if self.selected_nav ~= nav then
            tween(nav.button, TWEEN_FAST, { TextColor3 = THEME.text_dim })
        end
    end)

    nav.button.MouseButton1Click:Connect(function()
        if self.selected_nav ~= nav then
            self:_close_popup()
            self:_activate_nav(nav)
        end
    end)

    table.insert(self.navs, nav)

    if #self.navs == 1 then
        self:_activate_nav(nav)
    end

    return nav
end

function Window:AddPageTab(nav: any, name: string)
    return nav:AddPageTab(name)
end

function Nav:AddPageTab(name: string)
    local window = self.window

    local page = setmetatable({
        window = window,
        nav = self,
        name = name,
        columns = {},
    }, Page)

    page.button = create("TextButton", {
        Name = name,
        Size = UDim2.fromOffset(0, 30),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Text = name,
        Font = FONT,
        TextSize = 14,
        TextColor3 = THEME.text_dim,
        LayoutOrder = #self.pages + 1,
        Parent = self.strip,
    }, { padding(0, 0, 8, 8) })

    page.canvas = create("CanvasGroup", {
        Name = name,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        GroupTransparency = 1,
        Visible = false,
        Parent = window.pages_holder,
    })

    page.scroll = create("ScrollingFrame", {
        Name = "Scroll",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = THEME.card_stroke,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Parent = page.canvas,
    }, { padding(4, 16, 16, 16) })

    page.columns_frame = create("Frame", {
        Name = "Columns",
        -- ScrollingFrame has 16px left/right UIPadding; subtract both from
        -- the child width so the last column cannot spill past the content edge.
        Size = UDim2.new(1, -32, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = page.scroll,
    }, {
        list_layout(COLUMN_GAP, Enum.FillDirection.Horizontal),
    })

    page.button.MouseEnter:Connect(function()
        if self.selected_page ~= page then
            tween(page.button, TWEEN_FAST, { TextColor3 = THEME.text })
        end
    end)

    page.button.MouseLeave:Connect(function()
        if self.selected_page ~= page then
            tween(page.button, TWEEN_FAST, { TextColor3 = THEME.text_dim })
        end
    end)

    page.button.MouseButton1Click:Connect(function()
        window:_close_popup()
        window:_select_page(page)
    end)

    -- the underline follows the text width once layout has run
    page.button:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        if window.selected_nav == self and self.selected_page == page then
            window:_move_underline(page, false)
        end
    end)

    table.insert(self.pages, page)

    if #self.pages == 1 then
        if window.selected_nav == self then
            window:_show_page(page)
        else
            self.selected_page = page
        end
    end

    return page
end

function Window:_move_underline(page: any, animate: boolean)
    local button = page.button
    local bar = self.tabbar
    local ui_scale = math.max(self.scale.Scale, 0.01)

    local x = (button.AbsolutePosition.X - bar.AbsolutePosition.X) / ui_scale + 8
    local line_width = math.max(button.AbsoluteSize.X / ui_scale - 16, 0)
    local goal = {
        Position = UDim2.fromOffset(x, 40),
        Size = UDim2.fromOffset(line_width, 2),
    }

    if animate and self.underline.Size.X.Offset > 0 then
        tween(self.underline, TWEEN_MEDIUM, goal)
    else
        self.underline.Position = goal.Position
        self.underline.Size = goal.Size
    end
end

function Window:_show_page(page: any)
    local nav = page.nav

    if nav.selected_page == page and page.canvas.Visible then
        return
    end

    for _, other in nav.pages do
        local active = other == page

        tween(other.button, TWEEN_FAST, { TextColor3 = active and THEME.text or THEME.text_dim })

        if not active and other.canvas.Visible then
            other.canvas.Visible = false
            other.canvas.GroupTransparency = 1
        end
    end

    nav.selected_page = page

    page.canvas.Position = UDim2.fromOffset(0, 10)
    page.canvas.Visible = true
    tween(page.canvas, TWEEN_MEDIUM, {
        GroupTransparency = 0,
        Position = UDim2.fromOffset(0, 0),
    })

    task.defer(function()
        self:_move_underline(page, true)
    end)
end

function Window:_activate_nav(nav: any, page: any?)
    local previous = self.selected_nav
    self.selected_nav = nav

    for _, other in self.navs do
        local active = other == nav

        other.strip.Visible = active
        other.button.Font = active and FONT_BOLD or FONT

        tween(other.button, TWEEN_FAST, {
            BackgroundTransparency = active and 0 or 1,
            TextColor3 = active and THEME.text or THEME.text_dim,
        })
    end

    if previous and previous ~= nav and previous.selected_page then
        local old = previous.selected_page.canvas
        old.Visible = false
        old.GroupTransparency = 1
    end

    local target = page or nav.selected_page or nav.pages[1]
    if target then
        self:_show_page(target)
    end
end

function Window:_select_page(page: any)
    if self.selected_nav ~= page.nav then
        self:_activate_nav(page.nav, page)
        return
    end

    self:_show_page(page)
end

----------------------------------------------------------
-- COLUMNS AND BOXES
----------------------------------------------------------

function Page:AddColumn()
    local column = setmetatable({
        window = self.window,
        page = self,
        boxes = {},
    }, Column)

    column.frame = create("Frame", {
        Name = "Column",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = #self.columns + 1,
        Parent = self.columns_frame,
    }, { list_layout(12) })

    table.insert(self.columns, column)

    -- columns share the width equally
    local count = #self.columns
    -- Split the available content width evenly and subtract each column's
    -- share of the inter-column gap, so two or more columns stay inside the page.
    local widthScale = 1 / count
    local widthOffset = -(COLUMN_GAP * (count - 1) / count)

    for _, other in self.columns do
        other.frame.Size = UDim2.new(widthScale, widthOffset, 0, 0)
    end

    return column
end

function Column:AddBox(title: string)
    local window = self.window

    local box = setmetatable({
        window = window,
        page = self.page,
        column = self,
        order = 0,
        floating = false,
        over_library = false,
        placeholder = nil,
        placeholder_stroke = nil,
    }, Box)

    box.frame = create("Frame", {
        Name = title,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = THEME.card,
        BorderSizePixel = 0,
        LayoutOrder = #self.boxes + 1,
        Parent = self.frame,
    }, {
        corner(8),
        stroke(THEME.card_stroke),
        padding(12, 12, 12, 12),
        list_layout(10),
    })

    box.header = create("TextButton", {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = 1,
        Parent = box.frame,
    })

    box.title_label = new_label(box.header, title, {
        Size = UDim2.fromScale(1, 1),
        Font = FONT_BOLD,
        TextSize = 14,
    })

    box.content = create("Frame", {
        Name = "Content",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = 2,
        Parent = box.frame,
    }, { list_layout(8) })

    box.header.MouseEnter:Connect(function()
        tween(box.title_label, TWEEN_FAST, { TextColor3 = THEME.accent })
    end)

    box.header.MouseLeave:Connect(function()
        tween(box.title_label, TWEEN_FAST, { TextColor3 = THEME.text })
    end)

    box.header.InputBegan:Connect(function(input: InputObject)
        if is_press(input) then
            box:_begin_drag(input)
        end
    end)

    table.insert(self.boxes, box)
    return box
end

function Box:SetTitle(title: string)
    self.title_label.Text = title
end

function Box:_next_order(): number
    self.order += 1
    return self.order
end

-- lifts the box out of its column (leaving a slot behind) and follows the pointer
function Box:_begin_drag(input: InputObject)
    local window = self.window
    local frame = self.frame
    local float_layer = window.float_layer

    window:_close_popup()

    if not self.floating then
        local size = frame.AbsoluteSize
        local origin = frame.AbsolutePosition - float_layer.AbsolutePosition

        local slot_stroke = stroke(THEME.card_stroke, 1, 0.45)

        self.placeholder = create("Frame", {
            Name = "Slot",
            Size = UDim2.new(1, 0, 0, size.Y),
            BackgroundTransparency = 1,
            LayoutOrder = frame.LayoutOrder,
            Parent = self.column.frame,
        }, {
            corner(8),
            slot_stroke,
        })

        self.placeholder_stroke = slot_stroke

        frame.Size = UDim2.fromOffset(size.X, 0)
        frame.Position = UDim2.fromOffset(origin.X, origin.Y)
        frame.Parent = float_layer
        self.floating = true
    end

    window.float_order += 1
    frame.ZIndex = window.float_order

    local start_position = frame.Position

    start_drag(input, function(position: Vector2, start: Vector2)
        local delta = position - start
        local viewport = float_layer.AbsoluteSize
        local width = frame.AbsoluteSize.X

        local x = math.clamp(start_position.X.Offset + delta.X, -width + 60, viewport.X - 60)
        local y = math.clamp(start_position.Y.Offset + delta.Y, 0, viewport.Y - 30)
        frame.Position = UDim2.fromOffset(x, y)

        -- the slot lights up while the box is over the window
        local over = center_inside(frame, window.main)
        if over ~= self.over_library then
            self.over_library = over

            if self.placeholder_stroke then
                tween(self.placeholder_stroke, TWEEN_FAST, {
                    Color = over and THEME.accent or THEME.card_stroke,
                    Transparency = over and 0 or 0.45,
                })
            end
        end
    end, function()
        if self.over_library then
            self:_dock()
        end
    end)
end

-- slides the box back into its original slot and resets the layout
function Box:_dock()
    if not self.floating or not self.placeholder then
        return
    end

    local window = self.window
    local frame = self.frame

    self.over_library = false
    self.floating = false

    task.spawn(function()
        window:_select_page(self.page)

        -- one frame so the page layout is up to date before measuring the slot
        RunService.Heartbeat:Wait()

        local slot = self.placeholder
        if not slot or not slot.Parent then
            return
        end

        local goal = slot.AbsolutePosition - window.float_layer.AbsolutePosition
        local slide = tween(frame, TWEEN_MEDIUM, { Position = UDim2.fromOffset(goal.X, goal.Y) })
        slide.Completed:Wait()

        if not frame.Parent then
            return
        end

        frame.Size = UDim2.new(1, 0, 0, 0)
        frame.Position = UDim2.new()
        frame.ZIndex = 1
        frame.LayoutOrder = slot.LayoutOrder
        frame.Parent = self.column.frame

        slot:Destroy()
        self.placeholder = nil
        self.placeholder_stroke = nil
    end)
end

----------------------------------------------------------
-- ELEMENTS
----------------------------------------------------------

local function new_row(box: any, height: number): Frame
    return create("Frame", {
        Name = "Row",
        Size = UDim2.new(1, 0, 0, height),
        BackgroundTransparency = 1,
        LayoutOrder = box:_next_order(),
        Parent = box.content,
    })
end

-- label above a full-width field
local function field_row(box: any, text: string?, field_height: number): (Frame, number)
    local top = 0
    local height = field_height

    local row = new_row(box, 0)

    if text and text ~= "" then
        new_label(row, text, {
            Size = UDim2.new(1, 0, 0, 16),
            TextSize = 12,
            TextColor3 = THEME.text_dim,
        })

        top = 20
        height = field_height + top
    end

    row.Size = UDim2.new(1, 0, 0, height)
    return row, top
end

local function build_field_stroke(field: GuiObject): UIStroke
    local field_stroke = stroke(THEME.card_stroke)
    field_stroke.Parent = field
    return field_stroke
end

----------------------------------------------------------
-- TOGGLE
----------------------------------------------------------

local TOGGLE_ARGS = { "Text", "Default", "Keybind", "Callback" }

function Box:AddToggle(...)
    local config = parse_args(TOGGLE_ARGS, ...)
    local window = self.window
    local callback = config.Callback
    local row = new_row(self, 24)

    local toggle: any = {
        Type = "Toggle",
        Default = config.Default == true,
        Value = false,
        Mode = config.Mode or "Toggle",
        Key = typeof(config.Keybind) == "EnumItem" and config.Keybind or nil,
    }

    local hit = create("TextButton", {
        Name = "Hit",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 1,
        Parent = row,
    })

    local checkbox = create("Frame", {
        Name = "Checkbox",
        Position = UDim2.new(0, 0, 0.5, -8),
        Size = UDim2.fromOffset(16, 16),
        BackgroundColor3 = THEME.field,
        Parent = row,
    }, { corner(4) })

    local checkbox_stroke = stroke(THEME.card_stroke)
    checkbox_stroke.Parent = checkbox

    local fill = create("Frame", {
        Name = "Fill",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(0, 0),
        BackgroundColor3 = THEME.accent,
        Parent = checkbox,
    }, { corner(4) })

    new_label(row, config.Text or "Toggle", {
        Position = UDim2.fromOffset(26, 0),
        Size = UDim2.new(1, -26, 1, 0),
    })

    local right = new_right(row)

    local function apply(value: boolean)
        tween(fill, TWEEN_POP, {
            Size = value and UDim2.fromOffset(16, 16) or UDim2.fromOffset(0, 0),
        })

        tween(checkbox_stroke, TWEEN_FAST, {
            Color = value and THEME.accent or THEME.card_stroke,
        })
    end

    function toggle:Set(value: boolean, silent: boolean?)
        value = value == true

        if self.Value == value then
            return
        end

        self.Value = value
        apply(value)
        window:_record_action(tostring(config.Text or "Toggle") .. " → " .. (value and "On" or "Off"))

        if not silent then
            safe_call(callback, value)
        end
    end

    function toggle:Get(): boolean
        return self.Value
    end

    hit.MouseButton1Click:Connect(function()
        toggle:Set(not toggle.Value)
    end)

    hit.MouseEnter:Connect(function()
        tween(checkbox, TWEEN_FAST, { BackgroundColor3 = THEME.field_hover })
    end)

    hit.MouseLeave:Connect(function()
        tween(checkbox, TWEEN_FAST, { BackgroundColor3 = THEME.field })
    end)

    -- optional keybind
    if config.Keybind ~= nil and config.Keybind ~= false then
        local bind = build_keybind_button(right, toggle.Key, function(key: Enum.KeyCode?)
            toggle.Key = key
            safe_call(config.KeybindCallback, key)
        end)

        function toggle:SetKeybind(key: Enum.KeyCode?)
            bind.set(key, true)
            self.Key = key
        end

        register_binding({
            get_key = function()
                return toggle.Key
            end,
            on_press = function()
                if toggle.Mode == "Hold" then
                    toggle:Set(true)
                else
                    toggle:Set(not toggle.Value)
                end
            end,
            on_release = function()
                if toggle.Mode == "Hold" then
                    toggle:Set(false)
                end
            end,
        })

        -- shows up in the keybind list (if one was created)
        window:TrackKeybind(
            toggle,
            config.Text or "Toggle",
            function()
                return toggle.Key
            end,
            function()
                if not toggle.Value then
                    return "OFF"
                end

                return toggle.Mode == "Hold" and "HOLD" or "ON"
            end
        )

        hit.MouseButton2Click:Connect(function()
            window:_open_popup(hit, Vector2.new(156, 72), "right", function(popup, close)
                local function add_mode_option(label_text: string, mode: string, y: number)
                    local selected = toggle.Mode == mode
                    local option = create("TextButton", {
                        Name = mode .. "Mode",
                        Position = UDim2.fromOffset(5, y),
                        Size = UDim2.new(1, -10, 0, 29),
                        BackgroundColor3 = selected and THEME.field_hover or THEME.popup,
                        BorderSizePixel = 0,
                        AutoButtonColor = false,
                        Text = label_text .. (selected and "  ✓" or ""),
                        TextColor3 = THEME.text,
                        TextSize = 12,
                        Font = FONT,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        ZIndex = 3,
                        Parent = popup,
                    }, { corner(5) })

                    create("UIPadding", { PaddingLeft = UDim.new(0, 9), Parent = option })

                    option.MouseEnter:Connect(function()
                        tween(option, TWEEN_FAST, { BackgroundColor3 = THEME.field_hover })
                    end)

                    option.MouseLeave:Connect(function()
                        tween(option, TWEEN_FAST, {
                            BackgroundColor3 = toggle.Mode == mode and THEME.field_hover or THEME.popup,
                        })
                    end)

                    option.MouseButton1Click:Connect(function()
                        toggle.Mode = mode
                        close()
                    end)
                end

                add_mode_option("Toggle", "Toggle", 5)
                add_mode_option("Hold", "Hold", 38)
            end)
        end)
    end

    -- optional colour swatch
    if typeof(config.Color) == "Color3" then
        local swatch = build_swatch(right, self.window, config.Color, config.ColorCallback)
        toggle.Swatch = swatch.button

        function toggle:SetColor(color: Color3)
            swatch.set(color, true)
        end

        function toggle:GetColor(): Color3
            return swatch.get()
        end
    end

    if config.Default == true then
        toggle.Value = true
        fill.Size = UDim2.fromOffset(16, 16)
        checkbox_stroke.Color = THEME.accent
    end

    toggle.Row = row
    return window:_register_element(toggle, tostring(config.Text or "Toggle"), self.page and self.page.name, self.frame and self.frame.Name, config.Id)
end

Box.AddCheckbox = Box.AddToggle

----------------------------------------------------------
-- BUTTON
----------------------------------------------------------

local BUTTON_ARGS = { "Text", "Callback" }

function Box:AddButton(...)
    local config = parse_args(BUTTON_ARGS, ...)
    local row = new_row(self, 28)

    local button = create("TextButton", {
        Name = "Button",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = THEME.field,
        AutoButtonColor = false,
        Text = config.Text or "Button",
        Font = FONT,
        TextSize = 13,
        TextColor3 = THEME.text,
        Parent = row,
    }, {
        corner(5),
        stroke(THEME.card_stroke),
    })

    local press_scale = create("UIScale", { Parent = button })

    button.MouseEnter:Connect(function()
        tween(button, TWEEN_FAST, { BackgroundColor3 = THEME.field_hover })
    end)

    button.MouseLeave:Connect(function()
        tween(button, TWEEN_FAST, { BackgroundColor3 = THEME.field })
        tween(press_scale, TWEEN_FAST, { Scale = 1 })
    end)

    button.MouseButton1Down:Connect(function()
        tween(press_scale, TWEEN_FAST, { Scale = 0.97 })
    end)

    button.MouseButton1Up:Connect(function()
        tween(press_scale, TWEEN_POP, { Scale = 1 })
    end)

    local control: any = { Type = "Button" }

    function control:Fire()
        safe_call(config.Callback)
    end

    function control:SetText(text: string)
        button.Text = text
    end

    button.MouseButton1Click:Connect(function()
        control:Fire()
    end)

    return control
end

----------------------------------------------------------
-- SLIDER
----------------------------------------------------------

local SLIDER_ARGS = { "Text", "Min", "Max", "Default", "Callback" }

function Box:AddSlider(...)
    local config = parse_args(SLIDER_ARGS, ...)
    local min = config.Min or 0
    local max = config.Max or 100
    local increment = config.Increment or 1
    local suffix = config.Suffix or ""
    local decimals = decimals_of(increment)
    local row = new_row(self, 40)

    local slider: any = { Type = "Slider", Default = config.Default or min, Min = min, Max = max, Value = min }

    new_label(row, config.Text or "Slider", {
        Size = UDim2.new(1, -60, 0, 16),
    })

    local value_label = new_label(row, "", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.fromScale(1, 0),
        Size = UDim2.fromOffset(60, 16),
        TextXAlignment = Enum.TextXAlignment.Right,
        TextColor3 = THEME.text_dim,
        TextSize = 12,
    })

    local hit = create("TextButton", {
        Name = "Hit",
        Position = UDim2.fromOffset(0, 20),
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Parent = row,
    })

    local track = create("Frame", {
        Name = "Track",
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.new(1, 0, 0, 4),
        BackgroundColor3 = THEME.field_hover,
        BorderSizePixel = 0,
        Parent = hit,
    }, { corner(2) })

    local fill = create("Frame", {
        Name = "Fill",
        Size = UDim2.fromScale(0, 1),
        BackgroundColor3 = THEME.text,
        BorderSizePixel = 0,
        Parent = track,
    }, { corner(2) })

    local knob = create("Frame", {
        Name = "Knob",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.fromOffset(12, 12),
        BackgroundColor3 = THEME.text,
        ZIndex = 2,
        Parent = track,
    }, { corner(6) })

    local dragging = false

    local function snap(raw: number): number
        local steps = math.floor((raw - min) / increment + 0.5)
        local snapped = math.clamp(min + steps * increment, min, max)
        return tonumber(string.format("%.6f", snapped)) :: number
    end

    local function render(animate: boolean)
        local alpha = max == min and 0 or (slider.Value - min) / (max - min)
        value_label.Text = string.format("%." .. decimals .. "f", slider.Value) .. suffix

        if animate then
            tween(fill, TWEEN_FAST, { Size = UDim2.fromScale(alpha, 1) })
            tween(knob, TWEEN_FAST, { Position = UDim2.fromScale(alpha, 0.5) })
        else
            fill.Size = UDim2.fromScale(alpha, 1)
            knob.Position = UDim2.fromScale(alpha, 0.5)
        end
    end

    function slider:Set(value: number, silent: boolean?)
        local snapped = snap(tonumber(value) or min)

        if snapped == self.Value then
            return
        end

        self.Value = snapped
        render(not dragging)

        if not silent then
            safe_call(config.Callback, snapped)
        end
    end

    function slider:Get(): number
        return self.Value
    end

    local function update_from(position: Vector2)
        local alpha = math.clamp((position.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        slider:Set(min + alpha * (max - min))
    end

    hit.InputBegan:Connect(function(input: InputObject)
        if not is_press(input) then
            return
        end

        dragging = true
        tween(knob, TWEEN_POP, { Size = UDim2.fromOffset(15, 15) })

        update_from(pointer_position(input))

        start_drag(input, update_from, function()
            dragging = false
            tween(knob, TWEEN_FAST, { Size = UDim2.fromOffset(12, 12) })
        end)
    end)

    hit.MouseEnter:Connect(function()
        if not dragging then
            tween(knob, TWEEN_FAST, { Size = UDim2.fromOffset(14, 14) })
        end
    end)

    hit.MouseLeave:Connect(function()
        if not dragging then
            tween(knob, TWEEN_FAST, { Size = UDim2.fromOffset(12, 12) })
        end
    end)

    slider.Value = snap(config.Default or min)
    render(false)

    slider.Row = row
    return self.window:_register_element(slider, tostring(config.Text or "Slider"), self.page and self.page.name, self.frame and self.frame.Name, config.Id)
end

----------------------------------------------------------
-- DUAL / RANGE SLIDER
----------------------------------------------------------

local RANGE_SLIDER_ARGS = { "Text", "Min", "Max", "DefaultMin", "DefaultMax", "Callback" }

function Box:AddRangeSlider(...)
    local config = parse_args(RANGE_SLIDER_ARGS, ...)
    local minimum = tonumber(config.Min) or 0
    local maximum = tonumber(config.Max) or 100
    if maximum < minimum then minimum, maximum = maximum, minimum end
    local increment = math.max(tonumber(config.Increment) or 1, 0.000001)
    local suffix = tostring(config.Suffix or "")
    local row = new_row(self, 44)
    local control: any = { Type = "RangeSlider", Min = minimum, Max = maximum, MinValue = minimum, MaxValue = maximum }
    new_label(row, config.Text or "Range", { Size = UDim2.new(1, -120, 0, 16) })
    local value_label = new_label(row, "", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(116, 16), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = THEME.text_dim, TextSize = 11 })
    local hit = create("Frame", { Name = "RangeHit", Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Parent = row })
    local track = create("Frame", { Position = UDim2.new(0, 0, 0.5, -2), Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = THEME.field_hover, BorderSizePixel = 0, Parent = hit }, { corner(2) })
    local fill = create("Frame", { Name = "RangeFill", BackgroundColor3 = THEME.accent, BorderSizePixel = 0, Parent = track }, { corner(2) })
    local function make_knob(name: string)
        return create("TextButton", { Name = name, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(12, 12), BackgroundColor3 = THEME.text, Text = "", AutoButtonColor = false, ZIndex = 3, Parent = track }, { corner(6) })
    end
    local low_knob, high_knob = make_knob("MinimumHandle"), make_knob("MaximumHandle")
    local dragging: string? = nil
    local selfWindow = self.window
    local function snap(value: number): number
        return math.clamp(tonumber(string.format("%.6f", minimum + math.floor((value - minimum) / increment + 0.5) * increment)) or minimum, minimum, maximum)
    end
    local function render(animate: boolean)
        local span = math.max(maximum - minimum, 0.000001)
        local low_a, high_a = (control.MinValue - minimum) / span, (control.MaxValue - minimum) / span
        value_label.Text = tostring(control.MinValue) .. suffix .. "  –  " .. tostring(control.MaxValue) .. suffix
        local props = { Position = UDim2.fromScale(low_a, 0), Size = UDim2.fromScale(math.max(0, high_a - low_a), 1) }
        if animate then tween(fill, TWEEN_FAST, props); tween(low_knob, TWEEN_FAST, { Position = UDim2.fromScale(low_a, 0.5) }); tween(high_knob, TWEEN_FAST, { Position = UDim2.fromScale(high_a, 0.5) })
        else fill.Position = props.Position; fill.Size = props.Size; low_knob.Position = UDim2.fromScale(low_a, 0.5); high_knob.Position = UDim2.fromScale(high_a, 0.5) end
    end
    function control:Set(low: number, high: number, silent: boolean?)
        low, high = snap(low), snap(high)
        if low > high then low, high = high, low end
        local changed = low ~= self.MinValue or high ~= self.MaxValue
        self.MinValue, self.MaxValue = low, high
        render(dragging == nil)
        if changed and not silent then safe_call(config.Callback, low, high); selfWindow:_record_action(tostring(config.Text or "Range") .. " → " .. tostring(low) .. "–" .. tostring(high)) end
    end
    function control:Get(): (number, number) return self.MinValue, self.MaxValue end
    local function update(position: Vector2)
        local alpha = math.clamp((position.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        local value = snap(minimum + alpha * (maximum - minimum))
        if dragging == "low" then control:Set(math.min(value, control.MaxValue), control.MaxValue)
        elseif dragging == "high" then control:Set(control.MinValue, math.max(value, control.MinValue)) end
    end
    local function begin_drag(which: string, input: InputObject)
        if not is_press(input) then return end
        dragging = which
        update(pointer_position(input))
        start_drag(input, update, function() dragging = nil end)
    end
    low_knob.InputBegan:Connect(function(input) begin_drag("low", input) end)
    high_knob.InputBegan:Connect(function(input) begin_drag("high", input) end)
    hit.InputBegan:Connect(function(input)
        if not is_press(input) then return end
        local point = pointer_position(input)
        local low_x = low_knob.AbsolutePosition.X + low_knob.AbsoluteSize.X / 2
        local high_x = high_knob.AbsolutePosition.X + high_knob.AbsoluteSize.X / 2
        begin_drag(math.abs(point.X - low_x) <= math.abs(point.X - high_x) and "low" or "high", input)
    end)
    local default_low = tonumber(config.DefaultMin) or minimum
    local default_high = tonumber(config.DefaultMax) or maximum
    control.MinValue, control.MaxValue = snap(default_low), snap(default_high)
    if control.MinValue > control.MaxValue then control.MinValue, control.MaxValue = control.MaxValue, control.MinValue end
    render(false)
    return selfWindow:_register_element(control, tostring(config.Text or "Range"), self.page and self.page.name, self.frame and self.frame.Name, config.Id)
end

Box.AddDualSlider = Box.AddRangeSlider

----------------------------------------------------------
-- DROPDOWN
----------------------------------------------------------

local DROPDOWN_ARGS = { "Text", "Options", "Default", "Callback" }

local function build_dropdown_field(row: Frame, top: number): (TextButton, TextLabel, TextLabel, UIStroke)
    local field = create("TextButton", {
        Name = "Field",
        Position = UDim2.fromOffset(0, top),
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundColor3 = THEME.field,
        AutoButtonColor = false,
        Text = "",
        Parent = row,
    }, { corner(5) })

    local field_stroke = build_field_stroke(field)

    local value_label = new_label(field, "", {
        Position = UDim2.fromOffset(10, 0),
        Size = UDim2.new(1, -32, 1, 0),
    })

    local arrow = new_label(field, "▾", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.fromOffset(14, 14),
        TextXAlignment = Enum.TextXAlignment.Center,
        TextColor3 = THEME.text_dim,
        TextSize = 14,
    })

    field.MouseEnter:Connect(function()
        tween(field, TWEEN_FAST, { BackgroundColor3 = THEME.field_hover })
    end)

    field.MouseLeave:Connect(function()
        tween(field, TWEEN_FAST, { BackgroundColor3 = THEME.field })
    end)

    return field, value_label, arrow, field_stroke
end

function Box:AddDropdown(...)
    local config = parse_args(DROPDOWN_ARGS, ...)
    local window = self.window
    local callback = config.Callback

    local is_size_dropdown = string.upper(tostring(config.Text or "")) == "UI-SIZE"
    local dropdown_options = config.Options
    if is_size_dropdown and dropdown_options == nil then
        dropdown_options = { "100%", "125%", "150%", "200%" }
    end

    local dropdown: any = {
        Type = "Dropdown",
        Default = config.Default,
        Options = dropdown_options or {},
        Value = config.Default,
    }

    local function apply_ui_size(value: any)
        if not is_size_dropdown or value == nil then
            return
        end
        local percentage = tonumber(string.match(tostring(value), "[%d%.]+"))
        if percentage then
            window:SetUIScale(percentage)
        end
    end

    local row, top = field_row(self, config.Text, 26)
    local field, value_label, arrow, field_stroke = build_dropdown_field(row, top)

    local function render()
        local has_value = dropdown.Value ~= nil and dropdown.Value ~= ""
        value_label.Text = has_value and tostring(dropdown.Value) or "None"
        value_label.TextColor3 = has_value and THEME.text or THEME.text_dim
    end

    function dropdown:Set(value: any, silent: boolean?)
        if self.Value == value then
            return
        end

        self.Value = value
        render()
        window:_record_action(tostring(config.Text or "Dropdown") .. " → " .. tostring(value))
        apply_ui_size(value)

        if not silent then
            safe_call(callback, value)
        end
    end

    function dropdown:Get(): any
        return self.Value
    end

    function dropdown:SetOptions(options: { any })
        self.Options = options
    end

    local close_list = nil

    field.MouseButton1Click:Connect(function()
        -- clicking the field while open closes it
        if close_list then
            close_list()
            return
        end

        tween(arrow, TWEEN_FAST, { Rotation = 180 })
        tween(field_stroke, TWEEN_FAST, { Color = THEME.text_dim })

        close_list = window:_open_list_popup(field, {
            options = dropdown.Options,
            searchable = config.Searchable == true or #dropdown.Options >= (config.SearchThreshold or 12),
            multi = false,
            keep_open = false,

            is_selected = function(option)
                return option == dropdown.Value
            end,

            on_pick = function(option)
                dropdown:Set(option)
            end,

            on_close = function()
                close_list = nil
                tween(arrow, TWEEN_FAST, { Rotation = 0 })
                tween(field_stroke, TWEEN_FAST, { Color = THEME.card_stroke })
            end,
        }, row, top)
    end)

    render()
    apply_ui_size(dropdown.Value)
    dropdown.Row = row
    return window:_register_element(dropdown, tostring(config.Text or "Dropdown"), self.page and self.page.name, self.frame and self.frame.Name, config.Id)
end

function Box:AddMultiDropdown(...)
    local config = parse_args(DROPDOWN_ARGS, ...)
    local window = self.window
    local callback = config.Callback

    local dropdown: any = {
        Type = "MultiDropdown",
        Default = config.Default or {},
        Options = config.Options or {},
        Selected = {},
    }

    local row, top = field_row(self, config.Text, 26)
    local field, value_label, arrow, field_stroke = build_dropdown_field(row, top)

    -- selected names in option order
    local function collect(): { any }
        local list = {}

        for _, option in dropdown.Options do
            if dropdown.Selected[option] then
                table.insert(list, option)
            end
        end

        return list
    end

    local function render()
        local list = collect()
        local has_value = #list > 0

        value_label.Text = has_value and table.concat(list, ", ") or "None"
        value_label.TextColor3 = has_value and THEME.text or THEME.text_dim
    end

    function dropdown:Get(): { any }
        return collect()
    end

    function dropdown:Has(option: any): boolean
        return self.Selected[option] == true
    end

    -- accepts an array of names or a { name = bool } map
    function dropdown:Set(values: { any }, silent: boolean?)
        local selected = {}

        for key, value in values or {} do
            if type(key) == "number" then
                selected[value] = true
            elseif value then
                selected[key] = true
            end
        end

        self.Selected = selected
        render()

        if not silent then
            safe_call(callback, collect())
        end
    end

    function dropdown:SetOptions(options: { any })
        self.Options = options
        render()
    end

    local close_list = nil

    field.MouseButton1Click:Connect(function()
        if close_list then
            close_list()
            return
        end

        tween(arrow, TWEEN_FAST, { Rotation = 180 })
        tween(field_stroke, TWEEN_FAST, { Color = THEME.text_dim })

        close_list = window:_open_list_popup(field, {
            options = dropdown.Options,
            searchable = config.Searchable == true or #dropdown.Options >= (config.SearchThreshold or 12),
            multi = true,
            keep_open = true,

            is_selected = function(option: any)
                return dropdown.Selected[option] == true
            end,

            on_pick = function(option: any)
                dropdown.Selected[option] = not dropdown.Selected[option] or nil
                render()
                safe_call(callback, collect())
            end,

            on_close = function()
                close_list = nil
                tween(arrow, TWEEN_FAST, { Rotation = 0 })
                tween(field_stroke, TWEEN_FAST, { Color = THEME.card_stroke })
            end,
        }, row, top)
    end)

    dropdown:Set(config.Default or {}, true)
    dropdown.Row = row
    return window:_register_element(dropdown, tostring(config.Text or "MultiDropdown"), self.page and self.page.name, self.frame and self.frame.Name, config.Id)
end

----------------------------------------------------------
-- COLORPICKER
----------------------------------------------------------

local COLORPICKER_ARGS = { "Text", "Default", "Callback" }

function Box:AddColorpicker(...)
    local config = parse_args(COLORPICKER_ARGS, ...)
    local row = new_row(self, 24)

    new_label(row, config.Text or "Colour", {
        Size = UDim2.new(1, -40, 1, 0),
    })

    local right = new_right(row)
    local swatch = build_swatch(right, self.window, config.Default or Color3.fromRGB(236, 32, 160), config.Callback)

    local picker: any = { Type = "Colorpicker", Default = config.Default or Color3.fromRGB(236, 32, 160), Swatch = swatch.button }

    function picker:Set(color: Color3, silent: boolean?)
        swatch.set(color, silent)
    end

    function picker:Get(): Color3
        return swatch.get()
    end

    picker.Row = row
    return self.window:_register_element(picker, tostring(config.Text or "Colour"), self.page and self.page.name, self.frame and self.frame.Name, config.Id)
end

Box.AddColorPicker = Box.AddColorpicker

----------------------------------------------------------
-- TEXTBOX
----------------------------------------------------------

local TEXTBOX_ARGS = { "Text", "Default", "Callback" }

function Box:AddTextbox(...)
    local config = parse_args(TEXTBOX_ARGS, ...)
    local row, top = field_row(self, config.Text, 26)

    local box: any = { Type = "Textbox", Default = config.Default or "", Value = config.Default or "" }

    local input = create("TextBox", {
        Name = "Input",
        Position = UDim2.fromOffset(0, top),
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundColor3 = THEME.field,
        Font = FONT,
        TextSize = 13,
        TextColor3 = THEME.text,
        PlaceholderText = config.Placeholder or "",
        PlaceholderColor3 = THEME.text_dim,
        Text = box.Value,
        ClearTextOnFocus = config.ClearOnFocus == true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = row,
    }, {
        corner(5),
        padding(0, 0, 10, 10),
    })

    local input_stroke = build_field_stroke(input)

    input.Focused:Connect(function()
        tween(input_stroke, TWEEN_FAST, { Color = THEME.accent })
    end)

    input.FocusLost:Connect(function(enter_pressed: boolean)
        tween(input_stroke, TWEEN_FAST, { Color = THEME.card_stroke })

        box.Value = input.Text
        safe_call(config.Callback, input.Text, enter_pressed)
    end)

    input:GetPropertyChangedSignal("Text"):Connect(function()
        if config.Numeric then
            local cleaned = input.Text:gsub("[^%d%.%-]", "")
            if cleaned ~= input.Text then
                input.Text = cleaned
                return
            end
        end

        box.Value = input.Text

        if config.Live then
            safe_call(config.Callback, input.Text, false)
        end
    end)

    function box:Set(text: string)
        self.Value = tostring(text)
        input.Text = self.Value
    end

    function box:Get(): string
        return self.Value
    end

    box.Row = row
    return self.window:_register_element(box, tostring(config.Text or "Textbox"), self.page and self.page.name, self.frame and self.frame.Name, config.Id)
end

----------------------------------------------------------
-- KEYBIND
----------------------------------------------------------

local KEYBIND_ARGS = { "Text", "Default", "Callback" }

function Box:AddKeybind(...)
    local config = parse_args(KEYBIND_ARGS, ...)
    local row = new_row(self, 24)

    new_label(row, config.Text or "Keybind", {
        Size = UDim2.new(1, -60, 1, 0),
    })

    local keybind: any = { Type = "Keybind", Default = config.Default, Key = config.Default }

    local bind = build_keybind_button(new_right(row), keybind.Key, function(key: Enum.KeyCode?)
        keybind.Key = key
        safe_call(config.Callback, key)
    end)

    function keybind:Set(key: Enum.KeyCode?, silent: boolean?)
        self.Key = key
        bind.set(key, silent)
    end

    function keybind:Get(): Enum.KeyCode?
        return self.Key
    end

    -- OnPress runs whenever the bound key is pressed
    if config.OnPress then
        register_binding({
            get_key = function()
                return keybind.Key
            end,
            on_press = function()
                safe_call(config.OnPress)
            end,
        })
    end

    keybind.Row = row
    return self.window:_register_element(keybind, tostring(config.Text or "Keybind"), self.page and self.page.name, self.frame and self.frame.Name, config.Id)
end

----------------------------------------------------------
-- IMAGE
----------------------------------------------------------

local IMAGE_ARGS = { "Image", "Height" }

local function resolve_image(image: any): string
    if type(image) == "number" then
        return "rbxassetid://" .. tostring(image)
    end

    local text = tostring(image or "")
    if text:match("^%d+$") then
        return "rbxassetid://" .. text
    end

    return text
end

function Box:AddImage(...)
    local config = parse_args(IMAGE_ARGS, ...)
    local row = new_row(self, config.Height or 100)

    local holder = create("Frame", {
        Name = "Holder",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = THEME.field,
        BackgroundTransparency = config.Background == false and 1 or 0,
        ClipsDescendants = true,
        Parent = row,
    }, { corner(config.Corner or 6) })

    local image = create("ImageLabel", {
        Name = "Image",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Image = resolve_image(config.Image),
        ImageColor3 = config.Color or Color3.new(1, 1, 1),
        ScaleType = config.ScaleType or Enum.ScaleType.Fit,
        Parent = holder,
    })

    local control: any = { Type = "Image" }

    function control:Set(new_image: any)
        image.Image = resolve_image(new_image)
    end

    function control:SetColor(color: Color3)
        image.ImageColor3 = color
    end

    return control
end

----------------------------------------------------------
-- LABEL
----------------------------------------------------------

local LABEL_ARGS = { "Text" }

function Box:AddLabel(...)
    local config = parse_args(LABEL_ARGS, ...)

    local label = new_label(self.content, config.Text or "", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        TextWrapped = config.Wrap ~= false,
        TextTruncate = Enum.TextTruncate.None,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextColor3 = config.Color or THEME.text_dim,
        TextSize = config.Size or 12,
        Font = config.Bold and FONT_BOLD or FONT,
        LayoutOrder = self:_next_order(),
    })

    local control: any = { Type = "Label" }

    function control:Set(text: string)
        label.Text = tostring(text)
    end

    function control:SetColor(color: Color3)
        label.TextColor3 = color
    end

    return control
end

----------------------------------------------------------
-- SEPARATOR
----------------------------------------------------------

local SEPARATOR_ARGS = { "Text" }

function Box:AddSeparator(...)
    local config = parse_args(SEPARATOR_ARGS, ...)
    local text = config.Text
    local row = new_row(self, text and 16 or 8)

    create("Frame", {
        Name = "Line",
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = THEME.card_stroke,
        BorderSizePixel = 0,
        Parent = row,
    })

    if text then
        -- the label sits on top of the line and hides the part behind it
        local label = new_label(row, text, {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(0, 16),
            AutomaticSize = Enum.AutomaticSize.X,
            BackgroundTransparency = 0,
            BackgroundColor3 = THEME.card,
            BorderSizePixel = 0,
            TextSize = 11,
            TextColor3 = THEME.text_dim,
            TextTruncate = Enum.TextTruncate.None,
            ZIndex = 2,
        })

        padding(0, 0, 8, 8).Parent = label
    end

    return { Type = "Separator" }
end

----------------------------------------------------------
-- HUD: SHARED HELPERS
----------------------------------------------------------

-- a separate ScreenGui so HUD elements stay visible when the main window is hidden
local function new_hud_gui(order: number): ScreenGui
    local gui = create("ScreenGui", {
        Name = HttpService:GenerateGUID(false),
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = order,
    })

    pcall(function()
        gui.ScreenInsets = Enum.ScreenInsets.None
    end)

    mount_gui(gui)
    root_maid.add(gui)
    return gui
end

-- drag `frame` by `handle`, kept fully on screen
local function make_hud_draggable(gui: ScreenGui, frame: GuiObject, handle: GuiObject)
    handle.InputBegan:Connect(function(input: InputObject)
        if not is_press(input) then
            return
        end

        local origin = frame.Position

        start_drag(input, function(position: Vector2, start: Vector2)
            local delta = position - start

            frame.Position = UDim2.new(
                origin.X.Scale,
                origin.X.Offset + delta.X,
                origin.Y.Scale,
                origin.Y.Offset + delta.Y
            )

            local absolute = frame.AbsolutePosition
            local size = frame.AbsoluteSize
            local view = gui.AbsoluteSize

            local fix_x = math.clamp(absolute.X, 0, math.max(view.X - size.X, 0)) - absolute.X
            local fix_y = math.clamp(absolute.Y, 0, math.max(view.Y - size.Y, 0)) - absolute.Y

            if fix_x ~= 0 or fix_y ~= 0 then
                frame.Position += UDim2.fromOffset(fix_x, fix_y)
            end
        end)
    end)
end

local function rich_escape(text: string): string
    return (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

----------------------------------------------------------
-- HUD: KEYBIND REGISTRY
----------------------------------------------------------

-- id: any unique key (usually the element table)
-- get_key() -> Enum.KeyCode?, get_state() -> "ON" | "OFF" | "HOLD"
function Window:TrackKeybind(id: any, name: string, get_key: () -> Enum.KeyCode?, get_state: () -> string)
    self.keybind_registry = self.keybind_registry or {}
    self.keybind_registry[id] = {
        name = name,
        get_key = get_key,
        get_state = get_state,
    }
end

function Window:UntrackKeybind(id: any)
    if self.keybind_registry then
        self.keybind_registry[id] = nil
    end
end

----------------------------------------------------------
-- HUD: KEYBIND LIST
----------------------------------------------------------

function Window:CreateKeybindList(config: { [string]: any }?)
    config = config or {}

    if self.keybind_list then
        return self.keybind_list
    end

    local window = self
    window.keybind_registry = window.keybind_registry or {}

    local only_active = config.OnlyActive == true
    local auto_hide = config.AutoHide == true
    local width = config.Width or 200
    local maid = new_maid()

    local gui = new_hud_gui(1002)

    local panel = create("Frame", {
        Name = "KeybindList",
        Position = config.Position or UDim2.fromOffset(16, 120),
        Size = UDim2.fromOffset(width, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = THEME.window,
        BorderSizePixel = 0,
        Active = true,
        Parent = gui,
    }, {
        corner(8),
        stroke(THEME.divider),
        list_layout(0),
    })

    local header = create("Frame", {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundTransparency = 1,
        Active = true,
        LayoutOrder = 1,
        Parent = panel,
    })

    local title_label = new_label(header, config.Title or "Active Keybinds", {
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -24, 1, 0),
        Font = FONT_BOLD,
        TextSize = 13,
    })

    create("Frame", {
        Name = "Divider",
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = THEME.divider,
        BorderSizePixel = 0,
        LayoutOrder = 2,
        Parent = panel,
    })

    local rows_frame = create("Frame", {
        Name = "Rows",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = 3,
        Parent = panel,
    }, {
        padding(8, 8, 12, 12),
        list_layout(4),
    })

    make_hud_draggable(gui, panel, header)

    local list: any = { Type = "KeybindList", Visible = config.Visible ~= false }
    local rows: { [any]: any } = {}
    local row_counter = 0

    local function build_row(entry: any)
        row_counter += 1

        local frame = create("Frame", {
            Name = "Entry",
            Size = UDim2.new(1, 0, 0, 18),
            BackgroundTransparency = 1,
            LayoutOrder = row_counter,
            Parent = rows_frame,
        })

        local name_label = new_label(frame, entry.name, {
            Size = UDim2.new(1, -92, 1, 0),
            TextSize = 12,
            TextColor3 = THEME.text_dim,
        })

        local key_label = new_label(frame, "", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -42, 0.5, 0),
            Size = UDim2.fromOffset(48, 16),
            TextXAlignment = Enum.TextXAlignment.Right,
            TextSize = 12,
            TextColor3 = THEME.text,
        })

        local state_label = new_label(frame, "", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.fromOffset(38, 16),
            TextXAlignment = Enum.TextXAlignment.Right,
            Font = FONT_BOLD,
            TextSize = 11,
        })

        return {
            frame = frame,
            name = name_label,
            key = key_label,
            state = state_label,
            last_state = nil,
        }
    end

    local function sync()
        local registry = window.keybind_registry
        local shown = 0

        for id, entry in registry do
            if not rows[id] then
                rows[id] = build_row(entry)
            end
        end

        for id, row in rows do
            local entry = registry[id]

            if not entry then
                row.frame:Destroy()
                rows[id] = nil
            else
                local key = entry.get_key()
                local state = entry.get_state()
                local active = state ~= "OFF"
                local visible = key ~= nil and (active or not only_active)

                row.frame.Visible = visible

                if visible then
                    shown += 1

                    if row.name.Text ~= entry.name then
                        row.name.Text = entry.name
                    end

                    local key_text = key_name(key)
                    if row.key.Text ~= key_text then
                        row.key.Text = key_text
                    end

                    if row.last_state ~= state then
                        row.last_state = state
                        row.state.Text = state

                        tween(row.state, TWEEN_FAST, {
                            TextColor3 = active and THEME.accent or THEME.text_dim,
                        })
                        tween(row.name, TWEEN_FAST, {
                            TextColor3 = active and THEME.text or THEME.text_dim,
                        })
                    end
                end
            end
        end

        panel.Visible = list.Visible and (not auto_hide or shown > 0)
    end

    maid.connect(RunService.Heartbeat, sync)
    root_maid.add(function()
        maid.clean()
    end)

    function list:SetVisible(visible: boolean)
        self.Visible = visible == true
        sync()
    end

    function list:Toggle()
        self:SetVisible(not self.Visible)
    end

    function list:SetTitle(text: string)
        title_label.Text = tostring(text)
    end

    function list:SetOnlyActive(value: boolean)
        only_active = value == true
    end

    function list:Destroy()
        maid.clean()
        gui:Destroy()
        window.keybind_list = nil
    end

    window.keybind_list = list
    sync()

    return list
end

----------------------------------------------------------
-- HUD: WATERMARK
----------------------------------------------------------

function Window:CreateWatermark(config: { [string]: any }?)
    config = config or {}

    if self.watermark then
        return self.watermark
    end

    local window = self
    local maid = new_maid()

    local title = tostring(config.Title or "LegendUI")
    local show_user = config.ShowUser ~= false
    local private = config.Private == true
    local show_fps = config.ShowFPS ~= false
    local show_ping = config.ShowPing ~= false
    local show_time = config.ShowTime ~= false
    local fields = config.Fields or {}
    local interval = math.clamp(config.Interval or 0.5, 0.1, 5)
    local override: string? = nil

    local gui = new_hud_gui(1003)

    local frame = create("Frame", {
        Name = "Watermark",
        Position = config.Position or UDim2.fromOffset(16, 16),
        Size = UDim2.fromOffset(0, 28),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = THEME.window,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Active = true,
        Parent = gui,
    }, {
        corner(6),
        stroke(THEME.divider),
    })

    -- accent line along the top edge
    create("Frame", {
        Name = "Accent",
        Size = UDim2.new(1, 0, 0, 2),
        BackgroundColor3 = THEME.accent,
        BorderSizePixel = 0,
        ZIndex = 2,
        Parent = frame,
    })

    local label = new_label(frame, "", {
        Position = UDim2.fromOffset(0, 1),
        Size = UDim2.fromOffset(0, 27),
        AutomaticSize = Enum.AutomaticSize.X,
        RichText = true,
        TextSize = 12,
        TextTruncate = Enum.TextTruncate.None,
        TextXAlignment = Enum.TextXAlignment.Center,
    })

    padding(0, 0, 10, 10).Parent = label

    if config.Draggable ~= false then
        make_hud_draggable(gui, frame, frame)
    end

    local fps = 60
    local frames = 0
    local elapsed = 0

    local function get_ping(): number
        local ok, value = pcall(function()
            return StatsService.Network.ServerStatsItem["Data Ping"]:GetValue()
        end)

        return ok and math.floor(value + 0.5) or 0
    end

    local function build_text(): string
        if override then
            return override
        end

        local accent = color_to_hex(THEME.accent)
        local dim = color_to_hex(THEME.text_dim)
        local parts = {
            string.format('<font color="%s"><b>%s</b></font>', accent, rich_escape(title)),
        }

        if show_user and not private and LocalPlayer then
            table.insert(parts, rich_escape(LocalPlayer.Name))
        end

        if show_fps then
            table.insert(parts, string.format("%d fps", fps))
        end

        if show_ping then
            table.insert(parts, string.format("%d ms", get_ping()))
        end

        if show_time then
            table.insert(parts, os.date("%H:%M:%S"))
        end

        for _, field in fields do
            local value = field

            if type(field) == "function" then
                local ok, result = pcall(field)
                value = ok and result or nil
            end

            if value ~= nil and value ~= "" then
                table.insert(parts, rich_escape(tostring(value)))
            end
        end

        return table.concat(parts, string.format(' <font color="%s">|</font> ', dim))
    end

    local function refresh()
        label.Text = build_text()
    end

    maid.connect(RunService.Heartbeat, function(dt: number)
        frames += 1
        elapsed += dt

        if elapsed >= interval then
            fps = math.floor(frames / elapsed + 0.5)
            frames = 0
            elapsed = 0
            refresh()
        end
    end)

    root_maid.add(function()
        maid.clean()
    end)

    local watermark: any = { Type = "Watermark" }

    function watermark:SetTitle(text: string)
        title = tostring(text)
        refresh()
    end

    -- pass nil to go back to the automatic text
    function watermark:SetText(text: string?)
        override = text and tostring(text) or nil
        refresh()
    end

    -- private mode hides the username (everything else keeps showing)
    function watermark:SetPrivate(value: boolean)
        private = value == true
        refresh()
    end

    function watermark:IsPrivate(): boolean
        return private
    end

    function watermark:SetFields(new_fields: { any })
        fields = new_fields or {}
        refresh()
    end

    function watermark:SetPosition(position: UDim2)
        frame.Position = position
    end

    function watermark:SetVisible(visible: boolean)
        frame.Visible = visible == true
    end

    function watermark:Toggle()
        frame.Visible = not frame.Visible
    end

    function watermark:Destroy()
        maid.clean()
        gui:Destroy()
        window.watermark = nil
    end

    window.watermark = watermark
    refresh()

    return watermark
end

----------------------------------------------------------
-- COMMAND PALETTE, NOTIFICATIONS, AND CONFIG PROFILES
----------------------------------------------------------

-- Toast notifications styled to match the window.
-- window:Notify({
--     Title = "Config loaded", Description = "Default profile applied",
--     Type = "success" | "warning" | "error" | "info",
--     Duration = 4 (0 = stays until clicked), Icon = "✓",
--     Action = { Text = "Undo", Callback = function() end },
-- })
function Window:Notify(config: any)
    config = type(config) == "table" and config or { Description = tostring(config) }

    local width = 300
    local max_toasts = 6

    if not self.toast_gui or not self.toast_gui.Parent then
        self.toast_gui = new_hud_gui(1200)
        self.toast_stack = create("Frame", {
            Name = "ToastStack",
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -18, 0, 18),
            Size = UDim2.fromOffset(width, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Parent = self.toast_gui,
        }, {
            list_layout(8, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Right),
        })
    end

    local kind = string.lower(tostring(config.Type or config.Kind or "info"))
    local styles = {
        success = { color = Color3.fromRGB(52, 199, 89), glyph = "✓" },
        warning = { color = Color3.fromRGB(255, 159, 10), glyph = "!" },
        error = { color = Color3.fromRGB(255, 69, 58), glyph = "✕" },
        info = { color = THEME.accent, glyph = "i" },
    }
    local style = styles[kind] or styles.info

    local title = tostring(config.Title or (kind:gsub("^%l", string.upper)))
    local description = config.Description or config.Message or config.Content
    local duration = math.max(tonumber(config.Duration) or 4, 0)
    local timed = duration > 0

    self.toast_counter = (self.toast_counter or 0) + 1

    local handle: any = {}
    local dismissed = false

    -- the wrapper keeps the layout slot while the card slides in and out
    local wrapper = create("Frame", {
        Name = "Toast",
        Size = UDim2.fromOffset(width, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = -self.toast_counter, -- newest on top
        Parent = self.toast_stack,
    })

    local card_stroke = stroke(THEME.card_stroke)

    local card = create("TextButton", {
        Name = "Card",
        Position = UDim2.fromOffset(width + 40, 0),
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = THEME.window,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        ClipsDescendants = true,
        Parent = wrapper,
    }, {
        corner(8),
        card_stroke,
    })

    -- icon chip
    create("Frame", {
        Name = "Icon",
        Position = UDim2.fromOffset(12, 12),
        Size = UDim2.fromOffset(26, 26),
        BackgroundColor3 = style.color,
        BackgroundTransparency = 0.85,
        BorderSizePixel = 0,
        Parent = card,
    }, {
        corner(6),
        stroke(style.color, 1, 0.7),
    })

    new_label(card, tostring(config.Icon or style.glyph), {
        Name = "Glyph",
        Position = UDim2.fromOffset(12, 12),
        Size = UDim2.fromOffset(26, 26),
        TextXAlignment = Enum.TextXAlignment.Center,
        TextColor3 = style.color,
        Font = FONT_BOLD,
        TextSize = 14,
    })

    -- text column (drives the card height)
    local body = create("Frame", {
        Name = "Body",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = card,
    }, {
        padding(12, timed and 15 or 13, 50, 30),
        list_layout(2),
    })

    new_label(body, title, {
        Name = "Title",
        Size = UDim2.new(1, 0, 0, 16),
        Font = FONT_BOLD,
        TextSize = 13,
        LayoutOrder = 1,
    })

    if description and tostring(description) ~= "" then
        new_label(body, tostring(description), {
            Name = "Description",
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            TextWrapped = true,
            TextTruncate = Enum.TextTruncate.None,
            TextYAlignment = Enum.TextYAlignment.Top,
            TextColor3 = THEME.text_dim,
            TextSize = 12,
            LayoutOrder = 2,
        })
    end

    if type(config.Action) == "table" and type(config.Action.Callback) == "function" then
        local action_row = create("Frame", {
            Name = "ActionRow",
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundTransparency = 1,
            LayoutOrder = 3,
            Parent = body,
        })

        local action = create("TextButton", {
            Name = "Action",
            Position = UDim2.fromOffset(0, 8),
            Size = UDim2.fromOffset(0, 22),
            AutomaticSize = Enum.AutomaticSize.X,
            BackgroundColor3 = THEME.field,
            AutoButtonColor = false,
            Text = tostring(config.Action.Text or "Open"),
            TextColor3 = THEME.text,
            Font = FONT,
            TextSize = 11,
            Parent = action_row,
        }, {
            corner(5),
            stroke(THEME.card_stroke),
            padding(0, 0, 10, 10),
        })

        action.MouseEnter:Connect(function()
            tween(action, TWEEN_FAST, { BackgroundColor3 = THEME.field_hover })
        end)

        action.MouseLeave:Connect(function()
            tween(action, TWEEN_FAST, { BackgroundColor3 = THEME.field })
        end)

        action.MouseButton1Click:Connect(function()
            safe_call(config.Action.Callback)
            handle.Dismiss()
        end)
    end

    local close_label = new_label(card, "✕", {
        Name = "Close",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -10, 0, 12),
        Size = UDim2.fromOffset(16, 16),
        TextXAlignment = Enum.TextXAlignment.Center,
        TextColor3 = THEME.text_dim,
        TextSize = 11,
    })

    -- countdown bar along the bottom edge
    local fill = nil
    if timed then
        local track = create("Frame", {
            Name = "Track",
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.fromScale(0, 1),
            Size = UDim2.new(1, 0, 0, 3),
            BackgroundColor3 = THEME.field,
            BorderSizePixel = 0,
            Parent = card,
        })

        fill = create("Frame", {
            Name = "Fill",
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = style.color,
            BorderSizePixel = 0,
            Parent = track,
        })
    end

    local function dismiss()
        if dismissed then
            return
        end

        dismissed = true

        for index, item in self.notifications do
            if item == handle then
                table.remove(self.notifications, index)
                break
            end
        end

        tween(card, TWEEN_MEDIUM, { Position = UDim2.fromOffset(width + 40, 0) })

        task.delay(0.22, function()
            if not wrapper.Parent then
                return
            end

            -- collapse the slot so the toasts below slide into place
            wrapper.AutomaticSize = Enum.AutomaticSize.None
            wrapper.Size = UDim2.fromOffset(width, wrapper.AbsoluteSize.Y)
            tween(wrapper, TWEEN_FAST, { Size = UDim2.fromOffset(width, 0) })

            task.delay(0.16, function()
                wrapper:Destroy()
            end)
        end)
    end

    handle.Dismiss = dismiss
    handle.Frame = card
    table.insert(self.notifications, handle)

    card.MouseButton1Click:Connect(dismiss)

    -- keep the stack tidy
    while #self.notifications > max_toasts do
        self.notifications[1].Dismiss()
    end

    tween(card, TWEEN_MEDIUM, { Position = UDim2.fromOffset(0, 0) })

    -- one loop per toast: hover highlight, pausing timer, countdown bar
    task.spawn(function()
        local remaining = duration
        local was_hovered = false

        while wrapper.Parent and not dismissed do
            local step = RunService.Heartbeat:Wait()

            local mouse = UserInputService:GetMouseLocation()
            local inset = GuiService:GetGuiInset()
            local point = Vector2.new(mouse.X - inset.X, mouse.Y - inset.Y)
            local position = card.AbsolutePosition
            local size = card.AbsoluteSize

            local hovered = point.X >= position.X
                and point.X <= position.X + size.X
                and point.Y >= position.Y
                and point.Y <= position.Y + size.Y

            if hovered ~= was_hovered then
                was_hovered = hovered
                tween(card_stroke, TWEEN_FAST, { Color = hovered and style.color or THEME.card_stroke })
                tween(close_label, TWEEN_FAST, { TextColor3 = hovered and THEME.text or THEME.text_dim })
            end

            -- the timer pauses while the pointer is over the toast
            if timed and not hovered then
                remaining -= step

                if fill then
                    fill.Size = UDim2.fromScale(math.clamp(remaining / duration, 0, 1), 1)
                end

                if remaining <= 0 then
                    dismiss()
                end
            end
        end
    end)

    return handle
end

function Window:CreateNotification(config: any) return self:Notify(config) end

function Window:OpenCommandPalette()
    if self.command_palette and self.command_palette.Parent then self.command_palette:Destroy(); self.command_palette = nil; return end
    local overlay = create("Frame", { Name = "CommandPaletteOverlay", Size = UDim2.fromScale(1,1), BackgroundColor3 = Color3.new(0,0,0), BackgroundTransparency = 0.35, ZIndex = 50, Parent = self.gui })
    local panel = create("Frame", { Name = "CommandPalette", AnchorPoint = Vector2.new(0.5,0), Position = UDim2.new(0.5,0,0, math.max(30, self.gui.AbsoluteSize.Y * 0.12)), Size = UDim2.fromOffset(460, 360), BackgroundColor3 = THEME.popup, ZIndex = 51, ClipsDescendants = true, Parent = overlay }, { corner(10), stroke(THEME.card_stroke) })
    self.command_palette = overlay
    local search = create("TextBox", { Position = UDim2.fromOffset(12,12), Size = UDim2.new(1,-24,0,34), BackgroundColor3 = THEME.field, TextColor3 = THEME.text, PlaceholderText = "Search controls and commands...", PlaceholderColor3 = THEME.text_dim, Text = "", ClearTextOnFocus = false, Font = FONT, TextSize = 14, ZIndex = 52, Parent = panel }, { corner(6), padding(0,0,10,10) })
    local results = create("ScrollingFrame", { Position = UDim2.fromOffset(8,56), Size = UDim2.new(1,-16,1,-64), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 52, Parent = panel }, { list_layout(4) })
    local selected_index = 1
    local entries = {}
    local palette_connection
    local close
    local function add_entry(label: string, detail: string, callback: () -> ())
        local button = create("TextButton", { Size = UDim2.new(1,-4,0,40), BackgroundColor3 = THEME.field, BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 53, Parent = results }, { corner(5) })
        new_label(button, label, { Position = UDim2.fromOffset(10,3), Size = UDim2.new(1,-20,0,17), Font = FONT_BOLD, TextSize = 12, ZIndex = 54 })
        new_label(button, detail, { Position = UDim2.fromOffset(10,20), Size = UDim2.new(1,-20,0,15), TextSize = 10, TextColor3 = THEME.text_dim, ZIndex = 54 })
        local entry = { Button = button, Label = label, Detail = detail, Callback = callback }
        table.insert(entries, entry)
        button.MouseEnter:Connect(function() selected_index = table.find(entries, entry) or 1 end)
        button.MouseButton1Click:Connect(function() safe_call(callback); self:_record_action(label); close() end)
        return entry
    end
    local function build()
        for _, child in ipairs(results:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
        table.clear(entries)
        local query = search.Text:lower()
        for _, element in ipairs(self.elements) do
            local label = tostring(element.Label or "")
            local detail = tostring(element.PageName or "") .. (element.BoxName ~= "" and " / " .. tostring(element.BoxName) or "")
            if query == "" or string.find(label:lower(),query,1,true) or string.find(detail:lower(),query,1,true) then
                add_entry(label, detail, function()
                    for _, nav in ipairs(self.navs) do
                        for _, page in ipairs(nav.pages) do if page.name == element.PageName then self:_select_page(page) end end
                    end
                    if element.Row and element.Row.Parent then
                        local oldColor = element.Row.BackgroundColor3
                        element.Row.BackgroundColor3 = THEME.accent
                        task.delay(0.45, function() if element.Row and element.Row.Parent then element.Row.BackgroundColor3 = oldColor end end)
                    end
                    if element.Type == "Toggle" then element:Set(not element:Get())
                    elseif element.Type == "Dropdown" and #element.Options > 0 then
                        local current = table.find(element.Options, element:Get()) or 0
                        element:Set(element.Options[(current % #element.Options) + 1])
                    elseif element.Type == "MultiDropdown" and #element.Options > 0 then
                        local selected = element:Get()
                        local map = {}; for _, value in ipairs(selected) do map[value] = true end
                        local option = element.Options[1]; map[option] = not map[option] or nil
                        local next_values = {}; for _, value in ipairs(element.Options) do if map[value] then table.insert(next_values, value) end end
                        element:Set(next_values)
                    elseif element.Type == "Slider" then element:Set(element:Get() + (element.Increment or 1))
                    elseif element.Type == "RangeSlider" then local low, high = element:Get(); element:Set(low, high)
                    elseif element.Type == "Textbox" and element.Set then element:Set(element:Get())
                    end
                end)
            end
        end
        for _, action in ipairs(self.recent_actions) do
            if query == "" or string.find(action.Text:lower(),query,1,true) then add_entry("Recent: " .. action.Text, "Recent action", function() end) end
        end
        selected_index = math.clamp(selected_index, 1, math.max(1,#entries))
        for i, entry in ipairs(entries) do entry.Button.BackgroundTransparency = i == selected_index and 0 or 1 end
    end
    close = function() if palette_connection then palette_connection:Disconnect(); palette_connection = nil end; if overlay.Parent then overlay:Destroy() end; if self.command_palette == overlay then self.command_palette = nil end end
    search:GetPropertyChangedSignal("Text"):Connect(build)
    palette_connection = UserInputService.InputBegan:Connect(function(input, processed)
        if not overlay.Parent or processed then return end
        if input.KeyCode == Enum.KeyCode.Escape then close()
        elseif input.KeyCode == Enum.KeyCode.Down then selected_index = math.min(#entries, selected_index + 1); for i,e in ipairs(entries) do e.Button.BackgroundTransparency = i == selected_index and 0 or 1 end
        elseif input.KeyCode == Enum.KeyCode.Up then selected_index = math.max(1, selected_index - 1); for i,e in ipairs(entries) do e.Button.BackgroundTransparency = i == selected_index and 0 or 1 end
        elseif input.KeyCode == Enum.KeyCode.Return and entries[selected_index] then safe_call(entries[selected_index].Callback); self:_record_action(entries[selected_index].Label); close() end
    end)
    build()
    search:CaptureFocus()
end

function Window:EnableCommandPalette(key: Enum.KeyCode?)
    self.command_key = key or Enum.KeyCode.K
    if self.command_binding then key_bindings[self.command_binding] = nil end
    self.command_binding = { get_key = function() return self.command_key end, on_press = function() if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) then self:OpenCommandPalette() end end }
    register_binding(self.command_binding)
end

local function serializable_value(element: any): any
    if element.Type == "RangeSlider" then return { Min = element.MinValue, Max = element.MaxValue } end
    local value = element.Get and element:Get() or nil
    if typeof(value) == "Color3" then return { __type = "Color3", R = value.R, G = value.G, B = value.B } end
    if typeof(value) == "EnumItem" then return { __type = "EnumItem", EnumType = tostring(value.EnumType), Name = value.Name } end
    if type(value) == "table" then
        local out = {}; for k,v in pairs(value) do if type(k) == "string" or type(k) == "number" then out[k] = v end end; return out
    end
    if type(value) == "string" or type(value) == "number" or type(value) == "boolean" then return value end
    return nil
end

function Window:ExportConfig(): string
    local data = { Version = 1, Name = self.config_name, UIScale = self:GetUIScale(), ToggleKey = self:GetToggleKey().Name, Elements = {} }
    for _, element in ipairs(self.elements) do data.Elements[element.Id] = { Type = element.Type, Value = serializable_value(element), Mode = element.Mode, Key = element.Key and element.Key.Name or nil } end
    return HttpService:JSONEncode(data)
end

function Window:ImportConfig(json: string)
    local ok, data = pcall(function() return HttpService:JSONDecode(json) end)
    if not ok or type(data) ~= "table" or type(data.Elements) ~= "table" then return false, "Invalid LegendUI config JSON" end
    self._loading_config = true
    if tonumber(data.UIScale) then self:SetUIScale(data.UIScale) end
    if type(data.ToggleKey) == "string" and Enum.KeyCode[data.ToggleKey] then self:SetToggleKey(Enum.KeyCode[data.ToggleKey]) end
    for _, element in ipairs(self.elements) do
        local saved = data.Elements[element.Id]
        if saved then
            local value = saved.Value
            if type(value) == "table" and value.__type == "Color3" then value = Color3.new(value.R, value.G, value.B)
            elseif type(value) == "table" and value.__type == "EnumItem" then value = Enum.KeyCode[value.Name] end
            pcall(function()
                if element.Type == "RangeSlider" and type(value) == "table" then element:Set(value.Min, value.Max, true)
                elseif element.Set and value ~= nil then
                    if element.Type == "MultiDropdown" then element:Set(value, true)
                    elseif element.Type == "Keybind" then element:Set(type(value) == "string" and Enum.KeyCode[value] or value, true)
                    else element:Set(value, true) end
                end
                if saved.Mode and element.Type == "Toggle" then element.Mode = saved.Mode end
                if saved.Key and element.Type == "Toggle" then element.Key = Enum.KeyCode[saved.Key] end
            end)
        end
    end
    self._loading_config = false
    return true
end

function Window:SaveConfig(name: string?)
    if self._loading_config then return false, "Config is loading" end
    self.config_name = tostring(name or self.config_name or "Default")
    if not (writefile and readfile) then return false, "This environment does not provide file read/write functions; use ExportConfig instead." end
    pcall(function() if makefolder then makefolder("LegendUI") end end)
    pcall(function() if makefolder then makefolder(self.profiles_folder) end end)
    local ok, err = pcall(function() writefile(self.profiles_folder .. "/" .. self.config_name:gsub("[^%w%-%_ ]", "") .. ".json", self:ExportConfig()) end)
    if ok then return true end
    return false, tostring(err)
end

function Window:LoadConfig(name: string?)
    self.config_name = tostring(name or self.config_name or "Default")
    if not readfile then return false, "This environment does not provide file read functions; use ImportConfig instead." end
    local path = self.profiles_folder .. "/" .. self.config_name:gsub("[^%w%-%_ ]", "") .. ".json"
    local ok, contents = pcall(readfile, path)
    if not ok then return false, tostring(contents) end
    return self:ImportConfig(contents)
end

function Window:ListProfiles(): { string }
    local profiles = {}
    if listfiles then
        local ok, files = pcall(listfiles, self.profiles_folder)
        if ok and type(files) == "table" then for _, path in ipairs(files) do local name = tostring(path):match("([^/\\]+)%.json$"); if name then table.insert(profiles, name) end end end
    end
    table.sort(profiles)
    return profiles
end

function Window:DeleteConfig(name: string)
    if not delfile then return false, "This environment does not provide delfile" end
    local path = self.profiles_folder .. "/" .. tostring(name):gsub("[^%w%-%_ ]", "") .. ".json"
    local ok, err = pcall(delfile, path)
    return ok, ok and nil or tostring(err)
end

function Window:ResetToDefaults()
    self._loading_config = true
    for _, element in ipairs(self.elements) do
        pcall(function()
            if element.Default ~= nil and element.Set then element:Set(element.Default, true)
            elseif element.Type == "RangeSlider" then element:Set(element.Min, element.Max, true) end
        end)
    end
    self:SetUIScale(1)
    self._loading_config = false
end

----------------------------------------------------------
-- UNLOAD
----------------------------------------------------------

function Library:Unload()
    root_maid.clean()
    GENV[CLEANUP_KEY] = nil
end

return Library
