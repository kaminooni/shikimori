describe Api::V1::TopicIgnoresController, :show_in_doc do
  include_context :seeds
  include_context :authenticated, :user

  let(:topic_ignore_params) {{ topic_id: seeded_offtopic_topic.id, user_id: user.id }}

  describe '#create' do
    before { post :create, topic_ignore: topic_ignore_params }

    it do
      expect(resource).to be_persisted
      expect(resource).to have_attributes user: user, topic: seeded_offtopic_topic
      expect(response).to have_http_status :success
      expect(json).to eq(
        id: resource.id,
        url: api_topic_ignore_url(resource),
        method: 'DELETE',
        # notice: I18n.t('api/v1/topic_ignores_controller.ignored')
      )
    end
  end

  describe '#destroy' do
    let(:topic_ignore) { create :topic_ignore, topic_ignore_params }
    before { delete :destroy, id: topic_ignore.id }

    it do
      expect(resource).to be_destroyed
      expect(response).to have_http_status :success
      expect(json).to eq(
        url: api_topic_ignores_url(topic_ignore: topic_ignore_params),
        method: 'POST',
        # notice: I18n.t('api/v1/topic_ignores_controller.not_ignored')
      )
    end
  end
end
