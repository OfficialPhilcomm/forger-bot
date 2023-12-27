# frozen_string_literal: true

require "pry"
require "discordrb"
require_relative "config"

module Forger
  class Bot
    def initialize
      @bot = Discordrb::Bot.new(token: Forger::Config.discord.token)

      @last_online = {}
      @offline = []
    end

    def start
      Thread.new do
        while true
          sleep(60)

          update_status_messages
        end
      end

      @bot.run
    end

    private

    def update_status_messages
      Forger::Config.forge.bots.each do |bot|
        id, name, message_id = bot.values_at("id", "name", "message_id")

        is_bot_online = is_bot_online?(id)
        current_time = Time.now

        description = if is_bot_online
          "Status: Online"
        else
          str = ["Status: Offline"]
          str << "Last Recorded Online: <t:#{@last_online[id].to_i}:R>" if @last_online.has_key?(id)
          str.join("\n")
        end
        color = is_bot_online ? 0x57F287.to_i : 0xED4245.to_i

        updates_channel.load_message(message_id).edit(
          nil,
          {
            title: name,
            description: description,
            color: color,
            timestamp: current_time.strftime("%Y-%m-%dT%H:%M:%S.%L%z")
          }
        )

        @last_online[id] = Time.now if is_bot_online

        if @offline.include?(id) && is_bot_online
          @offline.delete(id)

          updates_channel.send_temporary_message(
            "#{name} is back online",
            3600
          )
        end

        if !is_bot_online && !@offline.include?(id)
          @offline.push(id)

          updates_channel.send_temporary_message(
            "#{name} is offline",
            3600
          )
        end
      end
    end

    def is_bot_online?(id)
      @bot.servers[Forger::Config.forge.server_id].users.find do |user|
        user.id == id
      end.online?
    end

    def updates_channel
      @_updates_channel ||= @bot.servers[Forger::Config.forge.server_id].channels.find do |channel|
        channel.id == Forger::Config.forge.updates_channel_id
      end
    end
  end
end
