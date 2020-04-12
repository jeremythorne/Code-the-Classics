import sgz

let WIDTH:Float = 480
let HEIGHT:Float = 800
let TITLE = "Infinite Bunner"

let ROW_HEIGHT = 40

class MyActor: sgz.Actor {
    var children = [MyActor]()
    override init(image:String, pos:(x:Float, y:Float),
         anchor:(x:sgz.Anchor, y:sgz.Anchor) = 
            (sgz.Anchor.center, sgz.Anchor.bottom)) {
        super.init(image:image, pos:pos, anchor:anchor)
    }

    func draw(app:sgz.App, offset_x:Float, offset_y:Float) {
        self.x += offset_x
        self.y += offset_y
        self.draw(app:app)
        for child in self.children {
            child.draw(app:app, offset_x:self.x, offset_y:self.y)
        }
        self.x -= offset_x
        self.y -= offset_y
    }

    func update(app:sgz.App, game:MyGame) {
        for child in self.children {
            child.update(app:app, game:game)
        }
    }
}

class Eagle : MyActor {
    init(pos:(x:Float, y:Float)) {
        super.init(image:"eagles", pos:pos)

        self.children.append(MyActor(image:"eagle", pos:(0, -32)))
    }

    override func update(app:sgz.App, game:MyGame) {
        self.y += 12
    }
}

enum PlayerState : Int {
    case ALIVE = 0
    case SPLAT = 1
    case SPLASH = 2
    case EAGLE = 3
}

enum Direction : Int {
    case DIRECTION_UP = 0
    case DIRECTION_RIGHT = 1
    case DIRECTION_DOWN = 2
    case DIRECTION_LEFT = 3
}

class Bunner : MyActor {
    let direction_keys = [
        sgz.KeyCode.up,
        sgz.KeyCode.right,
        sgz.KeyCode.down,
        sgz.KeyCode.left
    ]

    let MOVE_DISTANCE:Float = 10

    let DX:[Float] = [0, 4, 0, -4]
    let DY:[Float] = [-4, 0, 4, 0]

    var state:PlayerState = PlayerState.ALIVE
    var direction = 2
    var timer = 2
    var input_queue:[Int] = []
    var min_y:Float = 0

    init(pos:(x:Float, y:Float)) {
        super.init(image:"blank", pos:pos)
        self.min_y = self.y
    }

    func handle_input(game:MyGame, dir:Int) {
        for row in game.rows {
            if row.y == self.y + self.MOVE_DISTANCE * self.DY[dir] {
                if row.allow_movement(self.x + self.MOVE_DISTANCE *
                                        self.DX[dir]) {
                    self.direction = dir
                    self.timer = Int(self.MOVE_DISTANCE)
                    game.play_sound("jump", 1)
                    return
                }
            }
        }
    }

    override func update(app:sgz.App, game:MyGame) {
        for direction in 0..<4 {
            if game.key_just_pressed(
                self.direction_keys[direction]) {
                self.input_queue.append(direction)
            }
        }

        if self.state == PlayerState.ALIVE {
            if self.timer == 0 && !self.input_queue.isEmpty {
                self.handle_input(game:game, dir:self.input_queue.remove(at: 0))
            }
            var land = false
            if self.timer > 0 {
                self.x += self.DX[self.direction]
                self.y += self.DY[self.direction]
                self.timer -= 1
                land = self.timer == 0
            }
            var current_row_o:Row? = nil
            for row in game.rows {
                if row.y == self.y {
                    current_row_o = row
                    break
                }
            }

            if let current_row = current_row_o {
                var state = current_row.check_collision(self.x)
                self.state = state.state
                if self.state == PlayerState.ALIVE {
                    self.x += current_row.push()
                    if land {
                        current_row.play_sound()
                    }
                } else {
                    if self.state == PlayerState.SPLAT {
                        current_row.children.insert(
                            MyActor(image:"splat" + String(self.direction),
                                    pos:(self.x, state.dead_obj_y_offset)),
                            at: 0)
                    }
                    self.timer = 100
                }
            } else {
                if self.y > game.scroll_pos + HEIGHT + 80 {
                    game.eagle = Eagle(pos:(x:self.x, y:game.scroll_pos))
                    self.state = PlayerState.EAGLE
                    self.timer = 150
                    game.play_sound("eagle")
                }
                self.x = max(16, min(WIDTH - 16, self.x))
            }
        } else {
            self.timer -= 1
        }

        self.min_y = min(self.min_y, self.y)
        self.image = "blank"

        if self.state == PlayerState.ALIVE {
            if self.timer > 0 {
                self.image = "jump" + String(self.direction)
            } else {
                self.image = "sit" + String(self.direction)
            }
        } else if self.state == PlayerState.SPLASH && self.timer > 84 {
            self.image = "splash" + String(Int((100 - self.timer) / 2))
        }
    }
}

class Row : MyActor {
    func push() -> Float {
        return 0
    }

    func play_sound() {
    }

    func allow_movement(_ x:Float) -> Bool {
        return true
    }

    func check_collision(_ x:Float) ->
        (state:PlayerState, dead_obj_y_offset:Float) {
            return (PlayerState.ALIVE, 0)
    }
}

class MyGame {
    var rows:[Row] = []
    var scroll_pos:Float = 0
    var eagle:Eagle? = nil

    func play_sound(_ sound:String, _ num:Int = 0) {
    }

    func key_just_pressed(_ key:sgz.KeyCode) -> Bool {
        return false
    }
}

class UI:sgz.Game {
    override func update(app:sgz.App) {
    }

    override func draw(app:sgz.App) {
        app.blit(name:"title", pos:(0, 0))
    }
}

sgz.run(width:Int(WIDTH), height:Int(HEIGHT), game:UI())
