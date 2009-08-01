require File.dirname(__FILE__) + '/test_helper.rb'

require "runit/testcase"

class ClickClient_BaseTest <  RUNIT::TestCase
  
  def setup
  end

  def teardown
  end
  
  def test_equals
    model  = TestModel.new("a","aaa")
    model2 = TestModel.new("a","aaa")
    assert model != model2
    assert model.eql?(model2)
    assert model.hash == model2.hash
    
    model3 = TestModel.new("b","aaa")
    assert model != model3
    assert !model.eql?(model3)
    assert model.hash != model3.hash
    assert model2 != model3
    assert !model2.eql?(model3)
    assert model2.hash != model3.hash
    
    model3 = TestModel.new("b","bbb")
    assert model != model3
    assert !model.eql?(model3)
    assert model.hash != model3.hash
    assert model2 != model3
    assert !model2.eql?(model3)
    assert model2.hash != model3.hash   
    
    model3 = nil
    assert model != model3
    assert !model.eql?(model3)
    assert model.hash != model3.hash
    assert model2 != model3
    assert !model2.eql?(model3)
    assert model2.hash != model3.hash
               
  end
  
  def test_set_get
    model  = TestModel.new("a","a")
    assert_equals model.text, "a"
    
    model.text = "x"    
    assert_equals model.text, "x"
  end
  
  class TestModel < ClickClient::Base
    def initialize( title, text )
      @title = title, text
      @text  = text
    end
  end
  
end