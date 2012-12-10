class ReportsController < InheritedResources::Base
  belongs_to :node, :optional => true
  protect_from_forgery :except => [:create, :upload]

  before_filter :raise_if_enable_read_only_mode, :only => [:new, :edit, :update, :destroy]
  before_filter :handle_raw_post, :only => [:create, :upload]

  def index
    index! do |format|
      format.html do
        if params[:kind] == "inspect"
          @reports = paginate_scope Report.inspections
        else
          @reports = paginate_scope Report.applies
        end
      end
    end
  end

  def create
    if SETTINGS.disable_legacy_report_upload_url
      render :text => "Access Denied, this url has been disabled, try /reports/upload", :status => 403
    else
      upload
    end
  end

  def upload
    begin
      @@n ||= 0
      yaml = params[:report][:report]
      file = Rails.root + 'spool' + "report-#{$$}-#{@@n += 1}.yaml"

      begin
        fd = File.new(file, File::CREAT|File::EXCL|File::RDWR, 0600)
        fd.print yaml
        fd.close

        Report.delay.create_from_yaml_file(file.to_s, :delete => true)
        render :text => "Report queued for import as #{file.basename}"
      rescue Errno::EEXIST
        file = Rails.root + 'spool' + "report-#{$$}-#{@@n += 1}.yaml"
        retry
      end
    rescue => e
      error_text = "ERROR! ReportsController#upload failed:"
      Rails.logger.debug error_text
      Rails.logger.debug e.message
      render :text => "#{error_text} #{e.message}", :status => 406
    end
  end

  def search
    @errors = []
    inspected_resources = ResourceStatus.latest_inspections.order("nodes.name")

    @title = params[:file_title].to_s.strip
    @content = params[:file_content].to_s.strip

    if params[:file_title] == nil and params[:file_content] == nil
      # Don't do anything; user just navigated to the search page
    else
      if !@title.present?
        @errors << "Please specify the file title to search for"
      end
      if !@content.present?
        @errors << "Please specify the file content to search for"
      elsif !is_md5?(@content)
        @errors << "#{@content} is not a valid md5 checksum"
      end
      if @errors.empty?
        @matching_files = inspected_resources.by_file_title(@title).by_file_content(@content)
        @unmatching_files = inspected_resources.by_file_title(@title).without_file_content(@content)
      end
    end
  end

  private

  def collection
    get_collection_ivar || set_collection_ivar(
      request.format == :html ? 
        paginate_scope(end_of_association_chain) : 
        end_of_association_chain
    )
  end

  def handle_raw_post
    report = params[:report]
    params[:report] = {}
    case report
    when String
      params[:report][:report] = report
    when nil
      params[:report][:report] = request.raw_post
    when Hash
      params[:report] = report
    end
  end

end
