require 'spec_helper'

describe NodesController do
  include ReportSupport
  render_views

  describe "#index" do
    before :each do
      @node = Factory(:changed_node)
      @resource = @node.last_apply_report.resource_statuses.first
    end

    context "as HTML" do
      before { get :index }
      specify { response.should be_success }
    end

    context "as JSON" do
      before { get :index, :format => "json" }
      specify { response.should be_success }
      it "should return JSON" do
        struct = json_from_response_body
        struct.size.should == 1
        struct.first["name"].should == @node.name
      end
    end

    context "as YAML" do
      context "when using node classification" do
        before :each do
          SETTINGS.stubs(:use_external_node_classification).returns(true)
        end

        it "should return YAML when the nodes are valid" do
          get :index, :format => "yaml"

          response.should be_success
          struct = yaml_from_response_body
          struct.size.should == 1
          struct.first["name"].should == @node.name
        end

        it "should propagate errors encountered when a node is invalid" do
          Node.any_instance.stubs(:compiled_parameters).raises ParameterConflictError
          lambda {get :index, :format => "yaml"}.should raise_error(ParameterConflictError)
        end
      end

      context "when not using node classification" do
        it "should raise an error and respond 403" do
          SETTINGS.stubs(:use_external_node_classification).returns(false)
          get :index, :format => "yaml"

          response.body.should =~ /Node classification has been disabled/
          response.should_not be_success
          response.should be_forbidden
        end
      end
    end

    context "as CSV" do
      let :header do
        UseThisCSV.generate_line %w[name            status            resource_count pending_count
                                    failed_count    compliant_count   resource_type  title
                                    evaluation_time file              line           time
                                    change_count    out_of_sync_count skipped        failed ], :row_sep => ''
      end

      it "should make correct CSV" do
        get :index, :format => "csv"

        response.should be_success
        response.body.split("\n").should =~ [
          header,
          "#{@node.name},changed,1,0,0,1,#{@resource.resource_type},#{@resource.title},#{@resource.evaluation_time},#{@resource.file},#{@resource.line},#{@resource.time},#{@resource.change_count},#{@resource.out_of_sync_count},#{@resource.skipped},#{@resource.failed}"
        ]

      end

      it "should handle unreported nodes" do
        unreported_node = Node.generate!

        get :index, :format => "csv"

        response.should be_success
        response.body.split("\n").should =~ [
          header,
          "#{@node.name},changed,1,0,0,1,#{@resource.resource_type},#{@resource.title},#{@resource.evaluation_time},#{@resource.file},#{@resource.line},#{@resource.time},#{@resource.change_count},#{@resource.out_of_sync_count},#{@resource.skipped},#{@resource.failed}",
          "#{unreported_node.name},,,,,,,,,,,,,,,"
        ]
      end

      %w[foo,_-' bar/\\$^ <ba"z>>].each do |name|
        it "should handle a node named #{name}" do
          node = Node.generate!(:name => name)
          get :index, :format => "csv"

          response.should be_success
          UseThisCSV.parse(response.body).last.first.should == name
        end
      end

      it "should include the node's resources" do
        report = Report.generate!(:host => @node.name, :status => "failed", :time => Time.now)
        res1 = report.resource_statuses.generate!( :resource_type     => "File",    :title        => "/etc/sudoers",
                                                   :evaluation_time   => 1.second,  :file         => "/etc/puppet/manifests/site.pp",
                                                   :line              => 1,         :tags         => ["file", "default"],
                                                   :time              => Time.now,  :change_count => 1,
                                                   :out_of_sync_count => 1,         :skipped      => false,
                                                   :failed            => false )

        res2 = report.resource_statuses.generate!( :resource_type     => "File",    :title        => "/etc/hosts",
                                                   :evaluation_time   => 2.seconds, :file         => "/etc/puppet/manifests/site.pp",
                                                   :line              => 5,         :tags         => ["file", "default"],
                                                   :time              => Time.now,  :change_count => 2,
                                                   :out_of_sync_count => 2,         :skipped      => false,
                                                   :failed            => true )

        res1.reload
        res2.reload

        get :index, :format => "csv"

        response.should be_success
        response.body.split("\n").should =~ [
          header,
          %Q[#{@node.name},failed,2,0,1,1,File,/etc/sudoers,1.0,/etc/puppet/manifests/site.pp,1,#{res1.time},1,1,false,false],
          %Q[#{@node.name},failed,2,0,1,1,File,/etc/hosts,2.0,/etc/puppet/manifests/site.pp,5,#{res2.time},2,2,false,true]
        ]
      end
    end
  end

  describe "#new" do
    it "should successfully render the new page" do
      get :new

      response.should be_success
      assigns[:class_data].should include({:class=>"#node_class_ids", :data_source=>"/node_classes.json", :objects=>[]})
      assigns[:group_data].should include({:class=>"#node_group_ids", :data_source=>"/node_groups.json", :objects=>[]})
    end
  end

  describe "#create" do
    it "should create a node on successful creation" do
      post :create, 'node' => { 'name' => 'foo' }
      assigns[:node].name.should == 'foo'
    end

    it "should render new when creation fails" do
      post :create, 'node' => { }
      response.should render_template('nodes/new')
      response.should be_success

      assigns[:node].errors.full_messages.should == ["Name can't be blank"]
      assigns[:class_data].should include({:class=>"#node_class_ids", :data_source=>"/node_classes.json", :objects=>[]})
      assigns[:group_data].should include({:class=>"#node_group_ids", :data_source=>"/node_groups.json", :objects=>[]})
    end
  end

  describe "#show" do

    before :each do
      @node = Node.generate!
    end

    context "as HTML" do
      it "should return HTML for an existing node" do
        get :show, :id => @node.name

        response.should be_success
        assigns[:node].name.should == @node.name
      end

      it "should return 404 Record Not found an unknown node" do
        # NOTE: Uncaught RecordNotFound exceptions cause Rails to render a 404
        # Not Found response in production. We may want to add our own
        # friendlier error handling, rather than letting Rails handle these.
        lambda { get :show, :id => 'not_a_valid_node' }.should raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "as JSON" do
      it "should return JSON for an existing node" do
        get :show, :id => @node.name, :format => "json"

        response.should be_success

        struct = json_from_response_body
        struct["name"].should == @node.name
      end

      it "should return an error for an unknown node" do
        # NOTE: In the future, it may be better to return a JSON object that
        # better describes the error. Currently we're raising RecordNotFound,
        # which returns an HTML page.
        lambda { get :show, :id => 'not_a_valid_node', :format => 'json' }.should raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "as YAML" do
      context "when using node classification" do
        before :each do
          SETTINGS.stubs(:use_external_node_classification).returns(true)
        end

        it "should return YAML when the node is valid" do
          get :show, :id => @node.name, :format => "yaml"

          response.should be_success
          struct = yaml_from_response_body
          struct["name"].should == @node.name
        end

        it "should explain errors encountered when the node is invalid" do
          Node.any_instance.stubs(:compiled_parameters).raises ParameterConflictError
          get :show, :id => @node.name, :format => "yaml"

          response.should_not be_success
          response.body.should =~ /has conflicting parameter\(s\)/
        end

        it "should return YAML for an empty node when the node is not found" do
          get :show, :id => "nonexistent", :format => "yaml"

          response.should be_success
          struct = yaml_from_response_body
          struct.should include({'classes' => []})
        end
      end

      context "when not using node classification" do
        it "should raise an error and respond 403" do
          SETTINGS.stubs(:use_external_node_classification).returns(false)
          get :show, :id => @node.name, :format => "yaml"

          response.body.should =~ /Node classification has been disabled/
          response.should_not be_success
          response.should be_forbidden
        end
      end
    end
  end

  describe '#edit' do
    def do_get
      get :edit, :id => @node.id
    end

    before :each do
      @node = Node.generate!
    end

    it 'should render the edit template' do
      do_get
      assigns[:node].should == @node

      response.should render_template('edit')
      response.should be_success

      assigns[:class_data].should include({:class=>"#node_class_ids", :data_source=>"/node_classes.json", :objects=>[]})
      assigns[:group_data].should include({:class=>"#node_group_ids", :data_source=>"/node_groups.json", :objects=>[]})
    end

    it 'should work when given a node name' do
      get :edit, :id => @node.name

      response.should render_template('edit')
      response.should be_success

      assigns[:node].should == @node
    end
  end

  describe '#update' do
    def do_put
      put :update, @params
    end

    before :each do
      SETTINGS.stubs(:enable_read_only_mode).returns(false)
      @node = Node.generate!
      @params = { :id => @node.id, :node => @node.attributes }
    end

    it 'should fail when an invalid node id is given' do
      @params[:id] = 'unknown'
      lambda { do_put }.should raise_error(ActiveRecord::RecordNotFound)
    end

    it 'should work when given a node name' do
      @params.merge!({:id => @node.name})

      do_put
      assigns[:node].should == @node
    end

    describe 'when a valid node id is given' do

      describe 'and the data provided would make the node invalid' do
        before :each do
          @params[:node]['name'] = nil
        end

        it 'should make the node available to the view' do
          do_put
          assigns[:node].should == @node
        end

        it 'should not save the node' do
          do_put
          Node.find(@node.id).name.should_not be_nil
        end

        it 'should have errors on the node' do
          do_put
          assigns[:node].errors[:name].should_not be_blank
        end

        it 'should render the update action' do
          do_put
          response.should render_template('edit')
        end
      end

      describe 'and the data provided make the node valid' do
        it 'should update the node with the data provided' do
          @params[:node]['description'] = 'new description'
          do_put
          Node.find(@node.id).description.should == 'new description'
        end

        it 'should have a valid node' do
          do_put
          assigns[:node].should be_valid
        end
      end
    end

    describe "when node classification is enabled" do
      before :each do
        SETTINGS.stubs(:use_external_node_classification).returns(true)
      end

      it "should allow specification of 'parameter_attributes'" do
        @params[:node].merge! :parameter_attributes => [{:key => 'foo', :value => 'bar'}]

        do_put

        @node.reload.parameters.to_hash.should include({'foo' => 'bar'})
      end

      it "should allow specification of node classes" do
        node_class = NodeClass.generate!
        @params[:node].merge! :node_class_ids => [node_class.id]

        do_put

        @node.reload.node_classes.should == [node_class]
      end
    end

    describe "when node classification is disabled" do
      before :each do
        SETTINGS.stubs(:use_external_node_classification).returns(false)
      end

      it "should fail if parameter_attributes are specified" do
        @params[:node].merge! :parameter_attributes => [{:key => 'foo', :value => 'bar'}]

        do_put

        response.should be_forbidden
        response.body.should =~ /Node classification has been disabled/

        @node.reload.parameters.to_hash.should_not be_present
      end

      it "should fail if node classes are specified" do
        node_class = NodeClass.generate!
        @params[:node].merge! :assigned_node_class_ids => [node_class.id]

        do_put

        response.should be_forbidden
        response.body.should =~ /Node classification has been disabled/

        @node.reload.node_classes.should_not be_present
      end

      it "should not fail if node groups are specified" do
        node_group = NodeGroup.generate!
        @params[:node].merge! :assigned_node_group_ids => [node_group.id]

        do_put

        response.should redirect_to(node_path(@node))
        @node.node_groups.should == [node_group]
      end

      it "should succeed if parameter_attributes and node classes are omitted" do
        do_put

        response.should be_redirect
      end
    end
  end

  describe "#search" do
    before :each do
      @params = {}
    end

    it "should strip empty search parameters" do
      expected_param = {'facts' => 'foo', 'comparator' => 'eq', 'value' => 'bar'}
      @params['search_params'] = [
        {'facts' => '', 'comparator' => '', 'values' => ''},
        {'facts' => 'foo', 'comparator' => '', 'values' => ''},
        {'facts' => '', 'comparator' => 'eq', 'values' => ''},
        {'facts' => '', 'comparator' => '', 'values' => 'bar'},
        expected_param,
      ]

      Node.expects(:find_from_inventory_search).with([expected_param])
      get :search, @params
    end

    it "should not search with no parameters" do
      @params['search_params'] = []

      Node.expects(:find_from_inventory_search).never
      get :search, @params
    end
  end

  describe "#hide" do
    it "should hide the node" do
      @node = Node.generate!
      @node.hidden.should == false

      put :hide, :id => @node.name

      response.should redirect_to(node_path(@node))
      @node.reload
      @node.hidden.should == true
    end
  end

  describe "#unhide" do
    it "should unhide the node" do
      @node = Node.generate! :hidden => true
      @node.hidden.should == true

      put :unhide, :id => @node.name

      response.should redirect_to(node_path(@node))
      @node.reload
      @node.hidden.should == false
    end
  end

  describe "#facts" do
    before :each do
      @time = Time.now
      @node = Node.generate! :name => "testnode"
      Node.any_instance.stubs(:facts).returns({:timestamp => @time, :values => {"foo" => "1", "bar" => "2"}})
    end

    def do_get
      get :facts, :id => @node.name
    end

    it "should fail gracefully when connections are refused" do
      Node.any_instance.stubs(:facts).raises(Errno::ECONNREFUSED)

      do_get
      response.body.should =~ /Could not retrieve facts from inventory service: Connection refused/
    end

    it "should fail gracefully when other errors occur" do
      Node.any_instance.stubs(:facts).raises("some error")

      do_get
      response.body.should =~ /Could not retrieve facts from inventory service: some error/
    end

    it "should render a table when facts are fetched" do
      do_get
      response.body.should =~ /<table.*>/
    end

    it "should include the inventory timestamp in the rendered table" do
      do_get
      response.body.should =~ /Current inventory for testnode as of #{@time}/
    end
  end

  describe "#reports" do
    before :each do
      @node = Node.generate!
      Node.stubs(:find_by_name! => @node)
      Report.stubs(:assign_to_node => false)
      @report = Report.create_from_yaml(report_yaml_with(:host => @node.name))
      @node.reports = [@report]
    end

    context "for HTML" do
      before { get :reports, :node => 123 }

      specify { response.should be_success }

      it "should be paginated" do
        assigns[:reports].should respond_to(:paginate)
      end
    end
  end

  # Relies on #action returning name of a NodesController action, e.g. as "successful".
  describe "#scoped_index" do
    shared_examples_for "a scoped_index action" do
      context "as HTML" do
        before { get action, action_params }

        specify { response.should be_success }

        it "should assign only appropriate records" do
          assigns[:nodes].size.should == 1
          assigns[:nodes].first.name.should == "foo"
        end

        # NOTE: Once upon a time, these were paginated but were breaking the graphs
        it "should not be paginated" do
          assigns[:nodes].should_not be_a_kind_of(WillPaginate::Collection)
        end
      end

      context "as YAML" do
        context "when using node classification" do
          before :each do
            SETTINGS.stubs(:use_external_node_classification).returns(true)
            get action, action_params.merge(:format => "yaml")
          end

          specify { response.should be_success }

          it "should assign only appropriate records" do
            assigns[:nodes].size.should == 1
          end

          it "should not be paginated" do
            assigns[:nodes].should_not be_a_kind_of(WillPaginate::Collection)
          end

          it "should return YAML" do
            struct = yaml_from_response_body
            struct.size.should == 1
            struct.first["name"].should == "foo"
          end
        end
      end
    end

    describe "#unreported" do
      before :each do
        @node = Node.generate!(:name => "foo")
        @hidden_node = Node.generate!(:name => "bar", :hidden => true)
      end

      let(:action) { "unreported" }
      let(:action_params) { {} }

      it_should_behave_like "a scoped_index action"
    end

    describe "#hidden" do
      before :each do
        @node = Node.generate!(:name => "foo", :hidden => true)
        @unhidden_node = Node.generate!(:name => "bar")
      end

      let(:action) { "hidden" }
      let(:action_params) { {} }

      it_should_behave_like "a scoped_index action"
    end
  end

  describe 'read-only mode' do

    let(:node) { Node.generate! }

    ['configuration file', 'Rack middleware'].each do |source|
      describe "when set by the #{source}" do
        before :each do
          SETTINGS.stubs(:enable_read_only_mode).returns(source == 'configuration file')
          session.expects(:[]).with('ACCESS_CONTROL_ROLE').returns('READ_ONLY') if source == 'Rack middleware'
          # Raising the ReadOnlyEnabledError exception will create a session[:flash] error entry, which we stub (but not expects)
          session.stubs(:[]).with('flash').returns(ActionDispatch::Flash::FlashHash.new)
        end

        it "should raise an error when calling 'new'" do
          lambda{ get :new }.should raise_error(ReadOnlyEnabledError)
        end

        it "should raise an error calling 'edit'" do
          lambda{ get :edit, :id => node.name }.should raise_error(ReadOnlyEnabledError)
        end

        it "should raise an error when calling 'update'" do
          params = { :id => node.id, :node => node.attributes }
          lambda{ put :update, params }.should raise_error(ReadOnlyEnabledError)
        end

        it "should raise an error when calling 'create'" do
          lambda{ post :create, 'node' => { 'name' => 'foo' } }.should raise_error(ReadOnlyEnabledError)
        end
      end
    end
  end
end
