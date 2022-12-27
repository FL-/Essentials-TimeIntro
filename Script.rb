#===============================================================================
# * Time of Day Introduction - by FL (Credits will be apreciated)
#===============================================================================
#
# This script is for Pokémon Essentials. It show Time of Day message and 
# image (i.e. "Day", "Night"). 
#
#===============================================================================
#
# To this script works, put it above main. Place introductionday.png and 
# introductionnight.png images on Graphics/Pictures . If you don't put, the
# message will be centralized on black background.
#
# The time is displayed when player came outside and time was changed and when
# time change and player already is outside.
# 
#===============================================================================

if !PluginManager.installed?("Time of Day Introduction")
  PluginManager.register({                                                 
    :name    => "Time of Day Introduction",                                        
    :version => "1.0.1",                                                     
    :link    => "https://www.pokecommunity.com/showthread.php?p=10369544",             
    :credits => "FL"
  })
end

module TimeOfDayIntroduction
  # Player can skip when true
  SKIPPABLE = true

  # When true, shows right after the game load
  SHOW_AT_GAME_LOAD = true

  # When false, won't shows if player enter an inside map and exit on same 
  # time of day.
  # i.e. enter house nightime and exits on nightime
  SHOW_ONLY_WHEN_CHANGED = true
  
  @@conf_presets = nil

  class Configuration
    attr_reader   :name
    attr_reader   :proc
    attr_reader   :image_path
    
    def initialize(name, proc, image_path=nil)
      @name = name
      @proc = proc
      @image_path = image_path
    end
  end
  
  # You can create other introduction periods here
  def self.create_conf_presets
    ret = [
      Configuration.new(_INTL("Day"), -> (t){ PBDayNight.isDay?(t)}, "Graphics/Pictures/introductionday.png"),
      Configuration.new(_INTL("Night"), -> (t){ PBDayNight.isNight?(t)}, "Graphics/Pictures/introductionnight.png")
    ]
#    ret = [
#      Configuration.new(_INTL("Morning"), -> (t){ TimeOfDayIntroduction.isMorningXY?(t)}),
#      Configuration.new(_INTL("Day"), -> (t){ TimeOfDayIntroduction.isDayXY?(t)}),
#      Configuration.new(_INTL("Evening"), -> (t){ TimeOfDayIntroduction.isEveningXY?(t)}),
#      Configuration.new(_INTL("Night"), -> (t){ TimeOfDayIntroduction.isNightXY?(t)})
#    ]
    self.check_consistensy(ret)
    return ret
  end
    
  def self.get_conf(time=nil)
    time = pbGetTimeNow if !time
    @@conf_presets = self.create_conf_presets if !@@conf_presets
    for time_conf in @@conf_presets
      return time_conf if time_conf.proc.call(time)
    end
    return nil
  end

  def self.check_consistensy(presets)
    step = 60*60 # Check per hour
    for step_count in 0...((60*60*24)/step)
      count = 0
      time = Time.at(step_count*step)
      for time_conf in presets
        count+=1 if time_conf.proc.call(time)
      end
      time_string = time.strftime("%I:%M %p %S - %s")
      if count != 1
        raise "For time #{time.strftime("%I:%M %p")} there is #{count} correct configurations. There must be only one."
      end
    end
  end

  def self.temp
    return $game_temp || $PokemonTemp # Essentials v19- compatibility
  end

  def self.on_map_update
    return if (temp.in_menu || temp.in_battle || temp.message_window_showing)
    return if $game_player.move_route_forcing || pbMapInterpreterRunning?
    return if !GameData::MapMetadata.exists?($game_map.map_id) || !GameData::MapMetadata.get($game_map.map_id).outdoor_map
    return if temp.last_time_of_day && TimeOfDayIntroduction.get_conf == temp.last_time_of_day
    temp.last_time_of_day = TimeOfDayIntroduction.get_conf
    temp.last_time_of_day_yday = pbGetTimeNow.yday
    return if TimeOfDayIntroduction::SHOW_ONLY_WHEN_CHANGED && temp.last_time_of_day_yday != pbGetTimeNow.yday
    frameCount = Graphics.frame_count
    Graphics.update
    has_freeze = frameCount == Graphics.frame_count
    if has_freeze
      return if !TimeOfDayIntroduction::SHOW_AT_GAME_LOAD
      Graphics.transition(0)
      TimeOfDayIntroduction.start_scene
    else 
      pbFadeOutIn(99999) { TimeOfDayIntroduction.start_scene }
    end
  end
 
  class Scene
    def start_scene(time_of_day_conf)
      @sprites={} 
      @viewport=Viewport.new(0,0,Graphics.width,Graphics.height)
      @viewport.z=999999
      @sprites["background"]=IconSprite.new(0,0,@viewport)
      @sprites["background"].bitmap = Bitmap.new(Graphics.width,Graphics.height)
      @sprites["background"].bitmap.fill_rect(Rect.new(0,0,@sprites["background"].bitmap.width,@sprites["background"].bitmap.height),Color.new(0,0,0))
      load_image = time_of_day_conf.image_path && !time_of_day_conf.image_path.empty?
      if load_image
        @sprites["image"]=IconSprite.new(0,0,@viewport)
        @sprites["image"].setBitmap(time_of_day_conf.image_path)
        @sprites["image"].x=(Graphics.width-@sprites["image"].bitmap.width)/2
        @sprites["image"].y=(Graphics.height-@sprites["image"].bitmap.height)/2
      end
      @sprites["messagebox"]=Window_AdvancedTextPokemon.new(time_of_day_conf.name)
      @sprites["messagebox"].viewport=@viewport
      if !load_image || !@sprites["image"].bitmap
        @sprites["messagebox"].x = (Graphics.width-@sprites["messagebox"].width)/2
        @sprites["messagebox"].y = (Graphics.height-@sprites["messagebox"].height)/2
      end
      pbFadeInAndShow(@sprites) { update }
    end
   
    def update
      pbUpdateSpriteHash(@sprites)
    end
  
    def main
      wait_frames = Graphics.frame_rate*3
      for i in 0...wait_frames
        Graphics.update
        Input.update
        update
        if (Input.trigger?(Input::USE) || Input.trigger?(Input::BACK)) && SKIPPABLE
          break
        end   
      end 
    end
  
    def end_scene
      pbFadeOutAndHide(@sprites) { update }
      pbDisposeSpriteHash(@sprites)
      @viewport.dispose if @viewport
    end
  end
 
  class Screen
    def initialize(scene)
      @scene=scene
    end

    def start_screen(time_of_day_conf)
      @scene.start_scene(time_of_day_conf)
      @scene.main
      @scene.end_scene
    end
  end

  def isMorningXY?(time)
    return time.hour>=4 && time.hour<11
  end

  def isDayXY?(time)
    return time.hour>=11 && time.hour<18
  end

  def isEveningXY?(time)
    return time.hour>=18 && time.hour<21
  end

  def isNightXY?(time)
    return time.hour>=21 || time.hour<4
  end
 
  def self.start_scene
    scene=Scene.new
    screen=Screen.new(scene)
    screen.start_screen(temp.last_time_of_day)
    PBDayNight.recache_tone # Force a tone recache
    pbRefreshSceneMap
  end
end 
  
module PBDayNight
  def self.recache_tone
    getToneInternal
  end
end
 
# Essentials v19- compatibility
if defined?(Events) && Events.respond_to?(:onMapUpdate) 
  Events.onMapUpdate += proc { |_sender,_e|
    TimeOfDayIntroduction.on_map_update
  }
else
  EventHandlers.add(:on_frame_update, :time_of_day_introduction, proc {
    TimeOfDayIntroduction.on_map_update
  })
end

Game_Temp = PokemonTemp if !defined?(Game_Temp) 
class Game_Temp
  attr_accessor :last_time_of_day
  attr_accessor :last_time_of_day_yday
end 