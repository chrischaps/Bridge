-- Love2D Configuration for Bridge Card Game Suite
function love.conf(t)
    t.identity = "bridge"
    t.version = "11.4"
    t.console = false

    t.window.title = "Klondike Solitaire"
    t.window.icon = nil
    t.window.width = 1280
    t.window.height = 720
    t.window.borderless = false
    t.window.resizable = true
    t.window.minwidth = 960
    t.window.minheight = 540
    t.window.fullscreen = false
    t.window.vsync = 1

    t.modules.audio = true
    t.modules.data = true
    t.modules.event = true
    t.modules.font = true
    t.modules.graphics = true
    t.modules.image = true
    t.modules.joystick = false
    t.modules.keyboard = true
    t.modules.math = true
    t.modules.mouse = true
    t.modules.physics = false
    t.modules.sound = true
    t.modules.system = true
    t.modules.thread = false
    t.modules.timer = true
    t.modules.touch = false
    t.modules.video = false
    t.modules.window = true
end
