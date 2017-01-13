# frozen_string_literal: true

require_relative "buffer"
require_relative "window"
require_relative "commands"
require_relative "keys"

module Textbringer
  TOP_LEVEL_TAG = Object.new
  RECURSIVE_EDIT_TAG = Object.new

  class Controller
    attr_accessor :this_command, :last_command

    @@current = nil

    def self.current
      @@current
    end

    def self.current=(controller)
      @@current = controller
    end

    def initialize
      @key_sequence = []
      @last_key = nil
      @recursive_edit_level = 0
      @this_command = nil
      @last_command = nil
    end

    def last_key
      @last_key
    end

    def command_loop(tag)
      catch(tag) do
        loop do
          begin
            c = Window.current.getch
            Window.echo_area.clear_message
            @last_key = c
            @key_sequence << @last_key
            cmd = key_binding(@key_sequence)
            if cmd.is_a?(Symbol) || cmd.respond_to?(:call)
              @key_sequence.clear
              @this_command = nil
              begin
                if cmd.is_a?(Symbol)
                  send(cmd)
                else
                  cmd.call
                end
              ensure
                @last_command = @this_command || cmd
              end
            else
              if cmd.nil?
                keys = @key_sequence.map { |c| key_name(c) }.join(" ")
                @key_sequence.clear
                Window.echo_area.show("#{keys} is undefined")
              end
            end
          rescue => e
            Window.echo_area.show(e.to_s.chomp)
            Window.beep
          end
          Window.redisplay
        end
      end
    end

    def recursive_edit
      @recursive_edit_level += 1
      begin
        if command_loop(RECURSIVE_EDIT_TAG)
          raise Quit
        end
      ensure
        @recursive_edit_level -= 1
      end
    end

    private

    def key_name(key)
      case key
      when Integer
        if key < 0x80
          s = Ncurses.keyname(key)
          case s
          when /\AKEY_(.*)/
            "<#{$1.downcase}>"
          else
            s
          end
        else
          key.chr(Encoding::UTF_8)
        end
      else
        key.to_s
      end
    end

    def key_binding(key_sequence)
      Buffer.current.keymap&.lookup(key_sequence) ||
        GLOBAL_MAP.lookup(key_sequence)
    end
  end
end
