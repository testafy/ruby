require 'testafy'

# create a new test, with required parameter login_name
test = Testafy::Test.new "user", "pass"

# The pbehave is set to this by default. Set explicitly here for demonstration.
test.pbehave = "For the url http://www.google.com\nthen pass this test"

# Run a test synchronously
test.run
puts "passed: #{test.passed}, failed: #{test.failed}, total: #{test.planned}"
# test.results_string gives us a string in TAP format.
puts "\nresults:\n" + test.results_string

# Run a test asynchronously
test.run true
# Do some other stuff, if we want.
sleep 1 until test.done?
puts "\nresults: \n" + test.results_string

