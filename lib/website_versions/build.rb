require 'grit'

class LeadRepo
  attr_accessor :lead_repo, :ref
  def initialize(lead_repo,ref)
    @lead_repo = lead_repo
    @ref = ref
  end
  def follow_repos
    @follow_repos ||= []
  end

  def repo_path(url)
    base = File.basename(url).gsub(/\.git$/,"")
    "tmp/#{base}"
  end
  def checkout_as_of(url,dt)
    path = repo_path(url)
    ensure_repo_exists(url)
    dt_str = dt.strftime("%Y-%m-%d %H:%M:%S")
    system "cd #{path} && git checkout `git rev-list -n 1 --before=\"#{dt_str}\" master`"
  end
  def ensure_repo_exists(url)
    FileUtils.mkdir("tmp") unless FileTest.exist?("tmp")
    path = repo_path(url)
    if !FileTest.exist?("#{path}/.git")
      system "cd tmp && git clone #{url}"
    end 
    system "cd #{path} && git reset --hard && git clean -df && git fetch origin"
  end

  def lead_commit_dt
    @lead_commit_dt ||= begin
      repo = Grit::Repo.new(repo_path(lead_repo))
      commit = repo.commits(ref,1).first
      commit.committed_date
    end
  end

  def checkout!
    ensure_repo_exists(lead_repo)
    system "cd #{repo_path(lead_repo)} && git checkout #{ref}"

    follow_repos.each do |url|
      checkout_as_of(url,lead_commit_dt)
    end
  end
end


def ec(cmd)
  puts cmd
  system cmd
end

module WebsiteVersions
  class << self
    def build_ref(ref)
      repo = LeadRepo.new("git://github.com/emberjs/ember.js.git",ref)
      repo.follow_repos << "git://github.com/emberjs/website.git"
      repo.checkout!

      ec "cd tmp/website && bundle install && bundle exec rake build"
    end

    def doc_urls
      res = {}
      #{}`git tag`.split("\n")
      %w(v0.9.1 v0.9.8 v0.9.7 v0.9.6).each do |v|
        cleaned = v.gsub("_","").gsub(".","")
        res[v] = "emberdocs#{cleaned}"
      end
      res
    end
  end
end