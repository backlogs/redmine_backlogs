class BacklogsAfterSave
  include Sidekiq::Worker

  sidekiq_options queue: :backlogs,
    backtrace: true

  def perform(issue_id)
    Issue.find(issue_id).backlogs_after_save_async
  end
end
