require 'java'
require 'tree'

java_import 'java.lang.Runnable'
java_import 'java.util.concurrent.Executor'
java_import 'java.util.concurrent.Executors'
java_import 'java.util.concurrent.CountDownLatch'

module Jobbable
   
  attr_accessor :node
  attr_accessor :signal
  
  def run()
    
    before_run()
    s_result = run_job()
    after_run(s_result)
    
    @signal.count_down() unless @signal.nil?
  end
  
  def before_run(); end
  def run_job(); end
  def after_run(s_result=nil); end
  def error_raised(); end
  
end

module BasicJobbable
  include Runnable 
  include Jobbable
  
  attr_accessor :exec_cmd
  attr_accessor :work_dir

  def run_job()
    
    begin 
      s_result = ""
      Dir.chdir(@work_dir) do 
        s_result = %x{#{@exec_cmd}}
      end  
      return s_result
    rescue Exception => o_exc
      error_raised(o_exc) # TODO: think about it more. should it stop all other jobs?
    end
  end
 
end

module SerialJobbable
  include Runnable
  include Jobbable
  
  def run_job()
    begin
      @node.children do |o_child_node|
        o_child_node.content.run()
      end
    rescue Exception => o_exc
      error_raised(o_exc)
    end
  end
end

module ParallelJobbable
  include Runnable
  include Jobbable
  
  def run_job()
    
    o_signal = CountDownLatch.new(@node.children.length)
    o_executor = Executors.new_fixed_thread_pool(@node.children.length)
    
    begin 
    
      @node.children do |o_child_node|
        o_job = o_child_node.content
        o_job.signal = o_signal
        o_executor.execute(o_job)
      end
      
      # initiates an orderly shutdown in which previously submitted tasks are executed, 
      # but no new tasks will be accepted.
      o_executor.shutdown()
      o_signal.await()
      
    rescue Exception => o_exc
      error_raised(o_exc)
    ensure
      o_executor.shutdown()
    end

  end
  
end




