module Fluent
  class RedisOutput < BufferedOutput
    Fluent::Plugin.register_output('rzinc', self)
    attr_reader :host, :port, :db_number, :rzinc, :password, :key, :increment, :match

    def initialize
      super
      require 'redis'
      require 'msgpack'
    end

    def configure(conf)
      super

      @host = conf.has_key?('host') ? conf['host'] : 'localhost'
      @port = conf.has_key?('port') ? conf['port'].to_i : 6379
      @db_number = conf.has_key?('db_number') ? conf['db_number'].to_i : nil
      @password = conf.has_key?('password') ? conf['password'] : nil
      @key = conf.has_key?('key') ? conf['key'] : 'key'
      @regex_match = conf.has_key?('regex_match') ? conf['regex_match'] : nil
      @increment = conf.has_key?('increment') ? conf['increment'].to_i : 1

      if conf.has_key?('namespace')
        $log.warn "namespace option has been removed from fluent-plugin-redis 0.1.3. Please add or remove the namespace '#{conf['namespace']}' manually."
      end
    end

    def start
      super

      @redis = Redis.new(:host => @host, :port => @port,
                         :thread_safe => true, :db => @db_number)

      if ! password.nil? then
        @redis.auth(@password)
	log.info "password=#{@password}"
      end
    end

    def shutdown
      @redis.quit
    end

    def format(tag, time, record)
      identifier = [tag, time].join(".")
      [identifier, record].to_msgpack
    end

    def write(chunk)
      @redis.pipelined {
        chunk.open { |io|
          begin
            MessagePack::Unpacker.new(io).each.each_with_index { |record, index|
	      member = record[1].fetch(@regex_match)
	      @redis.zincrby(@key, @increment, member)
#	      $log.info "ZINCRBY #{@key} #{@increment} #{member}" 
            }
          rescue EOFError
            # EOFError always occured when reached end of chunk.
          end
        }
      }
    end
  end
end
