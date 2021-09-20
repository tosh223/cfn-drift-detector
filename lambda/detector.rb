require 'aws-sdk-cloudformation'

module Worker
  @@client = nil

  class << self
    def set_client(profile)
      Aws.config[:credentials] = Aws::SharedCredentials.new(profile_name: profile)
      @@client = Aws::CloudFormation::Client.new
    end
  end

  module_function

  def detect(stack_name)
    resp = @@client.detect_stack_drift({ stack_name: stack_name })
    resp.stack_drift_detection_id
  end
end

def handler(event:, context:)
  stack_name = ENV['STACK_ID']
  
  Worker.set_client(profile=nil)
  Worker.detect(stack_name)
end
