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

def launch_url_hinter(data, buffer, argv)
  clear_hints

  return Weechat::WEECHAT_RC_OK unless include_url?(buffer)

  own_lines = Weechat.hdata_pointer(Weechat.hdata_get('buffer'), buffer, 'own_lines')
  line = Weechat.hdata_pointer(Weechat.hdata_get('lines'), own_lines, 'first_line')

  continue_count = get_continue_count(buffer)

  index = 0
  while true
    data = Weechat.hdata_pointer(Weechat.hdata_get('line'), line, 'data')
    message = Weechat.hdata_string(Weechat.hdata_get('line_data'), data, 'message')
    displayed = Weechat.hdata_char(Weechat.hdata_get('line_data'), data, 'displayed').to_s == '1'
    UrlList.push_message(data, message.dup)
    new_message = Weechat.string_remove_color(message, '')
    if new_message =~ /(https?:\/\/[^ \(\)\r\n]*)/
      if index >= continue_count
        url = $1
        new_message = new_message.split(url)
        new_message = "#{new_message[0].to_s + Weechat.color("yellow")}[#{UrlList.add($1).to_s}]#{Weechat.color("red") + url[3..-1].to_s + Weechat.color("blue") + new_message[1].to_s}"
      end
    end
    new_message = "#{Weechat.color('blue')}#{new_message}#{Weechat.color('reset')}"
    Weechat.hdata_update(Weechat.hdata_get('line_data'), data, { 'message' => new_message })

    index += 1 if displayed
    line = Weechat.hdata_pointer(Weechat.hdata_get('line'), line, 'next_line')
    break if line.to_s == ''
  end

  UrlList.hook_pointer = Weechat.hook_signal('input_text_changed', 'my_signal_cb', "")

  Weechat::WEECHAT_RC_OK
end

def hook_process_cb(data, command, rc, stdout, stderr)
  return Weechat::WEECHAT_RC_OK
end

def get_continue_count(buffer)
  own_lines = Weechat.hdata_pointer(Weechat.hdata_get('buffer'), buffer, 'own_lines')

  line_count = Weechat.hdata_integer(Weechat.hdata_get('lines'), own_lines, 'lines_count')
  max_lines  = Weechat.hdata_integer(Weechat.hdata_get('window'), Weechat.current_window, 'win_chat_height')
  line_count - max_lines
end

#
# Check whether if strings like an url 'http://...' or 'https://...' is included in the buffer.
#
def include_url?(buffer)
  line = Buffer.new(buffer).own_lines.first_line

  while true
    return true if line.message =~ /(https?:\/\/[^ \(\)\r\n]*)/
    break unless line = line.next
  end

  false
end

class Buffer
  def initialize(pointer)
    @pointer = pointer
  end

  def own_lines
    own_lines_pointer = Weechat.hdata_pointer(Weechat.hdata_get('buffer'), @pointer, 'own_lines')
    Lines.new(own_lines_pointer)
  end
end

class Lines
  def initialize(pointer)
    @pointer = pointer
  end

  def first_line
    first_line_pointer = Weechat.hdata_pointer(Weechat.hdata_get('lines'), @pointer, 'first_line')
    Line.new(first_line_pointer)
  end
end

class Line
  def initialize(pointer)
    @pointer = pointer
    @data_pointer = Weechat.hdata_pointer(Weechat.hdata_get('line'), @pointer, 'data')
  end

  def message
    Weechat.hdata_string(Weechat.hdata_get('line_data'), @data_pointer, 'message').to_s
  end

  def next
    next_line_pointer = Weechat.hdata_pointer(Weechat.hdata_get('line'), @pointer, 'next_line')
    Line.new(next_line_pointer) unless next_line_pointer.to_s.empty?
  end

  def displayed?
    Weechat.hdata_char(Weechat.hdata_get('line_data'), @data_pointer, 'displayed').to_s == '1'
  end
end

#
# Clear hints.
#
def clear_hints
  UrlList.messages.each {|pointer, message| Weechat.hdata_update(Weechat.hdata_get('line_data'), pointer, { 'message' => message }) }
  UrlList.clear
end
