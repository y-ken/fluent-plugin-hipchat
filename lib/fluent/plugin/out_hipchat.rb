
module Fluent
  class HipchatOutput < Output
    COLORS = %w(yellow red green purple gray random)
    FORMAT = %w(html text)
    Fluent::Plugin.register_output('hipchat', self)

    config_param :api_token, :string
    config_param :default_room, :string, :default => nil
    config_param :default_color, :string, :default => nil
    config_param :default_from, :string, :default => nil
    config_param :default_notify, :bool, :default => nil
    config_param :default_format, :string, :default => nil

    config_param :message, :string, :default => nil
    config_param :out_keys, :string, :default => ""
    config_param :time_key, :string, :default => nil
    config_param :tag_key, :string, :default => 'tag'



    attr_reader :hipchat

    def initialize
      super
      require 'hipchat-api'
    end

    def configure(conf)
      super

      @hipchat = HipChat::API.new(conf['api_token'])
      @default_room = conf['default_room']
      @default_from = conf['default_from'] || 'fluentd'
      @default_notify = conf['default_notify'] || 0
      @default_color = conf['default_color'] || 'yellow'
      @default_format = conf['default_format'] || 'html'
    end

    def emit(tag, es, chain)
      es.each {|time, record|
        begin
          send_message(record, tag, time)
        rescue => e
          $log.error("HipChat Error: #{e} / #{e.message}")
        end
      }
    end

    def send_message(record, tag, time)
      room = record['room'] || @default_room
      from = record['from'] || @default_from
      message = record['message'] || evaluate_message(@message, @out_keys, tag, time, record)
      if record['notify'].nil?
        notify = @default_notify
      else
        notify = record['notify'] ? 1 : 0
      end
      color = COLORS.include?(record['color']) ? record['color'] : @default_color
      message_format = FORMAT.include?(record['format']) ? record['format'] : @default_format
      @hipchat.rooms_message(room, from, message, notify, color, message_format)
    end

  def evaluate_message(message, out_keys, tag, time, record)
    values = []
    last = out_keys.length - 1

    values = out_keys.map do |key|
      case key
      when @time_key
        @time_format_proc.call(time)
      when @tag_key
        tag
      else
        record[key].to_s
      end
    end

    (message % values).gsub(/\\n/, "\n")
  end
  end
end
