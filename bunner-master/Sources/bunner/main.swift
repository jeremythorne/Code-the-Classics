import sgz

let WIDTH:Float = 480
let HEIGHT:Float = 800
let TITLE = "Infinite Bunner"

let ROW_HEIGHT = 40

var key_status = [sgz.KeyCode:Bool]()

func key_just_pressed(app:sgz.App, _ key:sgz.KeyCode) -> Bool {
    let prev_status:Bool = key_status[key] ?? false
    let result = !prev_status && app.pressed(key)
    key_status[key] = app.pressed(key)
    return result
}


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
    var timer = 0
    var input_queue:[Int] = []
    var min_y:Float = 0

    init(pos:(x:Float, y:Float)) {
        super.init(image:"", pos:pos)
        min_y = y
    }

    func handle_input(app:sgz.App, game:MyGame, dir:Int) {
        print("handle \(dir)")
        for row in game.rows {
            //print("row.y\(row.y) \(y) \(y + MOVE_DISTANCE * DY[dir])")
            if row.y == y + MOVE_DISTANCE * DY[dir] {
                if row.allow_movement(app:app, x + MOVE_DISTANCE * DX[dir]) {
                    direction = dir
                    timer = Int(MOVE_DISTANCE)
                    game.play_sound(app:app, "jump", 1)
                    return
                }
            }
        }
    }

    override func update(app:sgz.App, game:MyGame) {
        for dir in 0..<4 {
            if key_just_pressed(app:app,
                direction_keys[dir]) {
                input_queue.append(dir)
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
                if row.y == y {
                    current_row_o = row
                    break
                }
            }

            if let current_row = current_row_o {
                let col = current_row.check_collision(app:app, game:game, x)
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
        image = ""

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

class MoverBase : MyActor {
    var dx:Float
    init(dx:Float, image:String, pos:(x:Float, y:Float)) {
        self.dx = dx
        super.init(image:image, pos:pos)
    }

    override func update(app:sgz.App, game:MyGame) {
        x += dx
    }
}

protocol MoverInit {
    init(dx:Float, pos:(x:Float, y:Float))
}

typealias Mover = MoverBase & MoverInit

class Car : Mover {
    let SOUND_ZOOM = 0
    let SOUND_HONK = 1
    var played = [false, false]
    var sounds = [("zoom", 6), ("honk", 4)]

    required init(dx:Float, pos:(x:Float, y:Float)) {
        let im = "car\(Int.random(in:0...3))" + (dx < 0 ? "0" : "1")
        super.init(dx:dx, image:im, pos:pos)
    }

    func play_sound(app:sgz.App, game:MyGame, num:Int) {
        if !played[num] {
            let sound = sounds[num]
            game.play_sound(app:app, sound.0, sound.1)
            played[num] = true 
        }
    }
}

class Log : Mover {
    required init(dx:Float, pos:(x:Float, y:Float)) {
        let im = "log\(Int.random(in:0...1))"
        super.init(dx:dx, image:im, pos:pos)
    }
}

class Train : Mover {
    required init(dx:Float, pos:(x:Float, y:Float)) {
        let im = "train\(Int.random(in:0...2))" + (dx < 0 ? "0" : "1")
        super.init(dx:dx, image:im, pos:pos)
    }
}

typealias Row = RowBase & NextRow

protocol NextRow {
    init(predecessor:Row?, index:Int, y:Float)
    func next() -> Row
}

class RowBase : MyActor {
    var index:Int
    var dx:Float = 0

    init(base_image:String, index:Int, y:Float) {
        self.index = index
        super.init(image:base_image + String(index),
                   pos:(0, y),
                   anchor:(sgz.Anchor.left, sgz.Anchor.bottom))
    }

    func collide(app:sgz.App, x:Float, margin:Float = 0) -> MyActor? {
        for child in children {
            if x >= child.x - (Float(child.width(app:app)) / 2) - margin &&
                x < child.x + (Float(child.width(app:app)) / 2) + margin {
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

    func allow_movement(app:sgz.App, _ x:Float) -> Bool {
        return x >= 16 && x <= WIDTH - 16
    }

    func check_collision(app:sgz.App, game:MyGame, _ x:Float) ->
        (state:PlayerState, dead_obj_y_offset:Float) {
            return (PlayerState.ALIVE, 0)
    }
}

typealias ActiveRow = ActiveRowBase & NextRow

class ActiveRowBase : RowBase {
    var timer:Int = 0
    var child_type:Mover.Type
    init(child_type:Mover.Type, dxs:[Float], base_image:String,
         index:Int, y:Float) {
        self.child_type = child_type
        super.init(base_image:base_image, index:index, y:y)
        self.dx = choice(dxs)
        assert(dx != 0)
        var cx = Int(-WIDTH) / 2 - 70
        while cx < Int(WIDTH) / 2 + 70 {
            cx += Int.random(in:240...480)
            let cpos = (WIDTH / 2 + (dx > 0 ? x : -x), Float(0))
            children.append(child_type.init(dx:dx, pos:cpos))
        }
    }

    override func update(app:sgz.App, game:MyGame) {
        super.update(app:app, game:game)
        children = children.filter { $0.x > -70 && $0.x < WIDTH + 70 }
        timer -= 1

        if timer < 0 {
            let cpos = (dx < 0 ? WIDTH + 70 : -70, Float(0))
            children.append(child_type.init(dx:dx, pos:cpos))
            timer = Int((1 + Float.random(in:0..<1)) * 240 / abs(dx))
        }
    }
}

class Hedge : MyActor {
    init(x:Int, y:Int, pos:(Float, Float)) {
        super.init(image:"bush\(x)\(y)", pos:pos)
    }
}

func generate_hedge_mask() -> [Bool] {
    return Array(repeating:false, count:15)
}

func classify_hedge_segment(_ mask:[Bool], _ mid_segment:Bool?) ->
    (mid_segment:Bool, sprite_x:Int?) {
    return (false, nil)
}

func choice<T>(_ list:[T]) -> T {
    return list[Int.random(in:0..<list.count)]
}

class Grass : Row {
    var hedge_row_index:Int?
    var hedge_mask = Array(repeating:false, count:15)
    required init(predecessor:Row?, index:Int, y:Float) {
        super.init(base_image:"grass", index:index, y:y)
        print("Grass::init \(index) \(y)")
        let grass = predecessor as? Grass
        if grass == nil || grass!.hedge_row_index == nil {
            if Float.random(in:0..<1) < 0.5 && index > 7 && index < 14 {
                hedge_mask = generate_hedge_mask()
                hedge_row_index = 0
            }                
        } else if grass!.hedge_row_index == 0 {
            hedge_mask = grass!.hedge_mask
            hedge_row_index = 1
        }
        if hedge_row_index != nil {
            var previous_mid_segment:Bool?
            for i in 1..<13 {
                let seg = classify_hedge_segment(
                    Array(hedge_mask[(i - 1)..<(i + 3)]),
                        previous_mid_segment)
                previous_mid_segment = seg.mid_segment
                if seg.sprite_x != nil {
                    children.append(
                        Hedge(x:seg.sprite_x!, y:hedge_row_index!,
                              pos:(Float(i * 40 - 20), 0)))
                }
            }
        }
    }

    override func allow_movement(app:sgz.App, _ x:Float) -> Bool {
        return super.allow_movement(app:app, x) && collide(app:app, x: x, margin: 8) == nil
    }
    
    override func play_sound(app:sgz.App, game:MyGame) {
        game.play_sound(app:app, "grass", 1)
    }

    func next() -> Row {
        let (row_class, new_index) = { () -> (Row.Type, Int) in
            switch(index) {
            case 0...5:
                return (Grass.self, index + 8)
            case 6:
                return (Grass.self, 7)
            case 7:
                return (Grass.self, 15)
            case 8...14:
                return (Grass.self, index + 1)
            default:
                //return (choice([Road.self, Water.self]), 0)
                return (Road.self, 0)
            }
        } ()
        return row_class.init(predecessor:self, index:new_index,
                         y:y - Float(ROW_HEIGHT))
    }
}

class Dirt : Row {
    required init(predecessor:Row?, index:Int, y:Float) {
        super.init(base_image:"dirt", index:index, y:y)
    }
    
    override func play_sound(app:sgz.App, game:MyGame) {
        game.play_sound(app:app, "dirt", 1)
    }

    func next() -> Row {
        let (row_class, new_index) = { () -> (Row.Type, Int) in
            switch(index) {
            case 0...5:
                return (Dirt.self, index + 8)
            case 6:
                return (Dirt.self, 7)
            case 7:
                return (Dirt.self, 15)
            case 8...14:
                return (Dirt.self, index + 1)
            default:
                // return (choice([Road.self, Water.self]), 0)
                return (Road.self, 0)
            }
        } ()
        return row_class.init(predecessor:self, index:new_index,
                         y:y - Float(ROW_HEIGHT))
    }
}

class Road : ActiveRow {
    required init(predecessor:Row?, index:Int, y:Float) {
        print("Road::init \(index) \(y)")
        var dxs = [Float]()
        for i in -5...5 {
            if i != 0 {
                dxs.append(Float(i))
            }
        }
        if let prev = predecessor {
            dxs = dxs.filter { $0 != prev.dx }
        }
        super.init(child_type:Car.self, dxs:dxs, base_image:"road",
                  index:index, y:y) 
    }

    // TODO update

    override func check_collision(app:sgz.App, game:MyGame, _ x:Float) ->
        (state:PlayerState, dead_obj_y_offset:Float) {
        if collide(app:app, x:x) != nil {
            game.play_sound(app:app, "splat", 1)
            return (PlayerState.SPLAT, 0)
        }
        return (PlayerState.ALIVE, 0)
    }

    override func play_sound(app:sgz.App, game:MyGame) {
        game.play_sound(app:app, "road", 1)
    }

    func next() -> Row {
        let (row_class, new_index) = { () -> (Row.Type, Int) in
            switch(index) {
            case 0:
                return (Road.self, 1)
            case 1..<5:
                switch(Float.random(in:0..<1)) {
                case 0..<0.8:
                    return (Road.self, index + 1)
                case 0.8..<0.88:
                    return (Grass.self, Int.random(in:0...6))
                case 0.88..<0.94:
                    return (Rail.self, 0)
                default:
                    return (Pavement.self, 0)
                }
            default:
                switch(Float.random(in:0..<1)) {
                case 0..<0.6:
                    return (Grass.self, Int.random(in:0...6))
                case 0.6..<0.9:
                    return (Rail.self, 0)
                default:
                    return (Pavement.self, 0)
                }
            }
        } ()
        return row_class.init(predecessor:self, index:new_index,
                                y:y - Float(ROW_HEIGHT))
    }
}

class Pavement : Row {
    required init(predecessor:Row?, index:Int, y:Float) {
        super.init(base_image:"side", index:index, y:y)
    }
    
    override func play_sound(app:sgz.App, game:MyGame) {
        game.play_sound(app:app, "sidewalk", 1)
    }

    func next() -> Row {
        let (row_class, new_index) = { () -> (Row.Type, Int) in
            switch(index) {
            case 0...1:
                return (Pavement.self, index + 1)
            default:
                return (Road.self, 0)
            }
        } ()
        return row_class.init(predecessor:self, index:new_index,
                         y:y - Float(ROW_HEIGHT))
    }
}

class Rail : Row {
    var predecessor:Row?
    required init(predecessor:Row?, index:Int, y:Float) {
        self.predecessor = predecessor
        super.init(base_image:"rail", index:index, y:y)
    }
    
    override func update(app:sgz.App, game:MyGame) {
        super.update(app:app, game:game)
        if index == 1 {
            children = children.filter { $0.x > -1000 &&
                $0.x < WIDTH + 1000 }
            if y < game.scroll_pos + HEIGHT && children.count == 0
                && Float.random(in:0..<1) < 0.01 {
                let dx = Float(choice([-20, 20]))
                children.append(Train(dx:dx, 
                    pos:(dx < 0 ? WIDTH + 1000 : -1000, -13)))
                game.play_sound(app:app, "bell")
                game.play_sound(app:app, "train", 2)
            }
        }
    }

    override func check_collision(app:sgz.App, game:MyGame, _ x:Float) ->
        (state:PlayerState, dead_obj_y_offset:Float) {
        if index == 2 && predecessor?.collide(app:app, x:x) != nil {
            game.play_sound(app:app, "splat", 1)
            return (PlayerState.SPLAT, 8)
        }
        return (PlayerState.ALIVE, 0)
    }

    override func play_sound(app:sgz.App, game:MyGame) {
        game.play_sound(app:app, "grass", 1)
    }

    func next() -> Row {
        let (row_class, new_index) = { () -> (Row.Type, Int) in
            switch(index) {
            case 0..<3:
                return (Rail.self, index + 1)
            default:
                //return (choice([Road.self, Water.self], 0))
                // TODO Water
                return (Road.self, 0)
            }
        } ()
        return row_class.init(predecessor:self, index:new_index,
                         y:y - Float(ROW_HEIGHT))
    }
}

class MyGame {
    var bunner:Bunner?
    var rows:[Row] = [Grass(predecessor:nil, index:0, y:0)]
    var scroll_pos:Float = -HEIGHT
    var eagle:Eagle?
    var frame = 0
    // TODO looped sounds, volume

    init(bunner:Bunner? = nil) {
        self.bunner = bunner
    }

    func update(app:sgz.App) {
        if let bunner = self.bunner {
            scroll_pos -= max(1, min(3,
                (scroll_pos + HEIGHT - bunner.y) / Float(Int(HEIGHT) / 4)))
        } else {
            scroll_pos -= 1
        }
        
        rows = rows.filter {
            $0.y < scroll_pos + HEIGHT + Float(ROW_HEIGHT) * 2
        }

        var row = rows[rows.count - 1]
        while row.y > scroll_pos + Float(ROW_HEIGHT) {
            rows.append(row.next())
            row = rows[rows.count - 1]
        }

        rows.forEach { $0.update(app:app, game:self) }
        bunner?.update(app:app, game:self)
        eagle?.update(app:app, game:self)
        // TODO sounds
    }

    func draw(app:sgz.App) {
        var all_objs = [MyActor]()
        rows.forEach { all_objs.append($0) }

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

        all_objs.forEach { $0.draw(app:app, 0, -scroll_pos) }
    }

    func score() -> Int {
        guard let bunner = self.bunner else {
            return 0
        }
        return Int(-320 - bunner.min_y) / 40 
    }

    func play_sound(app:sgz.App, _ sound:String, _ count:Int = 0) {
        if self.bunner != nil && count > 0 {
            app.playSound(name:sound + String(Int.random(in:0..<count)))
        }
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
        case .MENU:
            if key_just_pressed(app:app, KeyCode.space) {
                state = State.PLAY
                game = MyGame(bunner:Bunner(pos:(240, -320)))
            } else {
                game.update(app:app)
            }
        case .PLAY:
            if let bunner = game.bunner,
                    bunner.state != PlayerState.ALIVE &&
                    bunner.timer < 0 {
                high_score = max(high_score, game.score())
                //TODO save high_score to file
                state = State.GAME_OVER
            } else {
                game.update(app:app)
            }
        case .GAME_OVER:
            if key_just_pressed(app:app, KeyCode.space) {
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
            app.blit(name:"digit\(colour)" + String(c),
                     pos:(Float(x + (i - ns.count * align) * 25), 0))
            i += 1
        }
    }

    override func draw(app:sgz.App) {
        game.draw(app:app)
        switch state {
        case .MENU:
            app.blit(name:"title", pos:(0, 0))
            let start_index = 
                [0, 1, 2, 1][(Int(abs(game.scroll_pos)) / 6) % 4]
            app.blit(name:"start" + String(start_index),
                pos:((WIDTH - 270) / 2, HEIGHT - 240))
        case .PLAY:
            display_number(app:app, game.score(), 0, 0, 0)
            display_number(app:app, high_score, 1, Int(WIDTH) - 10, 1)
        case .GAME_OVER:
            app.blit(name:"gameover", pos:(0,0))
        }
    }

}

sgz.run(width:Int(WIDTH), height:Int(HEIGHT), game:UI())
