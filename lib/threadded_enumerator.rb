require "tsafe"

class Threadded_enumerator
  def initialize(args = {}, &block)
    @args = {
      :cache => 1,
      :block => block
    }.merge(args)
    
    @debug = @args[:debug]
    @yielder = Threadded_enumerator::Yielder.new(@args)
  end
  
  def next
    block_start if !@block_started
    return @yielder.get_result
  end
  
  def each(&block)
    enum = Enumerator.new do |yielder|
      begin
        loop do
          next_res = self.next
          print "Nex: #{next_res}\n" if @debug
          yielder << next_res
        end
      rescue StopIteration
        STDOUT.print "StopIteration!\n" if @debug
        #ignore
      end
      
      print "Done?\n" if @debug
    end
    
    if block
      enum.each(&block)
      return nil
    else
      return enum
    end
  end
  
  private
  
  def block_start
    @block_started = true
    
    Thread.new do
      @yielder.thread = Thread.current
      
      begin
        if @args[:block]
          @args[:block].call(@yielder)
          @yielder.done = true
        elsif enum = @args[:enum]
          begin
            loop do
              @yielder << enum.next
            end
          rescue StopIteration
            #ignore.
          end
        else
          raise "Dont know what to do?"
        end
      rescue => e
        $stderr.puts e.inspect
        $stderr.puts e.backtrace
      ensure
        @yielder.done = true
      end
    end
  end
end

class Threadded_enumerator::Yielder
  attr_accessor :done, :thread
  
  def initialize(args)
    @args = args
    @done = false
    @debug = @args[:debug]
    @results = Tsafe::MonArray.new
  end
  
  def <<(res)
    @results << res
    
    while @results.length >= @args[:cache]
      print "Stopping thread - too many results (#{@results}).\n" if @debug
      Thread.stop
    end
  end
  
  def get_result
    #Wait for results-thread to be spawned before continuing.
    Thread.pass while !@thread
    
    #Raise error if thread results are done spawning (there wont be coming any more).
    raise StopIteration if @done and @results.empty?
    
    #Wait for new result and continue passing thread until results appear.
    while @results.empty?
      raise StopIteration if @done
      @thread.run if !@done and @thread.alive?
      Thread.pass
    end
    
    res = @results.shift
    @thread.run if !@done
    
    print "Returning: #{res}\n" if @debug
    return res
  end
end