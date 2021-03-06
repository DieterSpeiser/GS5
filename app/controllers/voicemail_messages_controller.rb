class VoicemailMessagesController < ApplicationController

  load_resource :sip_account
  load_and_authorize_resource :voicemail_message, :through => [:sip_account]

  before_filter :set_and_authorize_parent
  before_filter :spread_breadcrumbs
  
  before_filter { |controller|
    if ! params[:type].blank? then
      @type = params[:type].to_s
    end

    if ! params[:page].blank? then
      @pagination_page_number = params[:page].to_i
    end
  }

  def index
    @messages_count = @sip_account.voicemail_messages.count
    @messages_unread_count = @sip_account.voicemail_messages.where(:read_epoch => 0).count
    @messages_read_count = @messages_count - @messages_unread_count

    if @type == 'read'
      @voicemail_messages = @sip_account.voicemail_messages.where('read_epoch > 0').order('created_epoch DESC').paginate(
                            :page => @pagination_page_number,
                            :per_page => GsParameter.get('DEFAULT_PAGINATION_ENTRIES_PER_PAGE')
                          )
    elsif @type == 'unread'
      @voicemail_messages = @sip_account.voicemail_messages.where(:read_epoch => 0).order('created_epoch DESC').paginate(
                            :page => @pagination_page_number,
                            :per_page => GsParameter.get('DEFAULT_PAGINATION_ENTRIES_PER_PAGE')
                          )
    else
      @voicemail_messages = @sip_account.voicemail_messages.order('created_epoch DESC').paginate(
                            :page => @pagination_page_number,
                            :per_page => GsParameter.get('DEFAULT_PAGINATION_ENTRIES_PER_PAGE')
                          )
    end
  end

  def show
    respond_to do |format|
      format.wav {
        if @voicemail_message.file_path
          send_file @voicemail_message.file_path, :type => "audio/x-wav", 
            :filename => "#{Time.at(@voicemail_message.created_epoch).strftime('%Y%m%d-%H%M%S')}-#{@voicemail_message.cid_number}.wav"
        else
          render(
            :status => 404,
            :layout => false,
            :content_type => 'text/plain',
            :text => "<!-- Message not found -->",
          )
        end
      }
    end
  end

  def new
  end

  def create
  end

  def edit
  end

  def update
  end

  def destroy
    @voicemail_message.destroy
    m = method( :"#{@parent.class.name.underscore}_voicemail_messages_url" )
    redirect_to m.(), :notice => t('voicemail_messages.controller.successfuly_destroyed')
  end

  def destroy_multiple
    result = false
    if ! params[:selected_uuids].blank? then
      voicemail_messages = @sip_account.voicemail_messages.where(:uuid => params[:selected_uuids])
      voicemail_messages.each do |voicemail_message|
        result = voicemail_message.destroy
      end
    end

    m = method( :"#{@parent.class.name.underscore}_voicemail_messages_url" )
    if result
      redirect_to m.(), :notice => t('voicemail_messages.controller.successfuly_destroyed')
    else
      redirect_to m.()
    end
  end

  def call
    phone_number = @voicemail_message.cid_number
    if ! phone_number.blank? && @sip_account.registration
      @sip_account.call(phone_number)
    end
    redirect_to(:back)
  end

  def mark_read
    @voicemail_message.mark_read
    redirect_to(:back)
  end

  def mark_unread
    @voicemail_message.mark_read(false)
    redirect_to(:back)
  end

  private
  def set_and_authorize_parent
    @parent = @sip_account

    authorize! :read, @parent

    @show_path_method = method( :"#{@parent.class.name.underscore}_voicemail_message_path" )
    @index_path_method = method( :"#{@parent.class.name.underscore}_voicemail_messages_path" )
    @new_path_method = method( :"new_#{@parent.class.name.underscore}_voicemail_message_path" )
    @edit_path_method = method( :"edit_#{@parent.class.name.underscore}_voicemail_message_path" )
  end

  def spread_breadcrumbs
    if @parent.class == SipAccount
     if @sip_account.sip_accountable.class == User
       add_breadcrumb t("#{@sip_account.sip_accountable.class.name.underscore.pluralize}.index.page_title"), method( :"tenant_#{@sip_account.sip_accountable.class.name.underscore.pluralize}_path" ).(@sip_account.tenant)
       add_breadcrumb @sip_account.sip_accountable, method( :"tenant_#{@sip_account.sip_accountable.class.name.underscore}_path" ).(@sip_account.tenant, @sip_account.sip_accountable)
     end
     add_breadcrumb t("sip_accounts.index.page_title"), method( :"#{@sip_account.sip_accountable.class.name.underscore}_sip_accounts_path" ).(@sip_account.sip_accountable)
     add_breadcrumb @sip_account, method( :"#{@sip_account.sip_accountable.class.name.underscore}_sip_account_path" ).(@sip_account.sip_accountable, @sip_account)
     add_breadcrumb t("voicemail_messages.index.page_title"), sip_account_voicemail_messages_path(@sip_account)
     if @voicemail_message && !@voicemail_message.new_record?
       add_breadcrumb @voicemail_message, sip_account_voicemail_message_path(@sip_account, @voicemail_message)
     end
    end
  end

end
