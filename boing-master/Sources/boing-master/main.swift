import sgz

let WIDTH:Float = 800
let HEIGHT:Float = 480
let TITLE = "Boing!"

let HALF_WIDTH = WIDTH / 2.0
let HALF_HEIGHT = HEIGHT / 2.0

let PLAYER_SPEED:Float = 6.0
let MAX_AI_SPEED:Float = 6.0

func normalised(x:Float, y:Float) -> (x: Float, y:Float) {
    let length = (x * x + y * y).squareRoot()
    return (x / length, y / length)
}

func sign(x:Float) -> Float {
    if x < 0 {
        return -1.0
    }
    return 1.0
}

class Impact:sgz.Actor {
    var time = 0

    init(center:(x:Float, y:Float)) {
        super.init(image:"blank", center:center)
    }

    func update() {
        self.image = "impact" + String(self.time / 2)
        self.time += 1
    }
}

class Ball:sgz.Actor {
    var dx:Float = 0
    var dy:Float = 0
    var speed = 5

    init(dx:Float) {
        super.init(image:"ball", center:(0, 0))
        self.x = Float(HALF_WIDTH)
        self.y = Float(HALF_HEIGHT)
        self.dx = dx
    }

    func update(game:MyGame) {
        for _ in 0..<self.speed {
            let original_x = self.x
            self.x += self.dx
            self.y += self.dy

            if (self.x - HALF_WIDTH).magnitude >= 344 && (original_x - HALF_WIDTH).magnitude < 344 {
                var new_dir_x:Float = -1.0
                var bat = game.bats[1] as! Bat
                if self.x < HALF_WIDTH {
                    new_dir_x = 1.0
                    bat = game.bats[0] as! Bat
                }

                let difference_y  = self.y - bat.y

                if difference_y > -64 && difference_y < 64 {
                    // bounce
                    self.dx = -self.dx
                    self.dy += difference_y / 128
                    self.dy = Float.minimum(Float.maximum(self.dy, -1.0), 1.0)
                    let norm = normalised(x:self.dx, y:self.dy)
                    self.dx = norm.x
                    self.dy = norm.y

                    game.impacts.append(Impact(center:(self.x - new_dir_x * 10, self.y)))

                    self.speed += 1
                    game.ai_offset = Float.random(in: -10.0...10.0)
                    bat.timer = 10
                }
            }
            if (self.y - HALF_HEIGHT).magnitude > 220 {
                // bounce vertically
                self.dy = -self.dy
                self.y += self.dy
                game.impacts.append(Impact(center:(self.x, self.y)))
            }
        }
    }

    func out() -> Bool {
        return self.x < 0 || self.x > WIDTH
    }

}

class Bat:sgz.Actor {
    var timer = 0
    var score = 0
}

func p1_controls(app:sgz.App) -> Float {
    var move:Float = 0
    if app.pressed(sgz.KeyCode.z) || app.pressed(sgz.KeyCode.down) {
        move = PLAYER_SPEED
    } else if app.pressed(sgz.KeyCode.a) || app.pressed(sgz.KeyCode.up) {
        move = -PLAYER_SPEED
    }
    return move
}

func p2_controls(app:sgz.App) -> Float {
    var move:Float = 0
    if app.pressed(sgz.KeyCode.m) {
        move = PLAYER_SPEED
    } else if app.pressed(sgz.KeyCode.k) {
        move = -PLAYER_SPEED
    }
    return move
}

class MyGame {
    var bats = [Actor]()
    var impacts = [Actor]()
    var ai_offset:Float = 0

    func draw(app:sgz.App) {
        app.blit(name:"table", pos:(0, 0))
    }
}

enum State {
    case MENU
    case PLAY
    case GAME_OVER
}

class UI:sgz.Game {
    var state = State.MENU
    var num_players = 1
    var space_down = false
    var game = MyGame()

    override func draw(app:sgz.App) {
        self.game.draw(app:app)

        if self.state == State.MENU {
            let menu_image = "menu" + String(self.num_players - 1)
            app.blit(name:menu_image, pos:(0, 0))
        } else if self.state == State.GAME_OVER {
            app.blit(name:"over", pos:(0, 0))
        }
    }
}

sgz.run(width:Int(WIDTH), height:Int(HEIGHT), game:UI())
