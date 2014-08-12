#! /usr/bin/env ruby
# encoding: UTF-8
require 'yaml'

class Game
  MOVE_ACTIONS = ["r", "f"]
  GAME_ACTIONS = ["quit", "q", "save", "s"]
  
  def initialize(board = Board.new)
    @board = board
    @time_elapsed = 0.0
  end
  
  def play
    start_time = Time.new
    
    until game_over?
      draw_board
      player_action = get_input
      return if handle_action(player_action)
      @time_elapsed += Time.new - start_time
    end

    show_board
    draw_board

    puts "You won in #{@time_elapsed.round(2)} seconds! 😃" if won?
    puts "You lost in #{@time_elapsed.round(2)} seconds! 😢" if lost?
  end
  
  def handle_action(player_action)
    action = player_action[:action]
    data = player_action[:data]

    if action == "quit" || action == "q"
      return true
    elsif action == "save" || action == "s"
      save_game(data)
    elsif action == "r"
      @board.reveal!(data)
    else
      @board[data].toggle_flag!
    end
    
    false
  end
  
  def get_input
    begin
      puts "Input F or R for flag or reveal followed by coordinates."
      print "> "
      response = STDIN.gets.chomp.downcase.split
      action = response[0]
      data = nil
      
      # early termination
      if GAME_ACTIONS.include?(action)
        data = true
        data = response[1] if action == "s" || action == "save" 
      elsif MOVE_ACTIONS.include?(action)
        data = [Integer(response[2]) - 1, Integer(response[1]) - 1]
        raise ArgumentError unless @board.valid_pos?(data)
      else
        raise ArgumentError
      end

      { action: action, data: data }
    rescue
      puts "Invalid input. Example: 'F 4 2'"
      retry
    end
  end
  
  def show_board
    @board.grid.each do |row|
      row.each do |tile|
        tile.revealed = true
      end
    end
  end
  
  def draw_board
    print "   |  "
    @board.size.times do |i|
      print "#{i + 1}  "
    end
    
    puts "\n-------------------------------"
    
    i = 0
    @board.grid.each do |row|
      print " #{i + 1} | "
      row.each do |tile|
        print "#{tile.display_char}  "
      end
      puts ""
      i += 1
    end
  end
  
  def game_over?
    won? || lost?
  end
  
  def won?
    safe_tiles = []
    bomb_tiles = []
    
    @board.grid.each do |row|
      row.each do |tile|
        if tile.is_bomb?
          bomb_tiles << tile
        else
          safe_tiles << tile
        end
      end
    end
    
    bomb_tiles.none? { |tile| tile.exploded? } &&
      safe_tiles.all? { |tile| tile.revealed? }
  end
  
  def lost?
    # @board.flatten.any?(&:exploded?)
    @board.grid.any? do |row|
      row.any? do |tile|
        tile.exploded?
      end
    end
  end
  
  def save_game(file)
    print "Saving game to #{file}..."
    
    File.open(file, "w") do |file|
      file << self.to_yaml
    end
    
    puts "done!"
  end
  
  def self.load_game(file)
    puts "Loading game from #{file}..."    
    YAML::load_file(file)
  end
end

class Board
  attr_reader :size, :grid
  
  def initialize(size = 9, bomb_num = 12)
    @size = size
    @grid = Array.new(size) { |x| Array.new(size) { |y| Tile.new(self, [x, y]) } }
    populate_bombs(bomb_num)
  end
  
  def populate_bombs(bomb_num)
    all_pos = (0...size).to_a.product((0...size).to_a)
    all_pos.sample(bomb_num).each do |pos|
      self[pos].plant_bomb!
    end
  end
  
  def reveal!(pos)
    self[pos].reveal!
  end
  
  def valid_pos?(pos)
    pos[0].between?(0, size - 1) && pos[1].between?(0, size - 1)
  end
  
  def [](pos)
    @grid[pos[0]][pos[1]]
  end
  
  def []=(pos, value)
    @grid[pos[0]][pos[1]] = value
  end
end

class Tile
  OFFSETS = [-1, 0, 1].product([-1, 0, 1]) - [[0, 0]]
  DISPLAYS = { 
    0 => "◼️", 
    1 => "1️⃣", 
    2 => "2️⃣", 
    3 => "3️⃣",
    4 => "4️⃣", 
    5 => "5️⃣", 
    6 => "6️⃣", 
    7 => "7️⃣", 
    8 => "8️⃣",
    :bomb => "💣", :flag => "🚩", :hidden => "◻️", :explosion => "💥"
  }
  
  attr_accessor :revealed
  
  def initialize(board, pos)
    @revealed = false
    @flagged = false
    @bombed = false
    @board = board
    @pos = pos
    @explode = false
  end
  
  def display_char
    display = :hidden
    display = neighbor_bomb_count if revealed? && !is_bomb?
    display = :flag if flagged?
    display = :bomb if revealed? && is_bomb?
    display = :explosion if exploded?
  
    DISPLAYS[display]
  end
  
  def plant_bomb!
    @bombed = true
  end
  
  def reveal!
    return if flagged?
    @revealed = true
    @exploded = true if is_bomb?

    return if neighbor_bomb_count > 0
    
    neighbors.each do |tile|
      tile.reveal! unless tile.is_bomb? || tile.revealed?
    end
  end
  
  def toggle_flag!
    @flagged = !@flagged unless revealed?
  end
  
  def is_bomb?
    @bombed
  end
  
  def exploded?
    @exploded && revealed?
  end
  
  def flagged?
    @flagged
  end
  
  def revealed?
    @revealed
  end
  
  def neighbors
    @neighbors ||= [].tap do |neighbors|
      OFFSETS.each do |offset|
        dpos = [@pos[0] + offset[0], @pos[1] + offset[1]]
        neighbors << @board[dpos] if @board.valid_pos?(dpos)
      end
    end
  end
  
  def neighbor_bomb_count
    @count ||= neighbors.count { |tile| tile.is_bomb? }
  end  
end

if __FILE__ == $PROGRAM_NAME
  game = Game.new

  unless ARGV.empty?
    game = Game.load_game(ARGV[0])
  end

  game.play
end