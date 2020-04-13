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

    func draw(app:sgz.App,_ offset_x:Float,_ offset_y:Float) {
        x += offset_x
        y += offset_y
        draw(app:app)
        for child in children {
            child.draw(app:app, x, y)
        }
        x -= offset_x
        y -= offset_y
    }

    func update(app:sgz.App, game:MyGame) {
        for child in children {
            child.update(app:app, game:game)
        }
    }
}

class Eagle : MyActor {
    init(pos:(x:Float, y:Float)) {
        super.init(image:"eagles", pos:pos)

        children.append(MyActor(image:"eagle", pos:(0, -32)))
    }

    override func update(app:sgz.App, game:MyGame) {
        y += 12
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
    var min_y:Float

    init(pos:(x:Float, y:Float)) {
        super.init(image:"blank", pos:pos)
        min_y = self.y
    }

    func handle_input(app:sgz.App, game:MyGame, dir:Int) {
        for row_o in game.rows {
            if let row = row_o, row.y == y + MOVE_DISTANCE * DY[dir] {
                if row.allow_movement(x + MOVE_DISTANCE * DX[dir]) {
                    direction = dir
                    timer = Int(MOVE_DISTANCE)
                    game.play_sound(app:app, "jump", 1)
                    return
                }
            }
        }
    }

    override func update(app:sgz.App, game:MyGame) {
        for direction in 0..<4 {
            if game.key_just_pressed(
                direction_keys[direction]) {
                input_queue.append(direction)
            }
        }

        if state == PlayerState.ALIVE {
            if timer == 0 && !input_queue.isEmpty {
                handle_input(app:app, game:game,
                             dir:input_queue.remove(at: 0))
            }
            var land = false
            if timer > 0 {
                x += DX[direction]
                y += DY[direction]
                timer -= 1
                land = timer == 0
            }
            var current_row_o:Row? = nil
            for row in game.rows {
                if row?y == y {
                    current_row_o = row
                    break
                }
            }

            if let current_row = current_row_o {
                var col = current_row.check_collision(x)
                state = col.state
                if state == PlayerState.ALIVE {
                    x += current_row.push()
                    if land {
                        current_row.play_sound(app:app, game:game)
                    }
                } else {
                    if state == PlayerState.SPLAT {
                        current_row.children.insert(
                            MyActor(image:"splat\(direction)",
                                    pos:(x, col.dead_obj_y_offset)),
                            at: 0)
                    }
                    timer = 100
                }
            } else {
                if y > game.scroll_pos + HEIGHT + 80 {
                    game.eagle = Eagle(pos:(x:x, y:game.scroll_pos))
                    state = PlayerState.EAGLE
                    timer = 150
                    game.play_sound(app:app, "eagle")
                }
                x = max(16, min(WIDTH - 16, x))
            }
        } else {
            timer -= 1
        }

        min_y = min(min_y, y)
        image = "blank"

        if state == PlayerState.ALIVE {
            if timer > 0 {
                image = "jump\(direction)"
            } else {
                image = "sit\(direction)"
            }
        } else if state == PlayerState.SPLASH && timer > 84 {
            image = "splash\(Int((100 - self.timer) / 2))"
        }
    }
}

class Row : MyActor {
    var index:Int
    var dx:Float = 0
    init(base_image:String, index:Int, y:Float) {
        self.index = index
        super.init(image:base_image + String(index),
                   pos:(0, y),
                   anchor:(sgz.Anchor.Left, sgz.Anchor.Bottom))
    }

    func next() -> Row? {
        return nil
    }

    func collide(x:Float, margin:Float = 0) -> MyActor? {
        for child in children {
            if x >= child.x - (child.width / 2) - margin &&
                x < child.x + (child.width / 2) + margin {
                return child
            }
        }
        return nil
    }

    func push() -> Float {
        return 0
    }

    func play_sound(app:sgz.App, game:MyGame) {
    }

    func allow_movement(_ x:Float) -> Bool {
        return x >= 16 && x <= WIDTH - 16
    }

    func check_collision(_ x:Float) ->
        (state:PlayerState, dead_obj_y_offset:Float) {
            return (PlayerState.ALIVE, 0)
    }
}

class Grass : Row {
    var hedge_row_index:Int?
    var hedge_mask:[Bool]?
    init(predecessor:Row?, index:Int, y:Float) {
        print("Grass::init \(index) \(y)")
        if !predecessor is Grass ||
            let grass = predecessor as! Grass,
             grass.hedge_row_index = nil {
            if Float.random(in:0...<1) < 0.5 && index > 7 && index < 14 {
                hedge_mask = game.generate_hedge_mask()
                hedge_row_index = 0
            }                
        } else if let grass = predecessor as! Grass,
             grass.hedge_row_index = 0 {
            hedge_mask = grass.hedge_mask
            hedge_row_index = 1
        }
        if hedge_row_index != nil {
            var previous_mid_segment:Bool?
            for i in 1...13 {
                var seg = game.classify_hedge_segment(
                    hedge_mask[(i - 1)...(i + 3)], previous_mid_segment)
                previous_mid_segment = seg.mid_segment
                if seg.sprite_x != nil {
                    children.append(
                        Hedge(x:seg.sprite_x, index:hedge_row_index,
                              (i * 40 - 20, 0)))
                }
            }
        }
        }

    override func allow_movement(_ x:Float) -> Bool {
        return super.allow_movement(x) && collide(x: x, margin: 8) != nil
    }
    
    override func play_sound(app:sgz.App, game:MyGame) {
        game.play_sound(app:app, "grass", 1)
    }

    override func next() -> Row? {
        print("Grass::next")
        let new_y = y - Float(ROW_HEIGHT)
        switch(index) {
        case 0...5:
            return Grass(predecessor:self, index:index + 8, y:new_y)
        case 6:
            return Grass(predecessor:self, index:7, y:new_y)
        case 7:
            return Grass(predecessor:self, index:15, y:new_y)
        case 9...14:
            return Grass(predecessor:self, index:index + 1, y:new_y)
        default:
            if Float.random(in:0..<1) < 0.5 {
                return nil //TODO return Road
            }
            return nil //TODO return Water
        }
    }
}

class MyGame {
    var bunner:Bunner?
    var rows:[Row?] = [Grass(predecessor:nil, index:0, y:0)]
    var scroll_pos:Float = -HEIGHT
    var eagle:Eagle?
    var frame = 0

    init(bunner:Bunner? = nil) {
        self.bunner = bunner
    }

    func update(app:sgz.App) {
        print("MyGame::update")
        if let bunner = self.bunner {
            scroll_pos -= max(1, min(3,
                (scroll_pos + HEIGHT - bunner.y) / Float(HEIGHT / 4)))
        } else {
            scroll_pos -= 1
        }
        
        var new_rows = [Row?]()
        for row_o in rows {
            if let row = row_o {
                if row.y < scroll_pos + HEIGHT + Float(ROW_HEIGHT) * 2 {
                    new_rows.append(row)
                }
            }
        }
        rows = new_rows

        while let row = rows[rows.count - 1], row.y > scroll_pos + Float(ROW_HEIGHT) {
            rows.append(row.next())
        }

        for row_o in rows {
            if let row = row_o {
                row.update(app:app, game:self)
            }
        }
        if let bunner = self.bunner {
            bunner.update(app:app, game:self)
        }
        if let eagle = self.eagle {
            eagle.update(app:app, game:self)
        }

        // TODO sounds
    }

    func draw(app:sgz.App) {
        var all_objs = [MyActor]()
        for row_o in rows {
            if let row = row_o {
                all_objs.append(row)
            }
        }

        if let bunner = self.bunner {
            all_objs.append(bunner)
        }

        func sort_key(_ obj:MyActor) -> Int {
            return Int(obj.y + 39) / ROW_HEIGHT
        }

        all_objs.sort { sort_key($0) < sort_key($1) }
        if let eagle = self.eagle {
            all_objs.append(eagle)
        }

        _ = all_objs.map { $0.draw(app:app, 0, -scroll_pos) }
    }

    func score() -> Int {
        guard let bunner = self.bunner else {
            return 0
        }
        return Int(-320 - bunner.min_y) / 40 
    }

    func play_sound(app:sgz.App, _ sound:String, _ count:Int = 0) {
        if self.bunner != nil {
            app.playSound(name:sound + String(Int.random(in:0..<count)))
        }
    }

    func key_just_pressed(_ key:sgz.KeyCode) -> Bool {
        return false
    }

    func generate_hedge_mask() -> [Bool] {
        return [Bool]()
    }

    func classify_hedge_segment(_ mask:[Bool], _ mid_segment:[Bool]?) ->
        (mid_segment:Bool, sprite_x:Float?) {
        return (false, nil)
    }
}

enum State:Int {
    case MENU = 1
    case PLAY = 2
    case GAME_OVER = 3
}

class UI:sgz.Game {
    var state:State = State.MENU
    var game = MyGame()
    var high_score = 0

    override func update(app:sgz.App) {
        switch state {
        case State.MENU:
            if app.pressed(KeyCode.space) {
                state = State.PLAY
                game = MyGame(bunner:Bunner(pos:(240, -320)))
            } else {
                game.update(app:app)
            }
        case State.PLAY:
            if game?bunner.state != PlayerState.ALIVE &&
                game?bunner.timer < 0 {
                high_score = max(high_score, game.score())
                //TODO save high_score to file
                state = State.GAME_OVER
            } else {
                game.update(app:app)
            }
        case State.GAME_OVER:
            if app.pressed(KeyCode.space) {
                state = State.MENU
                game = MyGame()
            }
        }
    }

    func display_number(app:sgz.App,_ n:Int, _ colour:Int, _ x:Int,
                        _ align:Int) {        
        var i = 0
        let ns = String(n)
        for c in ns {
            app.blit(name:"digit\(colour)" + c,
                     pos:(x + (i - ns.count * align) * 25, 0))
            i += 1
        }
    }

    override func draw(app:sgz.App) {
        game.draw(app:app)
        switch state {
        case State.MENU:
            app.blit(name:"title", pos:(0, 0))
            let start_index = 
                [0, 1, 2, 1][(Int(game.scroll_pos) / 6) % 4]
            app.blit(name:"start" + String(start_index),
                pos:((WIDTH - 270) / 2, HEIGHT - 240))
        case State.PLAY:
            display_number(app:app, game.score(), 0, 0, 0)
            display_number(app:app, high_score, 1, Int(WIDTH) - 10, 1)
        case State.GAME_OVER:
            app.blit(name:"gameover", pos:(0,0))
        }
    }

}

sgz.run(width:Int(WIDTH), height:Int(HEIGHT), game:UI())
