require 'redis'
require 'dotenv'

module RspecSupportUsesDotenv
  def uses_dotenv
    before(:all) { Dotenv.load!('.env.test') }
  end
end

RSpec.configure { |c| c.extend RspecSupportUsesDotenv }

