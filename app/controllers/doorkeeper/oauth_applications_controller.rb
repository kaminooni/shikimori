class Doorkeeper::OauthApplicationsController < ShikimoriController
  load_and_authorize_resource except: %i[index revoke]
  before_action :authenticate_user!, only: %i[revoke]

  before_action do
    og page_title: i18n_t('index.title')

    if params[:action] != 'index'
      @back_url = oauth_applications_url
      breadcrumb i18n_t('index.title'), oauth_applications_url
    end
    if @resource&.persisted? && params[:action] != 'show'
      @back_url = oauth_application_url @resource
      og page_title: @resource.name
      breadcrumb @resource.name, @back_url
    end
  end

  UPDATE_PARAMS = %i[name image redirect_uri]
  CREATE_PARAMS = %i[owner_id owner_type] + UPDATE_PARAMS

  def index # rubocop:disable AbcSize
    @collection = OauthApplication.order(:id)

    if params[:user_id]
      @user = User.find params[:user_id]
      @collection = @collection.where owner_id: @user.id, owner_type: User.name

    elsif user_signed_in?
      @granted_applications = Users::GrantedApplications.call(current_user)
      @collection = @collection.where.not(id: @granted_applications)
    end
  end

  def show
    og page_title: @resource.name
    if user_signed_in?
      @has_access = Users::GrantedApplications
        .call(current_user)
        .where(id: @resource.id)
        .any?
    end
  end

  def new
    og page_title: i18n_t('new.title')
    render :form
  end

  def create
    if @resource.save
      redirect_to edit_oauth_application_url(@resource)
    else
      render :form
    end
  end

  def edit
    og page_title: @resource.name
    render :form
  end

  def update
    if @resource.update update_params
      redirect_to edit_oauth_application_url(@resource)
    else
      render :form
    end
  end

  def destroy
    @resource.destroy
    redirect_to oauth_applications_url
  end

  def revoke
    current_user.access_grants.where(application_id: params[:id]).destroy_all
    current_user.access_tokens.where(application_id: params[:id]).destroy_all

    redirect_to oauth_application_url(params[:id])
  end

private

  def create_params
    params.require(:oauth_application).permit(*CREATE_PARAMS)
  end
  alias new_params create_params

  def update_params
    params.require(:oauth_application).permit(*UPDATE_PARAMS)
  end
end
