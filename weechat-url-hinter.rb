# coding: utf-8

class UrlList
  HINT_KEYS = 'jfhkgyuiopqwertnmzxcvblasd'
  @@urls = {}
  @@messages = {}
  @@hint_key_index = 0

  class << self
    attr_accessor :hook_pointer

    def clear
      @@urls = {}
      @@messages = {}
      @@hint_key_index = 0
    end

    def add(url)
      hint_key = HINT_KEYS[@@hint_key_index]
      @@urls[hint_key] = url
      @@hint_key_index += 1
      hint_key
    end

    def push_message(pointer, message)
      @@messages[pointer] = message
    end

    def messages
      @@messages
    end

    def get_by(key)
      if @@urls.has_key?(key)
        @@urls[key]
      end
    end

    def has_url?
      @@urls.any?
    end
  end
end

#
# Register url-hinter plugin to weechat and do initialization.
#
def weechat_init
  Weechat.register('weechat-url-hinter', 'Kengo Tateish', '0.1', 'MIT License', 'Open an url in the weechat buffer to type a hint', '', '')
  Weechat.hook_command('url_hinter', 'description', 'args', 'args_description', '', 'launch_url_hinter', '');
  return Weechat::WEECHAT_RC_OK
end

def my_signal_cb(data, signal, signal_type)
  input_key = Weechat.buffer_get_string(Weechat.current_buffer, 'input')

  if url = UrlList.get_by(input_key)
    clear_hints
    Weechat.unhook(UrlList.hook_pointer)
    Weechat.buffer_set(Weechat.current_buffer, 'input', '')

    cmd = "open #{url}"
    Weechat.hook_process(cmd, 10000, "hook_process_cb", "")
  end

  return Weechat::WEECHAT_RC_OK
end

def launch_url_hinter(data, buffer_pointer, argv)
  clear_hints

  buffer = Buffer.new(buffer_pointer)
  return Weechat::WEECHAT_RC_OK unless buffer.has_url?

  continue_count = buffer.own_lines.count - Window.current.chat_height

  index = 0
  buffer.own_lines.each do |line|
    UrlList.push_message(line.data_pointer, line.message.dup)
    new_message = Weechat.string_remove_color(line.message, '')
    if line.has_url?  && index >= continue_count
      line.urls.each do |url|
        new_message.gsub!(url, "#{Weechat.color("yellow")}[#{UrlList.add(url).to_s}]#{Weechat.color("red") + url[3..-1].to_s + Weechat.color("blue")}")
      end
    end
    line.message = "#{Weechat.color('blue')}#{new_message}#{Weechat.color('reset')}"

    index += 1 if line.displayed?
  end

  UrlList.hook_pointer = Weechat.hook_signal('input_text_changed', 'my_signal_cb', "")

  Weechat::WEECHAT_RC_OK
end

#
# Clear hints.
#
def clear_hints
  UrlList.messages.each {|pointer, message| Weechat.hdata_update(Weechat.hdata_get('line_data'), pointer, { 'message' => message }) }
  UrlList.clear
end

#
# Dummy hook callback.
#
def hook_process_cb(data, command, rc, stdout, stderr)
  return Weechat::WEECHAT_RC_OK
end

#----------------------------------
# Wrapper of weechat hdata objects.
#----------------------------------

#
# Wrapper of weechat hdata window.
#
class Window
  class << self
    def current
      Window.new(Weechat.current_window)
    end
  end

  def initialize(pointer)
    @pointer = pointer
  end

  def chat_height
    Weechat.hdata_integer(Weechat.hdata_get('window'), @pointer, 'win_chat_height')
  end
end

#
# Wrapper of weechat hdata buffer.
#
class Buffer
  def initialize(pointer)
    @pointer = pointer
  end

  def own_lines
    own_lines_pointer = Weechat.hdata_pointer(Weechat.hdata_get('buffer'), @pointer, 'own_lines')
    Lines.new(own_lines_pointer)
  end

  def has_url?
    !own_lines.find(&:has_url?).nil?
  end
end

#
# Wrapper of weechat hdata lines.
#
class Lines
  include Enumerable

  def initialize(pointer)
    @pointer = pointer
  end

  def first_line
    first_line_pointer = Weechat.hdata_pointer(Weechat.hdata_get('lines'), @pointer, 'first_line')
    Line.new(first_line_pointer)
  end

  def count
    Weechat.hdata_integer(Weechat.hdata_get('lines'), @pointer, 'lines_count')
  end

  def each
    line = first_line

    while true
      yield(line)
      break unless line = line.next
    end
  end
end

#
# Wrapper of weechat hdata line and line_data.
#
class Line
  attr_reader :data_pointer

  def initialize(pointer)
    @pointer = pointer
    @data_pointer = Weechat.hdata_pointer(Weechat.hdata_get('line'), @pointer, 'data')
  end

  def message
    @message ||= Weechat.hdata_string(Weechat.hdata_get('line_data'), @data_pointer, 'message').to_s
  end

  def message=(new_message)
    Weechat.hdata_update(Weechat.hdata_get('line_data'), @data_pointer, { 'message' => new_message })
  end

  def next
    next_line_pointer = Weechat.hdata_pointer(Weechat.hdata_get('line'), @pointer, 'next_line')
    Line.new(next_line_pointer) unless next_line_pointer.to_s.empty?
  end

  def displayed?
    Weechat.hdata_char(Weechat.hdata_get('line_data'), @data_pointer, 'displayed').to_s == '1'
  end

  def has_url?
    !/https?:\/\/[^ \(\)\r\n]*/.match(message).nil?
  end

  def urls
    message.scan(/https?:\/\/[^ \(\)\r\n]*/).uniq
  end
end
