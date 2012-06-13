require 'rubygems'
require 'rest-client'
require 'json'

# This class holds the information necessary to run tests on Testafy's servers.
# It encompasses the API calls, hopefully making integration
# with Testafy as simple as possible.
#
# Author:: David Orr (mailto: dorr@grantstreet.com)
# Copyright 2012 Grant Street Group

module Testafy

    class Test
        attr_accessor :login_name, :pbehave, \
            :test_id, :message, :error, :base_uri, :password

        # Store any known parameters associated with this test. 
        def initialize login_name, password, \
            pbehave = "For the url http://www.google.com\nthen pass this test",

            @login_name = login_name
            @pbehave = pbehave
            @base_uri = base_uri
            @product = "Google"
            @password = password
        end

        # Return the stored test parameters as JSON, as required by the server.
        def json
            vars = {}
            vars["pbehave"] = @pbehave
            vars["product"] = @product
            vars["asynchronous"] = true
            vars["trt_id"] = @test_id unless @test_id.nil?

            JSON.generate(vars)
        end

        # An internal method to generate the right URI
        def uri command
            "https://" + @login_name + ":" + @password + "@" + @base_uri + command
        end
        private :uri

        # An internal method to make an API call.
        def api_request command
            raise ArgumentError, "There's no base URI! Please set @base_uri." unless @base_uri

            begin
                response = JSON.parse RestClient.post(uri(command), :json => json)

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
        # Parameter:
        #   async:: if the test should be run asynchronously, returning before 
        #       it has completed.
        # Return:: 
        #  test_id of the test, which the server usEs to identify a 
        #       particular _run_ of a test 
        #       (ie returns a new test_id for every call to run)

        def run async = false
            response = api_request "test/run"
            @test_id = response["test_run_test_id"]

            return @test_id if @test_id.nil? or async

            sleep 1 until test.done?

            @test_id
        end

        # Get the status of the test
        # Return::
        #   nil if called with an invalid @test_id
        #   One of "unscheduled" "queued" "running" "stopped" or "completed"

        def status
            return "unscheduled" if @test_id.nil?

            response = api_request "test/status"

            response["status"]
        end

        def done?
            return false if @test_id.nil?

            s = status
            return (s != "queued" and s != "running")
        end

        # Get the number of checks ("then" statements) of the PBehave code that 
        # passed
        # Return::
        #   - the number of "then" statements that passed
        #       nil if called with an invalid @test_id
        #       0 if the test's status is "unscheduled" or "queued"
        #       >= 0 if the test's status is "running" or "completed"

        def passed
            return 0 if @test_id.nil?

            response = api_request "test/passed"

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

            response = api_request "test/failed"
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

            response = api_request "test/planned"
            response["planned"]
        end

        # Get the results of a completed test.
        #
        # Return::
        #   - an array containing the lines in the result set.
        #       Results are in TAP (Test Anything Protocol) format.

        def results
            response = api_request "test/results"
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
            response = api_request "phrase_check"
            response["message"]
        end

        def ping
            response = api_request "ping"
            response["message"]
        end
    end
end
