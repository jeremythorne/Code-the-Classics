import sgz

let WIDTH:Float = 480
let HEIGHT:Float = 800
let TITLE = "Infinite Bunner"

let ROW_HEIGHT = 40

class MyActor: sgz.Actor {
    init(image:String, pos:(x:Float, y:Float)) {
        //TODO support anchor points
        super.init(image:image, center:pos)
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
