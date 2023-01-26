require 'rest-client'
require 'json'

module Jenkins
  class JobClient

    attr_reader :async_mode, :jenkins_url, :jenkins_user, :jenkins_token, :proxy, :job_name, :job_params, :job_timeout

    DEFAULT_TIMEOUT = 30
    INTERVAL_SECONDS = 10

    def initialize(args)
      @jenkins_url = args['INPUT_JENKINS_URL'].chomp('/')
      @jenkins_user = args['INPUT_JENKINS_USER']
      @jenkins_token = args['INPUT_JENKINS_TOKEN']
      @proxy = args['INPUT_PROXY']
      @job_name = args['INPUT_JOB_NAME']
      @job_params = JSON.parse(args['INPUT_JOB_PARAMS'] || '{}')
      @job_timeout = args['INPUT_JOB_TIMEOUT'] || DEFAULT_TIMEOUT
      @async_mode = args['INPUT_ASYNC'].to_s == 'true'
    end

    def call
      queue_item_location = queue_job(job_name, job_params)
      job_run_url = get_job_run_url(queue_item_location, job_timeout)
      output_file = ENV.GITHUB_OUTPUT
      open(output_file, 'a') do |f|
        f << "jenkins_job_url=#{job_run_url}"
      end
      puts "Job run URL: #{job_run_url}"
      

      if @async_mode
        puts "Stopping at the triggering step since the async option is enabled"
        exit(0)
      end

      puts "Observing the job progress"
      job_progress(job_run_url, job_timeout)
      exit(0)
    end

    def perform_request(url, method = :get, **args)
      payload = args.delete(:payload)
      response = RestClient::Request.execute method: method, url: url, payload: payload, user: jenkins_user, password: jenkins_token, proxy: proxy, args: args
      response_code = response.code
      raise "Error on #{method} to #{url} [#{response_code}]" unless (200..299).include? response_code
      response
    end

    def queue_job(job_name, job_params)
      trigger_method = job_params.empty? ? 'build' : 'buildWithParameters'
      job_params = job_params.map { |key, val| [key.to_sym, val] }.to_h
      job_queue_url = "#{jenkins_url}/job/#{job_name}/#{trigger_method}"
      queue_response = perform_request(job_queue_url, :post, payload: job_params)
      queue_response.headers[:location]
    end

    def get_job_run_url(queue_item_location, job_timeout = DEFAULT_TIMEOUT)
      job_run_url = nil
      job_timeout = job_timeout.to_i if job_timeout.is_a? String
      timeout_countdown = job_timeout

      while job_run_url.nil? && timeout_countdown.positive?
        begin
          job_run_response = perform_request("#{queue_item_location}api/json", :get)
          job_run_response_executable = nil
          job_run_response_executable = JSON.parse(job_run_response)['executable']
          if job_run_response_executable
            job_run_url = job_run_response_executable['url']
          end
        rescue
          # NOOP
        end
        if job_run_url.nil?
            timeout_countdown -= sleep(INTERVAL_SECONDS)
        end
      end

      if job_run_url
          return job_run_url
      elsif timeout_countdown.zero?
          fail!("JOB TRIGGER TIMED OUT (After #{job_timeout} seconds)")
      else
          fail!("JOB TRIGGER FAILED.")
      end
      job_run_url
    end

    def job_progress(job_run_url, job_timeout = DEFAULT_TIMEOUT)
      job_timeout = job_timeout.to_i if job_timeout.is_a? String
      job_progress_url = "#{job_run_url}api/json"
      job_log_url = "#{job_run_url}logText/progressiveText"
      build_response = nil
      build_result = nil
      timeout_countdown = job_timeout
      while build_result.nil? and timeout_countdown > 0
        begin
            build_response = perform_request(job_progress_url, :get)
            result = JSON.parse(build_response)['result']
            build_result = result || build_result
        rescue
            # "NOOP"
        end
        if build_result.nil?
            timeout_countdown = timeout_countdown - sleep(INTERVAL_SECONDS)
        elsif build_result == 'ABORTED'
          fail!('JOB ABORTED')
        end
      end
      if build_result == 'SUCCESS'
          puts 'DDL validation with SUCCESS status!'
      elsif timeout_countdown == 0
          fail!("JOB FOLLOW TIMED OUT (After #{job_timeout} seconds)")
      else
        puts "DDL validation with #{build_result} status."
        begin
            log_response = perform_request(job_log_url, :get)
            puts log_response.body.force_encoding('utf-8')
        rescue
            puts 'Couldn\'t retrieve log messages.'
        end
        exit(1)
      end
    end

    def fail!(message = nil)
      puts message if message
      exit(1)
    end
  end
end
