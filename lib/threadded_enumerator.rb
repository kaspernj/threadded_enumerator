require "tsafe"
require "timeout"

class Threadded_enumerator
  @@threads = Tsafe::MonHash.new
  
  #Kills waiting threads when 'Threadded_enumerator'-objects are garbage-collected. This makes ensures being executed, objects GC'ed and so on.
  def self.finalizer(id)
    begin
      Timeout.timeout(3) do
        thread = @@threads[id]
        
        #The thread is not always started, if the loop is never called... The thread might not exist for this reason.
        return nil if !thread
        
        #Remove reference.
        @@threads.delete(id)
        
        #Thread is already dead - ignore.
        return nil if !thread.alive?
        
        #Kill thread to release references to objects within and make it execute any ensures within.
        thread.kill
        
        #Check that the thread is actually killed by joining - else the timeout would have no effect, since 'kill' doesnt block. If the thread is never killed, this will be properly be a memory leak scenario, which we report in stderr!
        thread.join
        
        #This will make all sleeps and thread-stops be ignored. Commented out until further... Maybe this is good?
        #thread.run while thread.alive?
      end
    rescue Timeout::Error
      $stderr.puts "Couldnt kill thread #{id} for 'Threadded_enumerator' - possible memory leak detected!"
    rescue Exception => e
      $stderr.puts "Error while killing 'Threadded_enumerator'-thread."
      $stderr.puts e.inspect
      $stderr.puts e.backtrace
      raise e
    end
  end
  
  #Starts a thread which fills the yielder. Its done by this method to allowed GC'ing of 'Threadded_enumerator'-objects.
  def self.block_runner(args)
    @@threads[args[:id]] = Thread.new do
      args[:yielder].thread = Thread.current
      
      begin
        if args[:block]
          args[:block].call(args[:yielder])
          args[:yielder].done = true
        elsif enum = args[:enum]
          begin
            loop do
              args[:yielder] << enum.next
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
        args[:yielder].done = true
      end
    end
  end
  
  def initialize(args = {}, &block)
    @args = {
      :cache => 0,
      :block => block,
      :id => self.__id__
    }.merge(args)
    
    @debug = @args[:debug]
    @yielder = Threadded_enumerator::Yielder.new(@args)
    
    #We use this to kill the block-thread, execute any ensures and release references to any objects within.
    ObjectSpace.define_finalizer(self, Threadded_enumerator.method(:finalizer))
  end
  
  #Returns the next result.
  def next
    block_start if !@block_started
    return @yielder.get_result
  end
  
  #Loops over each result and yields it or returns an enumerator if no block is given.
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
  
  #Starts the thread that spawns the results.
  def block_start
    @block_started = true
    
    #It has to be done this way in order to allowed the GC'ing of the object. Else the thread would contain an alive reference to self.
    Threadded_enumerator.block_runner(:id => self.__id__, :block => @args[:block], :enum => @args[:enum], :yielder => @yielder)
  end
end

class Threadded_enumerator::Yielder
  attr_accessor :args, :done, :thread
  
  def initialize(args)
    @args = args
    @done = false
    @debug = @args[:debug]
    @results = Tsafe::MonArray.new
    @waiting_for_result = 0
  end
  
  #Adds a new result to the yielder.
  def <<(res)
    @results << res
    @waiting_for_result -= 1
    
    while @results.length >= @args[:cache] and @waiting_for_result <= 0
      print "Stopping thread - too many results (#{@results}).\n" if @debug
      Thread.stop
    end
  end
  
  #Returns the next result.
  def get_result
    #Increase count to control cache.
    @waiting_for_result += 1
    
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