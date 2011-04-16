
require 'rubygems'
require 'gosu'
require 'chipmunk'
require 'RMagick'
require 'time'
require 'chingu'
require 'opengl'

include Gl,Glu,Glut

SUBSTEPS = 30

# Convenience method for converting from radians to a Vec2 vector.
class Numeric 
   def radians_to_vec2
       CP::Vec2.new(Math::cos(self), Math::sin(self))
   end
end

# Layering of sprites
module ZOrder
   Background, Box = *0..1
end

SCREEN_WIDTH = 1920
SCREEN_HEIGHT = 720
TICK = 1.0/60.0
NUM_SIDES = 4
EDGE_SIZE = 18
END_OF_WORLD = SCREEN_WIDTH * 4
PLAYER_MOVE_XY = 0.1
NUM_POLYGONS = 50
TILE_SIZE = 80
TILES_X = SCREEN_WIDTH / TILE_SIZE
TILES_Y = SCREEN_HEIGHT / TILE_SIZE
  

# Everything appears in the Gosu::Window.
class GameWindow < Chingu::Window 

   def initialize
       super(SCREEN_WIDTH, SCREEN_HEIGHT, false)
       self.caption = "Ez ruby gosu chipmunk experminets"
       @space = CP::Space.new
       @space.iterations = 10
       @space.gravity = CP::Vec2.new(0, 600)
       # you can replace the background with any image with this line
       fill = Magick::TextureFill.new(Magick::ImageList.new("media/tex_049.jpg")) 
       background = Magick::Image.new(SCREEN_WIDTH, SCREEN_HEIGHT, fill)
       @world = World.new(background, @space, self)
       @background_image = Gosu::Image.new(self, background, true) # turn the image into a Gosu one     
       @frame_cnt = 0
       @beginning = Time.now
       @font = Gosu::Font.new(self, Gosu::default_font_name, 20)
       @player = Player.create(:x => 200, :y => 200)
       @player.make(self, @space, 100, 100, @world)

       def setup
         retrofy
         self.factor = 3
         switch_game_state(GState.new(@player))
       end  
   end
    
  			
   def update
       @space.step(TICK)
       @player.resetPosition 

       SUBSTEPS.times do  
         @player.reset_forces
         
         if button_down? Gosu::KbUp
            @player.jump 
         end
            
         if button_down? Gosu::KbLeft
            @player.move_left
         end

         if button_down? Gosu::KbRight
            @player.move_right
         end    
       end
   end

   def draw 
       @background_image.draw(0, 0, ZOrder::Background)
       @world.draw 
       @player.draw

       @frame_cnt += 1
       passed_time = Time.now - @beginning
       @font.draw(("%.2f" % (@frame_cnt/passed_time)), 2, 2, 0, factor_x=1, factor_y=1, color=0xffffffff, mode=:default)
   end
end

class GState < Chingu::GameState
  #
  # This adds accessor 'viewport' to class and overrides draw() to use it.
  #
  trait :viewport
  

  def initialize(player)
    super
    
    self.viewport.lag = 0                           # 0 = no lag, 0.99 = a lot of lag.
    self.viewport.game_area = [0, 0, 4000, 4000]    # Viewport restrictions, full "game world/map/area"    
  
    # Create our mechanic star-hunter
    @player = player
    
  end

  
  def update    
    super
 
    self.viewport.center_around(@player)
        
  end
end

class CreateObjects

   def initialize(space, win)
         @space, @window = space, win
   end 
 # Produces the vertices of a regular polygon.
   def polygon_vertices(sides, size)
       vertices = []
       sides.times do |i|
           angle = -2 * Math::PI * i / sides
           vertices << angle.radians_to_vec2() * size
       end
       return vertices
   end

   # Produces the image of a polygon.
   def polygon_image(vertices)
       box_image = Magick::Image.new(EDGE_SIZE  * 2, EDGE_SIZE * 2) { self.background_color = 'transparent' }
       gc = Magick::Draw.new
       gc.stroke('red')
       gc.fill('plum')
       draw_vertices = vertices.map { |v| [v.x + EDGE_SIZE, v.y + EDGE_SIZE] }.flatten
       gc.polygon(*draw_vertices)
       gc.draw(box_image)
       return Gosu::Image.new(@window, box_image, false)
   end

   # Produces the polygon objects and adds them to the space.
   def create_boxes(num)
       box_vertices = polygon_vertices(NUM_SIDES, EDGE_SIZE)
       box_image = polygon_image(box_vertices)
       boxes =  []
       num.times do
           body = CP::Body.new(1, CP::moment_for_poly(1.0, box_vertices, CP::Vec2.new(0, 0))) # mass, moment of inertia
           body.p = CP::Vec2.new(rand(SCREEN_WIDTH), rand(40) - 50)
           shape = CP::Shape::Poly.new(body, box_vertices, CP::Vec2.new(0, 0))
           shape.e = 0.0
           shape.u = 0.4
           boxes << AObject.new(box_image, body)
           @space.add_body(body)
           @space.add_shape(shape)      
       end
       return boxes
   end

    def circle_image()
       circle_image = Magick::Image.new(20, 20) { self.background_color = 'transparent' }
       gc = Magick::Draw.new
       gc.fill('black').circle(10, 10, 10, 0)
       gc.draw(circle_image)
       return Gosu::Image.new(@window, circle_image, false)
   end

   # Produces the polygon objects and adds them to the space.
   def create_circles(num)
       circle_image = circle_image()
       circles =  []
       num.times do
           body = CP::Body.new(1, CP::moment_for_circle(1.0, 10,10, CP::Vec2.new(0, 0))) # mass, moment of inertia
           body.p = CP::Vec2.new(rand(SCREEN_WIDTH), rand(40) - 50)
           shape = CP::Shape::Circle.new(body, 10, CP::Vec2.new(0, 0))
           shape.e = 0.4
           shape.u = 0.4
           circles << AObject.new(circle_image, body)
           @space.add_body(body)
           @space.add_shape(shape)      
       end
       return circles
   end
end
# The falling boxes class.
# Nothing more than a body and an image.
class AObject

   def initialize(image, body)
       @image = image
       @body = body
   end

   # If it goes offscreen we put it back to the top.

   def moveLeft(dist)
       @body.p.x -= dist
   end

   def moveRight(dist) 
       @body.p.x += dist
   end

    def draw
       @image.draw_rot(@body.p.x, @body.p.y, ZOrder::Box, @body.a.radians_to_gosu)
   end
end


class Player < Chingu::GameObject
   attr_reader :body, :distWorldMoved

   def setup
  
    @player_x, @player_y = @x, @y
    
    update
   end

   def make(win, inThisSpace, startX, startY, world)
      @window = win     
      @space = inThisSpace      
      @player_x, @player_y = startX, startY
      @player_x_previous = @player_x   
      @world = world
      @distWorldMoved = 0
      
      create_player()
   end

    # Produces the vertices of a regular polygon.
   def polygon_vertices(sides, size)
      return [CP::Vec2.new(-size, size), CP::Vec2.new(size, size), CP::Vec2.new(size, -size), CP::Vec2.new(-size, -size)]
   end

   # Produces the polygon objects and adds them to the space.
   def create_player()
       box_vertices = polygon_vertices(NUM_SIDES, EDGE_SIZE)
       @image = init_player_on_window(box_vertices)
       @body = CP::Body.new(1, CP::moment_for_poly(10.0, box_vertices, CP::Vec2.new(0, 0))) # mass, moment of inertia
       @body.p = CP::Vec2.new(@player_x, @player_y)
       shape = CP::Shape::Poly.new(@body, box_vertices, CP::Vec2.new(0, 0))
       shape.e = 0.0
       shape.u = 0.0
       shape.collision_type = :player
       @body.a = (3*Math::PI/2.0) # angle in radians; faces towards top of screen
       @space.add_body(@body)
       @space.add_shape(shape)  
   end

   def init_player_on_window(vertices)
       box_image = Magick::Image.new(EDGE_SIZE  * 2, EDGE_SIZE * 2)
       gc = Magick::Draw.new
       gc.stroke('plum')
       gc.fill('white')
       draw_vertices = vertices.map { |v| [v.x + EDGE_SIZE, v.y + EDGE_SIZE] }.flatten
       gc.polygon(*draw_vertices)
       gc.draw(box_image)
       return Gosu::Image.new(@window, box_image, false)
   end
   
   def resetPosition
      @player_x = @body.p.x
      @x = @player_x
      @y = @body.p.y 
   end   

   def reset_forces
       @body.reset_forces
   end
  
   def canJump?
      return true 
   end 

   def jump
       #@body.apply_force((@body.a.radians_to_vec2 * (230000.0/SUBSTEPS)), CP::Vec2.new(0.0, 0.0)) if canJump?
   end

   def move_left
 
   end
   
   def move_right
  
   end

   def draw
       @image.draw_rot(@body.p.x, @body.p.y, ZOrder::Box, @body.a.radians_to_gosu)
   end

end

class World

   def initialize(background, space,win)
       @background = background
       @space = space
       @window = win
       @worldElements = []
       setup_level()    
   end
   

   def setup_level()
         
         polypoints, polypointsvec = make_triangle_verts(SCREEN_WIDTH, SCREEN_HEIGHT, SCREEN_WIDTH/2, 500, SCREEN_WIDTH/2, SCREEN_HEIGHT) 
         make_earth(polypoints, polypointsvec) #static triangles
         
         polypoints, polypointsvec = make_poly_4(SCREEN_WIDTH/2, SCREEN_HEIGHT, SCREEN_WIDTH/2, 400,0, 100, 0, SCREEN_HEIGHT)         
         make_earth(polypoints, polypointsvec) #static triangles
         objects = CreateObjects.new(@space, @window)
         #b = objects.create_boxes(NUM_POLYGONS)
         #c = objects.create_circles(NUM_POLYGONS)
         #@objects = b + c

   end

   def make_triangle_verts(x1, y1, x2, y2, x3, y3)
       polypointsvec = []
       polypoints = [x1, y1]
       polypointsvec << CP::Vec2.new(x1, y1)
       polypoints += [x2, y2]
       polypointsvec << CP::Vec2.new(x2, y2)
       polypoints += [x3, y3]
       polypointsvec << CP::Vec2.new(x3, y3)

      return polypoints, polypointsvec
   end

   def make_poly_4(x1, y1, x2, y2, x3, y3, x4, y4)
       polypointsvec = []
       polypoints = [x1, y1]
       polypointsvec << CP::Vec2.new(x1, y1)
       polypoints += [x2, y2]
       polypointsvec << CP::Vec2.new(x2, y2)
       polypoints += [x3, y3]
       polypointsvec << CP::Vec2.new(x3, y3)
       polypoints += [x4, y4]
       polypointsvec << CP::Vec2.new(x4, y4)
      return polypoints, polypointsvec
   end

   def make_earth(polypoints, polypointsvec)
       earth = Magick::Image.read('media/tex_059.jpg').first.resize(1.5)
       gc = Magick::Draw.new
       gc.pattern('earth', 0, 0, earth.columns, earth.rows) { gc.composite(0, 0, 0, 0, earth) }    
       gc.fill('earth')
       gc.stroke('#603000').stroke_width(1.5)       
       gc.polygon(*polypoints)
       gc.draw(@background)
       body = CP::Body.new(Float::MAX, Float::MAX)
       shape = CP::Shape::Poly.new(body, polypointsvec, CP::Vec2.new(0, 0))
       shape.e = 1
       shape.u = 1
       @space.add_static_shape(shape)
      
   end
      
   def draw

   end
end



window = GameWindow.new

window.show
