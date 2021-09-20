require 'aws-sdk-cloudformation'
require 'open3'
require 'optparse'
require 'timeout'

TIME_LIMIT = 300
STATUS_CHECK_LIMIT = 10

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

  def check_status(detection_id, attempts)
    begin
      count = 0
      Timeout.timeout(TIME_LIMIT) {
        while count < attempts do
          count += 1
          resp = describe(detection_id)
          if ['DETECTION_COMPLETE', 'DETECTION_FAILED'].include?(resp.detection_status)
            puts("detection_status: #{resp.detection_status}")
            puts("detection_status_reason: #{resp.detection_status_reason}")
            puts("stack_drift_status: #{resp.stack_drift_status}")
            return resp
          end

          # resp.detection_status == 'DETECTION_IN_PROGRESS'
          sleep(10)
        end
      }
      if count == attempts
        puts('Check attempts exceeded.')
      end
    rescue Timeout::Error
      puts 'Timeout'
    end
  end

  def describe(detection_id)
    @@client.describe_stack_drift_detection_status({ stack_drift_detection_id: detection_id })
  end
end

if __FILE__ == $PROGRAM_NAME
  stack_name = nil
  profile = nil

  opt = OptionParser.new
  opt.on('-s', '--stack_name=[stack_name]') { |val| stack_name = val }
  opt.on('-p', '--profile=[profile]') { |val| profile = val }
  opt.parse!(ARGV)

  if stack_name.nil?
    if ARGV[0].nil?
      puts 'Please set a AWS stack name.'
      exit(1)
    else
      stack_name = ARGV[0]
    end
  end

  Worker.set_client(profile)
  detection_id = Worker.detect(stack_name)
  Worker.check_status(detection_id, STATUS_CHECK_LIMIT)
  exit(0)
end
