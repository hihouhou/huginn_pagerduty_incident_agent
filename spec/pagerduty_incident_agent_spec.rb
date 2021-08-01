require 'rails_helper'
require 'huginn_agent/spec_helper'

describe Agents::PagerdutyIncidentAgent do
  before(:each) do
    @valid_options = Agents::PagerdutyIncidentAgent.new.default_options
    @checker = Agents::PagerdutyIncidentAgent.new(:name => "PagerdutyIncidentAgent", :options => @valid_options)
    @checker.user = users(:bob)
    @checker.save!
  end

  pending "add specs here"
end
