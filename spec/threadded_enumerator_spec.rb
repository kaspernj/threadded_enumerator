require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "ThreaddedEnumerator" do
  it "should be able to do enumeration" do
    debug = false
    
    count = 0
    enum = Threadded_enumerator.new(:cache => 10) do |yielder|
      0.upto(100) do |i|
        print "Adding i: #{i}\n" if debug
        yielder << i
        break if i == 75
        count += 1
      end
    end
    
    expect = 0
    enum.each do |num|
      raise "Expected num to be #{expect} but it was: #{num}" if num != expect
      expect += 1
      
      print "Num: #{num}\n" if debug
    end
    
    sleep 0.05
    print "Count: #{count}\n" if debug
    
    raise "Expected count to be 7 but it wasnt: #{count}" if count != 75
    
    
    
    enum = Threadded_enumerator.new do |yielder|
      0.upto(10) do |i|
        yielder << i
      end
    end
    
    begin
      while res = enum.next
        print "Res: #{res}\n" if debug
      end
      
      raise "We should never reach this?"
    rescue StopIteration
      #ignore
    end
  end
  
  it "should work with enumerators" do
    debug = false
    
    enum = Enumerator.new do |yielder|
      0.upto(100) do |i|
        yielder << i
      end
    end
    
    tenum = Threadded_enumerator.new(:enum => enum)
    
    tenum.each do |i|
      print "i: #{i}\n" if debug
    end
  end
  
  it "should not cache unless told to" do
    $count = 0
    debug = false
    
    tenum = Threadded_enumerator.new do |yielder|
      0.upto(100) do |i|
        STDOUT.print "Te: #{i}\n" if debug
        $count = i
        yielder << i
      end
    end
    
    0.upto(5) do
      i = tenum.next
      STDOUT.print "i: #{i}\n" if debug
    end
    
    raise "Expected count to be 5 but it wasnt: #{$count}" if $count != 5
  end
  
  it "should cache when told to" do
    $count = 0
    debug = false
    
    tenum = Threadded_enumerator.new(:cache => 10) do |yielder|
      0.upto(100) do |i|
        STDOUT.print "Te: #{i}\n" if debug
        $count = i
        yielder << i
      end
    end
    
    0.upto(5) do
      i = tenum.next
      STDOUT.print "i: #{i}\n" if debug
    end
    
    raise "Expected count to be 5 but it wasnt: #{$count}" if $count <= 5
  end
  
  it "should execute ensures and GC" do
    require "wref"
    $ensured = false #Used to check if ensures within 'Threadded_enumerator' are executed later.
    debug = false
    
    tenum = Threadded_enumerator.new(:cache => 1) do |yielder|
      begin
        someobj = "Kasper"
        $someobj_wref = Wref.new(someobj) #Used to check GC for objects within 'Threadded_enumerator' later.
        
        0.upto(100) do |i|
          STDOUT.print "Ensure: #{i} (#{yielder.args[:id]})\n" if debug
          yielder << i
        end
      ensure
        STDOUT.print "Ensured!\n" if debug
        $ensured = true #Used to check if ensures within 'Threadded_enumerator' are executed later.
      end
    end
    
    $tenum_wref = Wref.new(tenum)
    
    0.upto(5) do
      tenum.next
    end
    
    raise "Expected ensure to be false but it wasnt: #{$ensured}" if $ensured != false
    
    #Needs to create an object of same class in Ruby 1.9.2.
    tenum = Threadded_enumerator.new(:cache => 1) do |yielder|
      
    end
  end
  
  it "should execute ensures and GC (still)" do
    someobj = "Johan" #Or else 'someobj' wont be GC'ed for some reason.
    
    #Trigger GC-runs to collect everything (sleep and second GC makes it collect all!).
    GC.start
    sleep 0.001
    GC.start
    
    tenum = $tenum_wref.alive?
    raise "Expected threadded enumerator to be GCed, but it wasnt." if tenum
    raise "Expected ensured to be true but it wasnt: #{$ensured}" if !$ensured
    raise "Expected 'someobj' to be GCed, but it wasnt." if $someobj_wref.alive?
  end
end
