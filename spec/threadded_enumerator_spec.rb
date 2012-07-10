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
end
