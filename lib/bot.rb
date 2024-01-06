# frozen_string_literal: true

require "pry"
require "json"
require "time"
require "discordrb"
require_relative "config"
require_relative "persistent_memory"

module Forger
  class Bot
    def initialize
      @bot = Discordrb::Bot.new(token: Forger::Config.discord.token)

      @bot.button(custom_id: "resolve_error") do |event|
        embed = event.message.embeds.first

        event.update_message(
          content: nil,
          embeds: [{
            title: embed.title,
            description: embed.description,
            color: 0x57F287.to_i,
            timestamp: Time.now.strftime("%Y-%m-%dT%H:%M:%S.%L%z")
          }],
        )
      end

      @persistent_states = {}

      Forger::Config.forge.bots.each do |bot|
        id = bot["id"]

        @persistent_states[id] = PersistentMemory.new(id, {
          online: false,
          last_seen: Time.now
        })
      end
    end

    def start
      Thread.new do
        while true
          sleep(120)

          begin
            update_status_messages
          rescue StandardError => e
            generate_error_message(errors_channel, e)
          end
        end
      end

      @bot.run
    end

    private

    def update_status_messages
      Forger::Config.forge.bots.each do |bot|
        id, name, message_id = bot.values_at("id", "name", "message_id")
        last_state_online, last_seen = @persistent_states[id].state.values_at("online", "last_seen")

        is_bot_online = is_bot_online?(id)
        current_time = Time.now

        description = if is_bot_online
          "Status: Online"
        else
          str = ["Status: Offline"]
          str << "Last Recorded Online: <t:#{last_seen.to_i}:R>"
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

        if !last_state_online && is_bot_online
          updates_channel.send_temporary_message(
            "#{name} is back online",
            3600
          )
        end

        if !is_bot_online && last_state_online
          updates_channel.send_temporary_message(
            "#{name} is offline",
            3600
          )
        end

        if is_bot_online
          @persistent_states[id].state = {
            online: true,
            last_seen: Time.now
          }
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

    def errors_channel
      @_errors_channel ||= @bot.servers[Forger::Config.forge.server_id].channels.find do |channel|
        channel.id == Forger::Config.forge.errors_channel_id
      end
    end

    def generate_error_message(channel, exception)
      error_message = if exception.respond_to?(:full_message)
        exception.full_message
      else
        exception.message
      end
      error_message = error_message[..1000] + "..." if error_message.length > 1000

      view = Discordrb::Components::View.new

      view.row do |r|
        r.button(label: "Resolve", style: :success, custom_id: "resolve_error")
      end

      channel.send_message(
        nil,
        false,
        {
          title: exception.class.name,
          description: "```#{error_message}```\n```#{exception.backtrace.join("\n")[..2000]}```",
          color: 0xED4245.to_i
        },
        nil,
        nil,
        nil,
        view
      )
    end
  end
end
