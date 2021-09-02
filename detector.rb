require 'aws-sdk-cloudformation'
require 'open3'
require 'optparse'
require 'timeout'

module Stackato
  @@client = nil

  class << self
    def set_client(profile)
      Aws.config[:credentials] = Aws::SharedCredentials.new(profile_name: profile)
      @@client = Aws::CloudFormation::Client.new
    end
  end

  module_function

  def run_cmd!(cmd)
    _, err, status = Open3.capture3(cmd)
    unless err.empty?
      puts err
      exit(status.exitstatus)
    end
    status.exitstatus
  end

  def detect(stack_name)
    resp = @@client.detect_stack_drift({ stack_name: stack_name })
    resp.stack_drift_detection_id
  end

  def check_status(detection_id, attempts)
    begin
      count = 0
      Timeout.timeout(300) {
        while count < attempts do
          count += 1
          # puts("attempts: #{count}")

          resp = describe(detection_id)
          if resp.detection_status == 'DETECTION_COMPLETE'
            puts("#{resp.detection_status}: #{resp.stack_drift_status}")
            return resp.detection_status
          elsif resp.detection_status == 'DETECTION_FAILED'
            puts("#{resp.detection_status}: #{resp.detection_status_reason}")
            return resp.detection_status
          end

          # resp.detection_status == 'DETECTION_IN_PROGRESS'
          sleep(10)
        end
      }
      if count == attempts
        puts('Check attempts exceeded.')
      end
    rescue Timeout::Error
      puts "timeout"
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

  Stackato.set_client(profile)
  detection_id = Stackato.detect(stack_name)
  puts(detection_id)

  resp = Stackato.check_status(detection_id, 10)
  exit(0)
end
