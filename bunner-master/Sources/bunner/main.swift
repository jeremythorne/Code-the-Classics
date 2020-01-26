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
        super.init(image:"eagle", pos:pos)
    }
}

class MyGame {
}

class UI:sgz.Game {
    override func update(app:sgz.App) {
    }

    override func draw(app:sgz.App) {
        app.blit(name:"title", pos:(0, 0))
    }
}

sgz.run(width:Int(WIDTH), height:Int(HEIGHT), game:UI())
