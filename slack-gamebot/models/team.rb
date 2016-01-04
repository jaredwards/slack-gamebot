class Team
  include Mongoid::Document
  include Mongoid::Timestamps

  SORT_ORDERS = ['created_at', '-created_at', 'updated_at', '-updated_at']

  field :team_id, type: String
  field :name, type: String
  field :domain, type: String
  field :token, type: String
  field :active, type: Boolean, default: true
  field :gifs, type: Boolean, default: true
  field :aliases, type: Array, default: []

  scope :active, -> { where(active: true) }

  validates_uniqueness_of :token, message: 'has already been used'
  validates_presence_of :token
  validates_presence_of :team_id
  validates_presence_of :game_id

  has_many :users, dependent: :destroy
  has_many :seasons, dependent: :destroy
  has_many :matches, dependent: :destroy
  has_many :challenges, dependent: :destroy

  belongs_to :game

  def captains
    users.captains
  end

  def deactivate!
    update_attributes!(active: false)
  end

  def activate!
    update_attributes!(active: true)
  end

  def to_s
    {
      game: game.name,
      name: name,
      domain: domain,
      id: team_id
    }.map do |k, v|
      "#{k}=#{v}" if v
    end.compact.join(', ')
  end

  def ping!
    client = Slack::Web::Client.new(token: token)
    auth = client.auth_test
    {
      auth: auth,
      presence: client.users_getPresence(user: auth['user_id'])
    }
  end

  def self.find_or_create_from_env!
    token = ENV['SLACK_API_TOKEN']
    return unless token
    team = Team.where(token: token).first
    team ||= Team.new(token: token)
    info = Slack::Web::Client.new(token: token).team_info
    team.team_id = info['team']['id']
    team.name = info['team']['name']
    team.domain = info['team']['domain']
    team.game = Game.first || Game.create!(name: 'default')
    team.save!
    team
  end

  def self.purge!
    # destroy teams inactive for two weeks
    Team.where(active: false, :updated_at.lte => 2.weeks.ago).each do |team|
      Mongoid.logger.info "Destroying #{team}, inactive since #{team.updated_at}, over two weeks ago."
      team.destroy
    end
  end
end
