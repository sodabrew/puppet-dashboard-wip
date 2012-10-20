require 'spec_helper'

describe "/node_groups/index.html.haml" do
  include NodeGroupsHelper

  describe "successful render" do
    before :each do
      view.stubs(:action_name => 'index')
      assigns[:node_groups] = @node_groups = [ NodeGroup.generate!, NodeGroup.generate! ].paginate
      render
    end

    specify { rendered.should be_a_success }

    it "has node class items" do
      should have_tag('.node_group', @node_groups.size)
      should have_tag("#node_group_#{@node_groups.last.id}")
    end

    it { should have_tag('form.search') }
  end
end
