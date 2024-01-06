require "msgpack"

MessagePack::DefaultFactory.register_type(
  MessagePack::Timestamp::TYPE,
  Time,
  packer: MessagePack::Time::Packer,
  unpacker: MessagePack::Time::Unpacker
)

class PersistentMemory
  attr_reader :name, :state

  def initialize(name, initial_state = nil)
    @name = name

    if File.exists?(file_location)
      @state = MessagePack.unpack(File.binread(file_location))
    else
      @state = initial_state
      write_state
    end
  end

  def state=(new_state)
    @state = new_state
    write_state
  end

  private

  def write_state
    File.binwrite(file_location, @state.to_msgpack)
  end

  def file_location
    "mem/#{name}.mem"
  end
end

Dir.mkdir("mem") if !Dir.exists?("mem")
