# frozen_string_literal: true

describe Person do
  describe 'relations' do
    it { is_expected.to have_many :person_roles }
    it { is_expected.to have_many :animes }
    it { is_expected.to have_many :mangas }
    it { is_expected.to have_many :characters }

    it { is_expected.to have_attached_file :image }
  end

  describe 'topics concern' do
    describe 'associations' do
      it { is_expected.to have_many :topics }
    end

    describe 'callbacks' do
      let(:model) { build :person }

      before { allow(model).to receive(:generate_topics) }
      before { model.save }

      describe '#generate_topics' do
        it { expect(model).not_to have_received :generate_topics }
      end
    end

    describe 'instance methods' do
      let(:model) { create :person }

      describe '#generate_topics' do
        let(:topics) { model.topics.order(:locale) }
        before { model.generate_topics }

        it do
          expect(topics).to have(2).items
          expect(topics.first.locale).to eq 'en'
          expect(topics.second.locale).to eq 'ru'
        end
      end

      describe '#topic_auto_generated' do
        it { expect(model.topic_auto_generated?).to eq false }
      end

      describe '#topic_user' do
        it { expect(model.topic_user).to eq BotsService.get_poster }
      end
    end
  end
end
