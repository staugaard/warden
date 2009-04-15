require File.dirname(__FILE__) + '/../spec_helper'

describe Rack::Auth::Strategies::Base do

  before(:each) do
    RAS = Rack::Auth::Strategies unless defined?(RAS)
    Rack::Auth::Strategies.clear!
  end
  
  describe "headers" do
    it "should have headers" do
      Rack::Auth::Strategies.add(:foo) do
        def authenticate!
          headers("foo" => "bar")
        end
      end
      strategy = Rack::Auth::Strategies[:foo].new(env_with_params)
      strategy._run!
      strategy.headers["foo"].should == "bar"
    end
    
    it "should allow us to clear the headers" do
      Rack::Auth::Strategies.add(:foo) do
        def authenticate!
          headers("foo" => "bar")
        end
      end
      strategy = Rack::Auth::Strategies[:foo].new(env_with_params)
      strategy._run!
      strategy.headers["foo"].should == "bar"
      strategy.headers.clear
      strategy.headers.should be_empty
    end
  end
  
  it "should have a user object" do
    RAS.add(:foobar) do
      def authenticate!
        success!("foo")
      end
    end
    strategy = RAS[:foobar].new(env_with_params)
    strategy._run!
    strategy.user.should == "foo"
  end
  
  it "should allow you to set a message" do
    RAS.add(:foobar) do
      def authenticate!
        self.message = "foo message"
      end
    end
    strategy = RAS[:foobar].new(env_with_params)
    strategy._run!
    strategy.message.should == "foo message"
  end
  
  it "should provide access to the errors" do
    RAS.add(:foobar) do
      def authenticate!
        errors.add(:foo, "foo has an error")
      end
    end
    env = env_with_params
    env['auth.errors'] = Rack::Auth::Proxy::Errors.new
    strategy = RAS[:foobar].new(env)
    strategy._run!
    strategy.errors.on(:foo).should == ["foo has an error"]
  end
  
  describe "halting" do
    it "should allow you to halt a strategy" do
      RAS.add(:foobar) do
        def authenticate!
          halt!
        end
      end
      str = RAS[:foobar].new(env_with_params)
      str._run!
      str.should be_halted
    end
    
    it "should not be halted if halt was not called" do
      RAS.add(:foobar) do
        def authenticate!
          "foo"
        end
      end
      str = RAS[:foobar].new(env_with_params)
      str._run!
      str.should_not be_halted
    end

  end
  
  describe "pass" do
    it "should allow you to pass" do
      RAS.add(:foobar) do
        def authenticate!
          pass
        end
      end
      str = RAS[:foobar].new(env_with_params)
      str._run!
      str.should_not be_halted
      str.user.should be_nil
    end
  end
  
  describe "redirect" do
    it "should allow you to set a redirection" do
      RAS.add(:foobar) do
        def authenticate!
          redirect!("/foo/bar")
        end
      end
      str = RAS[:foobar].new(env_with_params)
      str._run!
      str.user.should be_nil
    end
    
    it "should mark the strategy as halted when redirecting" do
      RAS.add(:foobar) do
        def authenticate!
          redirect!("/foo/bar")
        end
      end
      str = RAS[:foobar].new(env_with_params)
      str._run!
      str.should be_halted
    end
    
    it "should escape redirected url parameters" do
      RAS.add(:foobar) do
        def authenticate!
          redirect!("/foo/bar", :foo => "bar")
        end
      end
      str = RAS[:foobar].new(env_with_params)
      str._run!
      str.headers["Location"].should == "/foo/bar?foo=bar"
    end
    
    it "should allow you to set a message" do
      RAS.add(:foobar) do
        def authenticate!
          redirect!("/foo/bar", {:foo => "bar"}, :message => "You are being redirected foo")
        end
      end
      str = RAS[:foobar].new(env_with_params)
      str._run!
      str.headers["Location"].should == "/foo/bar?foo=bar"
      str.message.should == "You are being redirected foo"
    end
    
    it "should set the action as :redirect" do
      RAS.add(:foobar) do
        def authenticate!
          redirect!("/foo/bar", {:foo => "bar"}, :message => "foo")
        end
      end
      str = RAS[:foobar].new(env_with_params)
      str._run!
      str.result.should == :redirect
    end
  end
  
  describe "failure" do
    
    before(:each) do
      RAS.add(:foobar) do
        def authenticate!
          fail!("You are not cool enough")
        end
      end
      @str = RAS[:foobar].new(env_with_params)
    end
    
    it "should allow you to fail" do
      @str._run!
      @str.user.should be_nil
    end
    
    it "should halt the strategies when failing" do
      @str._run!
      @str.should be_halted
    end
    
    it "should allow you to set a message when failing" do
      @str._run!
      @str.message.should == "You are not cool enough"
    end
    
    it "should set the action as :failure" do
      @str._run!
      @str.result.should == :failure
    end
  end
  
  describe "success" do
    before(:each) do
      RAS.add(:foobar) do
        def authenticate!
          success!("Foo User")
        end
      end
      @str = RAS[:foobar].new(env_with_params)
    end
    
    it "should allow you to succeed" do
      @str._run!
    end
      
    it "should be authenticated after success" do
      @str._run!
      @str.user.should_not be_nil
    end
    
    it "should store the user" do
      @str._run!
      @str.user.should == "Foo User"
    end
    
    it "should set the action as :success" do
      @str._run!
      @str.result.should == :success
    end    
  end
  
  describe "custom response" do
    before(:each) do
      RAS.add(:foobar) do
        def authenticate!
          custom!([521, {"foo" => "bar"}, ["BAD"]])
        end
      end
      @str = RAS[:foobar].new(env_with_params)
      @str._run!
    end
    
    it "should allow me to set a custom rack response" do
      @str.user.should be_nil
    end
    
    it "should halt the strategy" do
      @str.should be_halted
    end
    
    it "should provide access to the custom rack response" do
      @str.custom_response.should == [521, {"foo" => "bar"}, ["BAD"]]
    end
    
    it "should set the action as :custom" do
      @str._run!
      @str.result.should == :custom
    end
  end

end