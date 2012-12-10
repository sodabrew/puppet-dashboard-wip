class Node < ActiveRecord::Base
  def self.per_page; SETTINGS.nodes_per_page end # Pagination
  has_paper_trail

  include NodeGroupGraph
  extend FindFromForm

  validates_presence_of :name
  validates_uniqueness_of :name, :case_sensitive => false

  # attr_readonly :name, :created_at # FIXME: these should be readonly, but inherit_resources isn't creating new instances right
  attr_accessible :name, :created_at # FIXME: ^^
  attr_accessible :description, :parameter_attributes, :assigned_node_group_ids, :assigned_node_class_ids, :node_class_ids, :node_group_ids
  attr_accessible :reported_at, :last_inspect_report_id, :hidden, :updated_at, :last_apply_report_id, :status, :value, :report, :category

  has_many :node_class_memberships, :dependent => :destroy
  has_many :node_classes, :through => :node_class_memberships
  has_many :node_group_memberships, :dependent => :destroy
  has_many :node_groups, :through => :node_group_memberships
  has_many :reports
  has_many :resource_statuses, :through => :reports

  belongs_to :last_apply_report, :class_name => 'Report'
  belongs_to :last_inspect_report, :class_name => 'Report'

  def self.possible_derived_statuses
    self.possible_statuses.unshift("unresponsive")
  end

  def self.possible_statuses
    ["failed", "pending", "changed", "unchanged"]
  end

  scope :with_last_report, includes(:last_apply_report)
  scope :by_report_date, order('reported_at DESC')

  scope :search, lambda{ |q| where('name LIKE ?', "%#{q}%") unless q.blank? }

  scope :by_latest_report, proc { |order|
    direction = {1 => 'ASC', 0 => 'DESC'}[order]
    order("reported_at #{direction}") if direction
  }

  has_parameters

  assigns_related :node_class, :node_group

  fires :created, :on => :create
  fires :updated, :on => :update
  fires :removed, :on => :destroy

  scope :unresponsive, lambda {
    where("last_apply_report_id IS NOT NULL AND reported_at < ?",
          SETTINGS.no_longer_reporting_cutoff.seconds.ago)
  }

  possible_statuses.each do |node_status|
    scope node_status, lambda {
      where("last_apply_report_id IS NOT NULL AND
             reported_at >= ? AND
             nodes.status = '#{node_status}'",
             SETTINGS.no_longer_reporting_cutoff.seconds.ago)
    }
  end

  scope :unreported, where(:reported_at => nil)

  scope :hidden, where(:hidden => true)

  scope :unhidden, where(:hidden => false)

  # Enforce lowercase node name
  before_save :name_downcase
  def name_downcase
    self.name.downcase!
  end

  def self.find_by_id_or_name!(identifier)
    find_by_id(identifier) or find_by_name!(identifier)
  end

  def self.find_from_inventory_search(search_params={})
    queries = search_params.map do |param|
      fact  = CGI::escape(param['fact'])
      value = CGI::escape(param['value'])
      "facts.#{ fact }.#{ param['comparator'] }=#{ value }"
    end

    url = "https://#{SETTINGS.inventory_server}:#{SETTINGS.inventory_port}/" +
          "production/facts_search/search?#{ queries.join('&') }"

    matches = JSON.parse(PuppetHttps.get(url, 'pson'))
    matches.map!(&:downcase)
    nodes = Node.find_all_by_name(matches)
    found = nodes.map(&:name)
    created_nodes = matches.map do |m|
      Node.create!(:name => m) unless found.include? m
    end

    return nodes + created_nodes.compact
  end

  def configuration
    {
      'name'       => name,
      'classes'    => all_node_classes.collect(&:name),
      'parameters' => parameter_list
    }
  end

  def to_yaml(opts={})
    configuration.to_yaml(opts)
  end

  def resource_count
    last_apply_report.resource_statuses.count rescue nil
  end

  def pending_count
    last_apply_report.resource_statuses.pending(true).failed(false).count rescue nil
  end

  def failed_count
    last_apply_report.resource_statuses.failed(true).count rescue nil
  end

  def compliant_count
    last_apply_report.resource_statuses.pending(false).failed(false).count rescue nil
  end

  def self.to_csv_header
    UseThisCSV.generate_line(Node.to_csv_properties + ResourceStatus.to_csv_properties)
  end

  def self.to_csv_properties
    [:name, :status, :resource_count, :pending_count, :failed_count, :compliant_count]
  end

  def to_csv
    node_segment = self.to_csv_array
    rows = []
    if (last_apply_report.resource_statuses.present? rescue false)
      last_apply_report.resource_statuses.each do |res|
        rows << node_segment + res.to_csv_array
      end
    else
      rows << node_segment + ([nil] * ResourceStatus.to_csv_properties.length)
    end

    rows.map do |row|
      UseThisCSV.generate_line row
    end.join
  end

  def timeline_events
    TimelineEvent.for_node(self)
  end

  # Placeholder attributes

  def environment
    'production'
  end

  def assign_last_apply_report_if_newer(report)
    raise "wrong report type" unless report.kind == "apply"

    if reported_at.nil? or reported_at.to_i < report.time.to_i
      self.last_apply_report = report
      self.reported_at = report.time
      self.status = report.status
      self.save!
    end
  end

  def assign_last_inspect_report_if_newer(report)
    raise "wrong report type" unless report.kind == "inspect"

    if ! self.last_inspect_report or self.last_inspect_report.time.to_i < report.time.to_i
      self.last_inspect_report = report
      self.save!
    end
  end

  def find_and_assign_last_apply_report
    report = self.reports.applies.first
    if report
      self.reported_at = nil
      assign_last_apply_report_if_newer(report)
    else
      self.last_apply_report = nil
      self.reported_at = nil
      self.status = nil
      self.save!
    end
  end

  def find_and_assign_last_inspect_report
    report = self.reports.inspections.first
    self.last_inspect_report = nil
    if report
      assign_last_inspect_report_if_newer(report)
    else
      self.save!
    end
  end

  def facts
    return @facts if @facts
    url = "https://#{SETTINGS.inventory_server}:#{SETTINGS.inventory_port}/" +
          "production/facts/#{CGI.escape(self.name)}"
    data = JSON.parse(PuppetHttps.get(url, 'pson'))
    if data['timestamp']
      timestamp = Time.parse data['timestamp']
    elsif data['values']['--- !ruby/sym _timestamp']
      timestamp = Time.parse(data['values'].delete('--- !ruby/sym _timestamp'))
    else
      timestamp = nil
    end
    @facts = {
      :timestamp => timestamp,
      :values => data['values']
    }
  end

  def self.resource_status_totals(resource_status, scope='all')
    scope ||= 'all'
    raise ArgumentError, "No such status #{resource_status}" unless possible_statuses.unshift("total").include?(resource_status)

    case scope
    when *['all', 'index']
      Node.
           joins('LEFT JOIN metrics ON metrics.report_id = nodes.last_apply_report_id').
           where("metrics.category = 'resources' AND
                  metrics.name = '#{resource_status}'").sum(:value).to_i
    else
      Node.send(scope).
           joins('LEFT JOIN metrics ON metrics.report_id = nodes.last_apply_report_id').
           where("metrics.category = 'resources' AND
                  metrics.name = '#{resource_status}'").sum(:value).to_i
    end
  end
end
