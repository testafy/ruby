require 'rubygems'
require 'rest-client'
require 'json'
require 'base64'

# This class holds the information necessary to run tests on Testafy's servers.
# It encompasses the API calls, hopefully making integration
# with Testafy as simple as possible.
#
# Author:: David Orr (mailto: dorr@grantstreet.com)
# Copyright 2012 Grant Street Group

module Testafy

    class Test
        attr_accessor :login_name, :pbehave, :test_id, :message, :error, \
            :base_uri, :password, :step_screenshots, :results_type
        
        def self.try_it_now
            t = Test.new("try_it_now", "")
            t.pbehave = %q{#Remember, try_it_now tests can only be 3 lines long 
                # and automatically have a 2-second delay between steps.
                For the url http://testafy.com
                When the "About Us" link is clicked
                Then the text "Community. Efficiency. Innovation. Reliability." is present
                }

            return t
        end

        # Store any known parameters associated with this test. 
        def initialize login_name, password, \
            pbehave = "then pass this test"

            @login_name = login_name
            @pbehave = pbehave
            @base_uri = "https://app.testafy.com/api/v0/"
            @password = password
        end

        # An internal method to make an API call.
        def api_request command, vars=nil
            unless @base_uri
                raise ArgumentError, "No base URI! Please set @base_uri." 
            end
            
            # defaults to passing a test_id, if there is one.
            vars = {"trt_id" => @test_id} if (@test_id and not vars)

            json = JSON.generate(vars)

            begin
                response = JSON.parse(RestClient::Request.execute( \
                        :method => :post, \
                        :url => base_uri + command, \
                        :payload => { :json => json }, \
                        :user => @login_name, \
                        :password => @password \
                    )
                )

                @message = response['message'] unless response['message'].nil?
                @error = response['error'] unless response['error'].nil?

            rescue URI::InvalidURIError
                raise ArgumentError, "Check base_uri, possibly bad hostname"

            rescue RestClient::ExceptionWithResponse => e
                raise if e.http_code != 400
                response = JSON.parse e.response

                @error = response['error'] unless response['error'].nil?
                raise ArgumentError, @error.to_s
            end

            response
        end
        private :api_request

        # Run a test.
        #
        # Return:: 
        #  test_id of the test, which the server uses to identify a 
        #       particular _run_ of a test 
        #       (ie returns a new test_id for every call to run)

        def run

            vars = {"pbehave" => @pbehave}
            vars["screenshots"] = true if @step_screenshots

            path = "test/run"
            path = "try_it_now/run" if login_name == "try_it_now"
            response = api_request path, vars

            @test_id = response["test_run_test_id"]
        end

        # Run a test and wait for it to complete.
        #
        # Return::
        #   test_id of the test, which the server uses to identify a particular
        #       test run.

        def run_and_wait
            id = run
            return nil if id.nil?

            sleep 5 until done?
            return id
        end

        # Get the status of the test
        # Return::
        #   nil if called with an invalid @test_id
        #   One of "unscheduled" "queued" "running" "stopped" or "completed"

        def status
            return nil if @test_id.nil?

            path = "test/status"
            path = "try_it_now/status" if login_name == "try_it_now"
            response = api_request path

            response["status"]
        end

        # Get whether or not a test is done running.
        # Return::
        #   false if the test_id is nil
        #   false if the test has no status, if the status is "queued",
        #       or if the status is "running"
        #   true otherwise

        def done?
            return false if @test_id.nil?

            s = status
            return (!s.nil? and s != "queued" and s != "running")
        end

        # Get the number of "then" statements in the PBehave code that 
        # passed
        # Return::
        #   - the number of "then" statements that passed
        #       nil if called with an invalid @test_id
        #       0 if the test's status is "unscheduled" or "queued"
        #       >= 0 if the test's status is "running" or "completed"

        def passed
            return 0 if @test_id.nil?

            path = "test/stats/passed"
            path = "try_it_now/stats/passed" if login_name == "try_it_now"
            response = api_request path

            response["passed"]
        end

        # Get the number of checks ("then" statements) of the PBehave code that 
        # failed
        # Return::
        #   - the number of "then" statements that failed
        #       nil if called with an invalid @test_id
        #       0 if the test's status is "unscheduled" or "queued"
        #       >= 0 if the test's status is "running" or "completed"

        def failed
            return 0 if @test_id.nil?

            path = "test/stats/failed"
            path = "try_it_now/stats/failed" if login_name == "try_it_now"
            response = api_request path
            response["failed"]
        end

        # Get the total number of "then" statements in the PBehave code
        # planned == passed + failed, for a completed test
        #
        # Return::
        #   nil if called with an invalid @test_id
        #   0 if the test's status is "unscheduled" or "queued"
        #   otherwise, the total number of "then" statements in the test
        #

        def planned
            return 0 if @test_id.nil?

            path = "test/stats/planned"
            path = "try_it_now/stats/planned" if login_name == "try_it_now"
            response = api_request path

            response["planned"]
        end

        # Get the results of a completed test.
        #
        # Return::
        #   - an array containing the lines in the result set.
        #       Results are in TAP (Test Anything Protocol) format.

        def results
            vars = {"trt_id"=> @test_id}
            vars["type" => @results_type] if @results_type

            path = "test/results"
            path = "try_it_now/results" if login_name == "try_it_now"
            response = api_request path, vars
            response["results"]
        end

        def results_string
            res = results
            lines = res.map {|pair| pair[1]}
            str = lines.join("\n")
        end

        # Check the validity of the phrases in the PBehave code for this test
        #
        # Return::
        #   - a string stating whether the PBehave code is valid, and if it 
        #       is not, why it is not.
        def phrase_check
            response = api_request "phrase_check", \
                { "pbehave" => @pbehave }
            response["message"]
        end

        # Get a list of the screenshots for this test run.
        #
        # Return::
        #   filenames
        #       A list of the names of the screenshots on the server. 
        
        def screenshots
            return nil if @test_id.nil?

            path = "test/screenshots"
            path = "try_it_now/screenshots" if login_name == "try_it_now"
            r = api_request path
            return r['screenshots']
        end
       
        # Get a screenshot as a base64 encoded string
        #
        # Parameter::
        #   screenshot_name::
        #       The name of the screenshot to get
        #
        # Return::
        #   screenshot::
        #       A string containing the base64 encoded image
     
        def screenshot_as_base64 screenshot_name
            return nil if @test_id.nil?
      
            vars = {"filename" => screenshot_name, "trt_id" => @test_id}
            path = "test/screenshot"
            path = "try_it_now/screenshot" if login_name == "try_it_now"
            r = api_request path, vars
       
            return r["screenshot"]
        end
       
        # Get a hash containing all of the saved screenshots from this test run
        # as base64 encoded strings
        #
        # Return::
        #   screenshots::
        #       A mapping from screenshot names to the base64 encoded strings containing the screenshots
       
        def all_screenshots_as_base64
            all_screenshots = Hash.new
            screenshots.each do |screenshot_name|
                ss = screenshot_as_base64 screenshot_name
                all_screenshots[screenshot_name] = ss
            end
            return all_screenshots
        end

        # Save a single screenshot from this test run.
        #
        # Parameter::
        #   screenshot_name::
        #       which screenshot to get from the server.
        #   local_filename::
        #       the name to use for the screenshot locally
        #
        # return::
        #   true if the screenshot was successfully saved
        #   false if it was not
       
        def save_screenshot screenshot_name, local_filename
            return false if @test_id.nil?
       
            ss_64 = screenshot_as_base64 screenshot_name
            ss = Base64.decode64 ss_64
        
            File.open(local_filename, "w+") do |f|
                f.write ss
            end
        
            return true
        end

        # Save all screenshots from the current test run
        #
        # Parameter::
        #   local_dir::
        #       The directory in which to save the screenshots
        #
        # Return::
        #   true if the screenshots are all saved successfully,
        #   false otherwise
       
        def save_all_screenshots dir
            return false unless File.directory?(dir) or Dir.mkdir(dir)

            dir += "/" unless dir[-1] == "/"

            screenshots.each do |screenshot_name|
                save_screenshot screenshot_name, dir + screenshot_name
            end

            return true
        end

        # Send a barebones request to the API server. Useful for confirming
        # that everything is set up properly.
        
        def ping
            response = api_request "ping", {}
            response["message"]
        end

    end
end
