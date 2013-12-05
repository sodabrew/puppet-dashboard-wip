class Report < ActiveRecord::Base
  def self.per_page; SETTINGS.reports_per_page end # Pagination
  belongs_to :node

  # See the after_destroy delete_resources method for more delete_all action
  has_many :logs,   :class_name => 'ReportLog',     :dependent => :delete_all
  has_many :metrics,                                :dependent => :delete_all
  has_many :resource_statuses
  has_many :events, :through => :resource_statuses

  accepts_nested_attributes_for :metrics, :resource_statuses, :logs

  before_validation :assign_to_node
  validates_presence_of :host, :time, :kind
  validates_uniqueness_of :host,
    :scope     => [:time, :kind],
    :allow_nil => true,
    :message   => "already has a report for time and kind"
  after_save :update_node
  after_destroy :delete_resources
  after_destroy :replace_last_report

  default_scope :order => 'time DESC', :include => :node

  named_scope :inspections, :conditions => {:kind => "inspect"                       }, :include => :metrics
  named_scope :applies,     :conditions => {:kind => "apply"                         }, :include => :metrics
  named_scope :changed,     :conditions => {:kind => "apply", :status => 'changed'   }, :include => :metrics
  named_scope :unchanged,   :conditions => {:kind => "apply", :status => 'unchanged' }, :include => :metrics
  named_scope :failed,      :conditions => {:kind => "apply", :status => 'failed'    }, :include => :metrics
  named_scope :pending,     :conditions => {:kind => "apply", :status => 'pending'   }, :include => :metrics

  def total_resources
    metric_value("resources", "total")
  end

  def failed_resources
    metric_value("resources", "failed")
  end

  def failed_restarts
    metric_value("resources", "failed_restarts")
  end

  def skipped_resources
    metric_value("resources", "skipped")
  end

  def pending_resources
    metric_value("resources", "pending")
  end

  def unchanged_resources
    metric_value("resources", "unchanged")
  end

  def changed_resources
    metric_value("changes", "total")
  end

  TOTAL_TIME_FORMAT = "%0.2f"

  def total_time
    TOTAL_TIME_FORMAT % metric_value("time", "total")
  end

  def config_retrieval_time
    TOTAL_TIME_FORMAT % metric_value("time", "config_retrieval")
  end

  def metric_value(category, name)
    metric = metrics.detect {|m| m.category == category and m.name == name }
    (metric and metric.value) or 0
  end

  def self.attribute_hash_from(report_hash)
    attribute_hash = report_hash.dup
    attribute_hash["logs_attributes"] = attribute_hash.delete("logs")
    attribute_hash["resource_statuses_attributes"] = attribute_hash.delete("resource_statuses")
    attribute_hash["metrics_attributes"] = attribute_hash.delete("metrics")
    attribute_hash["resource_statuses_attributes"].each do |resource_status_hash|
      resource_status_hash["events_attributes"] = resource_status_hash.delete("events") || {}
    end
    attribute_hash["metrics_attributes"] = attribute_hash["metrics_attributes"].map do |category,metric_hash|
      metric_hash.map do |name,value|
        {:category => category, :name => name, :value => value}
      end
    end.flatten
    attribute_hash
  end

  def self.create_from_yaml_file(report_file, options = {})
    report = create_from_yaml(read_file_contents(report_file))
    remove_file(report_file) if options[:delete] && report
    report
  end

  def self.create_from_yaml(report_yaml)
    raw_report = YAML.load(report_yaml, :safe => :true, :deserialize_symbols => true)

    unless raw_report.is_a? Hash
      raise ArgumentError, 'The supplied report did not deserialize into a Hash'
    end

    report_hash = ReportTransformer.apply(ReportSanitizer.sanitize(raw_report))

    report_hash['resource_statuses'] = report_hash['resource_statuses'].values

    report = Report.new(Report.attribute_hash_from(report_hash)).munge
    report.save!
    return report
  rescue => e
    retries ||= 3
    retry if (retries -= 1) > 0
    DelayedJobFailure.create!(
      :summary   => "Importing report",
      :details   => e.to_s,
      :backtrace => Rails.backtrace_cleaner.clean(e.backtrace)
    )
    return nil
  end

  def self.read_file_contents(file)
    File.read(file)
  end

  def self.remove_file(file)
    File.unlink(file)
  end

  def assign_to_node
    self.node = Node.find_or_create_by_name(self.host)
  end

  def update_node
    case kind
    when "apply"
      node.assign_last_apply_report_if_newer(self)
    when "inspect"
      node.assign_last_inspect_report_if_newer(self)
    else
      raise "There's no such thing as a #{kind.inspect} report"
    end
  end

  def long_name
    "#{node.name} at #{time}"
  end

  # In order to add data to the report or its dependent tables
  # without modifying the report format that Puppet sends
  # There is concern that this method will not be reusable for future munging in migrations
  # At that point we'll need more methods that are called individually to tranform the report
  def munge
    add_status_to_resource_status
    add_missing_metrics
    recalculate_report_status
    self
  end

  private

  # Report format 2 knows nothing about pending status
  def recalculate_report_status
    self.status = 'pending' if resource_statuses.any? {|rs| rs.status == 'pending' } &&
      resource_statuses.none? {|rs| rs.status == 'failed'}
  end

  def add_missing_metrics
    ['pending', 'unchanged'].each do |additional_status|
      next if metrics.any? {|m| m.category == 'resources' and m.name == additional_status }
      metrics << Metric.new(
        :category => 'resources',
        :name     => additional_status,
        :value    => resource_statuses.select {|rs| rs.status == additional_status }.length
      )
    end
  end

  def add_status_to_resource_status
    resource_statuses.each do |rs|
      event_statuses = rs.events.map {|e| e.status}.flatten

      resource_status_status = if event_statuses.include? 'failure'
        'failed'
      elsif event_statuses.include? 'noop'
        'pending'
      elsif event_statuses.include? 'success'
        'changed'
      else
        'unchanged'
      end

      rs.status = resource_status_status
    end
  end

  # It is too expensive to use has_many ... :dependent => :destroy
  # and unfortunately :dependent => :delete_all doesn't work :through.
  def delete_resources
    ResourceEvent.delete_all(:resource_status_id => resource_statuses.map(&:id))
    ResourceStatus.delete_all(:report_id => id)
  end

  def replace_last_report
    return unless node

    case kind
    when "apply"
      node.find_and_assign_last_apply_report
    when "inspect"
      node.find_and_assign_last_inspect_report
    else
      raise "There's no such thing as a #{kind.inspect} report"
    end
  end
end
