require 'spec_helper'

describe "/node_groups/show.html.haml" do
  include NodeGroupsHelper

  describe "successful render" do
    before :each do
      assigns[:node_group] = @node_group = NodeGroup.generate!
      render
    end

    it { rendered.should have_tag 'h2', :text => /Group:\n#{@node_group.name}/ }
  end
end
