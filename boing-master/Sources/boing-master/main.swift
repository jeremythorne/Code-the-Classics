import sgz

let WIDTH:Float = 800
let HEIGHT:Float = 480
let TITLE = "Boing!"

let HALF_WIDTH = WIDTH / 2.0
let HALF_HEIGHT = HEIGHT / 2.0

let PLAYER_SPEED:Float = 6.0
let MAX_AI_SPEED:Float = 3.0

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

class UpdateableActor:sgz.Actor {
    func update(app:sgz.App, game:MyGame) {
    }
}

class Impact:UpdateableActor {
    var time = 0

    init(center:(x:Float, y:Float)) {
        super.init(image:"blank", center:center)
    }

    override func update(app:sgz.App, game:MyGame) {
        self.image = "impact" + String(self.time / 2)
        self.time += 1
    }
}

class Ball:UpdateableActor {
    var dx:Float = 0
    var dy:Float = 0
    var speed = 5

    init(dx:Float) {
        super.init(image:"ball", center:(0, 0))
        self.x = Float(HALF_WIDTH)
        self.y = Float(HALF_HEIGHT)
        self.dx = dx
    }

    override func update(app:sgz.App, game:MyGame) {
        for _ in 0..<self.speed {
            let original_x = self.x
            self.x += self.dx
            self.y += self.dy

            if abs(self.x - HALF_WIDTH) >= 344 && abs(original_x - HALF_WIDTH) < 344 {
                var new_dir_x:Float = -1.0
                var bat = game.bats[1]
                if self.x < HALF_WIDTH {
                    new_dir_x = 1.0
                    bat = game.bats[0]
                }

                let difference_y  = self.y - bat.y

                if difference_y > -64 && difference_y < 64 {
                    // bounce
                    self.dx = -self.dx
                    self.dy += difference_y / 128
                    self.dy = min(max(self.dy, -1.0), 1.0)
                    let norm = normalised(x:self.dx, y:self.dy)
                    self.dx = norm.x
                    self.dy = norm.y

                    game.impacts.append(Impact(center:(self.x - new_dir_x * 10, self.y)))

                    self.speed += 1
                    game.ai_offset = Float.random(in: -10.0...10.0)
                    bat.timer = 10

                    game.playSound(app:app, "hit", 5)
                    switch(self.speed) {
                    case 0...10:
                        game.playSound(app:app, "hit_slow", 1)
                    case 11...12:
                        game.playSound(app:app, "hit_medium", 1)
                    case 13...16:
                        game.playSound(app:app, "hit_fast", 1)
                    default:
                        game.playSound(app:app, "hit_veryfast", 1)
                    }
                }
            }
            if abs(self.y - HALF_HEIGHT) > 220 {
                // bounce vertically
                self.dy = -self.dy
                self.y += self.dy
                game.impacts.append(Impact(center:(self.x, self.y)))
 
                game.playSound(app:app, "bounce", 5)
                game.playSound(app:app, "bounce_synth", 1)
            }
        }
    }

    func out() -> Bool {
        return self.x < 0 || self.x > WIDTH
    }

}

typealias MoveFunc = (sgz.App) -> Float

class Bat:UpdateableActor {
    var timer = 0
    var score = 0
    var player = 0
    var controls:MoveFunc?

    init(player:Int, controls:MoveFunc?) {
        let x:Float = player == 0 ? 40 : 760
        let y = HALF_HEIGHT
        self.player = player
        self.controls = controls
        super.init(image:"blank", center:(x, y))
    }

    func isAI() -> Bool {
        return self.controls == nil
    }

    override func update(app:sgz.App, game:MyGame) {
        self.timer -= 1
        var y_movement:Float
        if let controls = self.controls {
            y_movement = controls(app)
        } else {
            y_movement = self.ai(app, game)
        }
        self.y = min(400.0, max(80.0, self.y + y_movement))
        var frame = 0
        if self.timer > 0 {
            frame = game.ball.out() ? 2 : 1
        }
        self.image = "bat" + String(self.player) + String(frame)
    }

    func ai(_ app:sgz.App, _ game:MyGame) -> Float {
        let x_distance = abs(game.ball.x - self.x)
        let target_y_1 = HALF_HEIGHT
        let target_y_2 = game.ball.y + game.ai_offset
        let weight1 = min(1.0, x_distance / HALF_WIDTH)
        let weight2 = 1.0 - weight1
        let target_y = (weight1 * target_y_1) + (weight2 * target_y_2)

        return min(MAX_AI_SPEED, max(-MAX_AI_SPEED, target_y - self.y))
    }
}

func p1Controls(app:sgz.App) -> Float {
    var move:Float = 0
    if app.pressed(sgz.KeyCode.z) || app.pressed(sgz.KeyCode.down) {
        move = PLAYER_SPEED
    } else if app.pressed(sgz.KeyCode.a) || app.pressed(sgz.KeyCode.up) {
        move = -PLAYER_SPEED
    }
    return move
}

func p2Controls(app:sgz.App) -> Float {
    var move:Float = 0
    if app.pressed(sgz.KeyCode.m) {
        move = PLAYER_SPEED
    } else if app.pressed(sgz.KeyCode.k) {
        move = -PLAYER_SPEED
    }
    return move
}


class MyGame {
    var bats:[Bat]
    var impacts = [Impact]()
    var ball = Ball(dx:-1.0)
    var ai_offset:Float = 0

    init(controls:(p0:MoveFunc?, p1:MoveFunc?)) {
        self.bats = [Bat(player:0, controls:controls.p0),
                     Bat(player:1, controls:controls.p1)]
    }

    func allObjs() -> [UpdateableActor] {
        var all = [UpdateableActor]()
        for obj in self.bats {
            all.append(obj)
        }
        all.append(self.ball)
        for obj in self.impacts {
            all.append(obj)
        }
        return all
    }

    func update(app:sgz.App) {
        for obj in allObjs() {
            obj.update(app:app, game:self)
        }
 
        var new_impacts = [Impact]()
        for impact in self.impacts {
            if impact.time < 10 {
                new_impacts.append(impact)
            }
        }
        self.impacts = new_impacts

        if self.ball.out() {
            let scoring_player = self.ball.x < HALF_WIDTH ? 1 : 0
            let losing_player = 1 - scoring_player
            if self.bats[losing_player].timer < 0 {
                self.bats[scoring_player].score += 1
                self.playSound(app:app, "score_goal", 1)
                self.bats[losing_player].timer = 20
            } else if self.bats[losing_player].timer == 0 {
                let direction:Float = losing_player == 0 ? -1.0 : 1.0
                self.ball = Ball(dx:direction)
            }
        }
    }

    func draw(app:sgz.App) {
        app.blit(name:"table", pos:(0, 0))
        for p in 0...1 {
            if self.bats[p].timer > 0 && self.ball.out() {
                app.blit(name:"effect" + String(p), pos:(0,0))
            }
        }

        for obj in allObjs() {
            obj.draw(app:app)
        }

        for p in 0...1 {
            let score = characters(from:self.bats[p].score, len:2)
            for i in 0...1 {
                var colour = 0
                let other_p = 1 - p
                if self.bats[other_p].timer > 0 && self.ball.out() {
                    colour = p == 0 ? 2 : 1
                }
                let image = "digit" + String(colour) + String(score[i])
                app.blit(name:image, pos:(Float(255 + (160 * p) + (i * 55))
                                          , 46.0))
            }
        }
    }

    func characters(from:Int, len:Int) -> [Character] {
        var i = from
        var s = [Character]()
        for _ in 0..<len {
            s = [Character(String(i % 10))] + s
            i = i / 10
        }
        return s
    }

    func playSound(app:App, _ name:String, _ count:Int) {
        if !self.bats[0].isAI() {
            app.playSound(name: name + String(Int.random(in:0..<count)))
        }
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
    var game = MyGame(controls:(nil, nil))

    override func update(app:sgz.App) {
        var space_pressed = false
        if app.pressed(sgz.KeyCode.space) && !self.space_down {
            space_pressed = true
        }
        self.space_down = app.pressed(sgz.KeyCode.space)

        switch self.state {
        case State.MENU:
            if space_pressed {
                self.state = State.PLAY
                let controls = (p1Controls,
                                self.num_players == 2 ? p2Controls : nil)
                self.game = MyGame(controls:controls)
            } else {
                if self.num_players == 2 && app.pressed(KeyCode.up) {
                    self.num_players = 1
                } else if self.num_players == 1 && app.pressed(KeyCode.down) {
                    self.num_players = 2
                }
                self.game.update(app:app)
            }
        case State.PLAY:
            if max(self.game.bats[0].score,
                           self.game.bats[1].score) > 9 {
                self.state = State.GAME_OVER
            } else {
                self.game.update(app:app)
            }
        case State.GAME_OVER:
            if space_pressed {
                self.state = State.MENU
                self.num_players = 1
                self.game = MyGame(controls:(nil, nil))
            }
        }
    }

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
