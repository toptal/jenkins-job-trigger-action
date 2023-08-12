require 'rest-client'
require 'json'

module Jenkins
  class JobClient

    attr_reader :jenkins_url, :jenkins_user, :jenkins_token, :job_name, :jenkins_client_id, :job_sa_credentials, :gcr_account_key, :iap_token, :job_params, :job_timeout, :async_mode

    DEFAULT_TIMEOUT = 30
    INTERVAL_SECONDS = 10

    def initialize(args)
      @jenkins_url = ENV['jenkins_url'].chomp('/')
      @jenkins_user = ENV['jenkins_user']
      @jenkins_token = ENV['jenkins_token']
      @job_name = ENV['job_name']
      @iap_token = ENV['iap_token']
      @job_params = JSON.parse(ENV['job_params'] || '{"dummy":"1234"}')
      @job_timeout = ENV['job_timeout'] || DEFAULT_TIMEOUT
      @async_mode = ENV['async'].to_s == 'true'
    end

    def call
      queue_item_location = queue_job(job_name, job_params)
      job_run_url = get_job_run_url(queue_item_location, job_timeout)
      output_file = ENV["GITHUB_OUTPUT"]
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
      url_prefix = 'https://'
      jenkins_url = url.delete_prefix(url_prefix) if url.include?(url_prefix)
      url = "#{url_prefix}#{jenkins_user}:#{jenkins_token}@#{jenkins_url}"
      response = RestClient::Request.execute method: method, url: url, :headers => {"Proxy-Authorization" => "Bearer #{iap_token}", :params => payload}
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
