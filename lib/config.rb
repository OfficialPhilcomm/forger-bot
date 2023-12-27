require "strong_yaml"

module Forger
  class Config
    include StrongYAML

    file "config.yml"

    schema do
      group :discord do
        integer :application_id
        string :public_key
        string :token
      end

      group :forge do
        integer :server_id
        integer :errors_channel_id
        integer :updates_channel_id
        list :bots
      end
    end
  end
end

Forger::Config.create_or_load
