
require 'rubygems'
require 'gosu'
require 'chipmunk'
require 'RMagick'
require 'time'

SUBSTEPS = 6

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

SCREEN_WIDTH = 1280
SCREEN_HEIGHT = 1024
TICK = 1.0/60.0
NUM_SIDES = 4
EDGE_SIZE = 15
END_OF_WORLD = SCREEN_WIDTH * 4
PLAYER_MOVE_XY = 0.8

# Everything appears in the Gosu::Window.
class DemoWindow < Gosu::Window

   def initialize
       super(SCREEN_WIDTH, SCREEN_HEIGHT, false)
       self.caption = "Ez ruby gosu chipmunk experminets"
       @space = CP::Space.new
       @space.iterations = 5
       @space.gravity = CP::Vec2.new(0, 300)
       # you can replace the background with any image with this line
       fill = Magick::TextureFill.new(Magick::ImageList.new("media/Splatter.jpg")) 
       background = Magick::Image.new(SCREEN_WIDTH, SCREEN_HEIGHT, fill)
       @world = World.new(background, @space, self)
       @background_image = Gosu::Image.new(self, background, true) # turn the image into a Gosu one     
       @frame_cnt = 0
       @beginning = Time.now
       @font = Gosu::Font.new(self, Gosu::default_font_name, 20)
       @player = Player.new(self, @space, 200, 200, @world)
   end
  			
   def update
       @space.step(TICK)

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
       if @player then 
            @player.draw
            @world.draw
       end 
       @frame_cnt += 1
       passed_time = Time.now - @beginning
       @font.draw(("%.2f" % (@frame_cnt/passed_time)), 2, 2, 0, factor_x=1, factor_y=1, color=0xffffffff, mode=:default)
        
   end
end


class Player 
   attr_reader :body

   def initialize(win, inThisSpace, startX, startY, world)
      @window = win     
      @space = inThisSpace      
      @player_x, @player_y = startX, startY      
      @world = world
      @middle_area_left = (SCREEN_WIDTH/2 - SCREEN_WIDTH/10) 
      @middle_area_right = (SCREEN_WIDTH/2 + SCREEN_WIDTH/10) 
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
       @body = CP::Body.new(1, CP::moment_for_poly(1.0, box_vertices, CP::Vec2.new(0, 0))) # mass, moment of inertia
       @body.p = CP::Vec2.new(@player_x, @player_y)
       shape = CP::Shape::Poly.new(@body, box_vertices, CP::Vec2.new(0, 0))
       shape.e = 0.0
       shape.u = 0.4
       @body.a = (3*Math::PI/2.0) # angle in radians; faces towards top of screen
       @space.add_body(@body)
       @space.add_shape(shape)  
   end

   def init_player_on_window(vertices)
       box_image = Magick::Image.new(EDGE_SIZE  * 2, EDGE_SIZE * 2)
       gc = Magick::Draw.new
       gc.stroke('red')
       gc.fill('plum')
       draw_vertices = vertices.map { |v| [v.x + EDGE_SIZE, v.y + EDGE_SIZE] }.flatten
       gc.polygon(*draw_vertices)
       gc.draw(box_image)
       return Gosu::Image.new(@window, box_image, false)
   end
   
   def reset_forces
       @body.reset_forces
   end

   def jump
       @body.apply_force((@body.a.radians_to_vec2 * (10000.0/SUBSTEPS)), CP::Vec2.new(0.0, 0.0))
   end

   def move_left
       @player_x -= PLAYER_MOVE_XY
       if ((@player_x <= (SCREEN_WIDTH/2 - SCREEN_WIDTH/10)) || (@player_x >= @middle_area_left))
         @body.p.x -= PLAYER_MOVE_XY
       else 
         @world.moveWorldRight(PLAYER_MOVE_XY)
       end
      
      puts @middle_area_left
       
       if ((@player_x < @middle_area_left) && (@middle_area_left > (SCREEN_WIDTH/2 - SCREEN_WIDTH/10)))
         @middle_area_left -= PLAYER_MOVE_XY 
         @middle_area_right -= PLAYER_MOVE_XY 
       end
   end
   
   def move_right
       if @player_x < END_OF_WORLD 
         @player_x += PLAYER_MOVE_XY
         if ((@player_x >= (END_OF_WORLD - SCREEN_WIDTH/10)) || (@player_x <= @middle_area_right))
            @body.p.x += PLAYER_MOVE_XY
         else
            @world.moveWorldLeft(PLAYER_MOVE_XY)
         end

         if ((@player_x > @middle_area_right) && (@middle_area_right < (END_OF_WORLD - SCREEN_WIDTH/10)))
            @middle_area_right += PLAYER_MOVE_XY
            @middle_area_left += PLAYER_MOVE_XY
         end
      end
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
      (1..180).each do |i|
         make_earth(100 + (i*30) , 630, 15, 30)
      end
   end

   def make_earth(x, y, base, height)
       fill = Magick::GradientFill.new(0, height * 0.4, base*2, height * 0.4, '#fff', '#666')
       box_image = Magick::Image.new(base*2, height+12, fill)
       gc = Magick::Draw.new 
       gc.fill('brown')
       # all the triangles are part of the same body
       body = CP::Body.new(Float::MAX, Float::MAX)   
       #body.p = CP::Vec2.new(x, y)   
       shape_vertices =  [CP::Vec2.new(-base, base), CP::Vec2.new(base, base), CP::Vec2.new(base, -height), CP::Vec2.new(-base, -height)]
       shape = CP::Shape::Poly.new(body, shape_vertices, CP::Vec2.new(x, y))
       shape.e = 1
       shape.u = 1
       shape.collision_type = :earth
       @space.add_static_shape(shape)
       gc.polygon(x - base + 1, y + base - 1, x + base - 1, y + base - 1,  x + base, y - height + 1,  x - base, y - height + 1)
       gc.draw(@background) 
       worldElement = []
       worldElement << Gosu::Image.new(@window, box_image, false) 
       worldElement << body 
       worldElement << x-15
       worldElement << y-29
       @worldElements << worldElement
   end
      
   def moveWorldLeft(dist)
      @worldElements.each do |e| 
            e[1].p.x -= dist
            e[2] -= dist  
         end
      @space.rehash_static
   end

   def moveWorldRight(dist)
      @worldElements.each do |e| 
            e[1].p.x += dist
            e[2] += dist  
         end
      @space.rehash_static
   end


   def draw
      @worldElements.each do |e|  
         e[0].draw(e[2], e[3], ZOrder::Box)     
      end
   end
end


window = DemoWindow.new

window.show
