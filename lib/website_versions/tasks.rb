require 'shellwords'
require 'tempfile'
require 'rake'

def run_s3cmd(subcmd, *args)
  cmd = ["s3cmd"]
  cmd << subcmd

  cmd.concat(args)

  cmd = Shellwords.join(cmd)

  puts "Running command: #{cmd.inspect}"
  result = system cmd

  puts "Error running command" unless result
end

namespace :versions do
  namespace :s3 do
    task :setup => [:write_creds, :create_bucket, :create_website, :create_policy, :deploy]

    task :write_creds do
      if !FileTest.exist?("~/.s3cfg")
        body = "[default]\naccess_key=#{ENV['S3_ACCESS_KEY_ID']}\nsecret_key=#{ENV['S3_SECRET_ACCESS_KEY']}"
        File.create "~/.s3cfg",body
      end
    end

    task :create_bucket do
      puts "creating #{ENV['BUCKET_URL']}"
      run_s3cmd "mb",  ENV['BUCKET_URL']
    end

    task :create_website do
      run_s3cmd "ws-create", ENV['BUCKET_URL']
    end

    task :create_policy do
      Tempfile.open('emberjs-policy.json') do |f|
        f.write bucket_policy
        f.rewind
        run_s3cmd "setpolicy",  f.path, ENV['BUCKET_URL']
      end
    end

    task :deploy do
      if ENV['REF'] == 'edge'
        run_s3cmd "sync", "--delete-removed", "build/", ENV['BUCKET_URL']
      else
        run_s3cmd "sync", "--delete-removed", "tmp/website/build/", ENV['BUCKET_URL']
      end
    end
  end

  task :setup_vars do
    ref = ENV['REF']
    bucket = WebsiteVersions.bucket_for_tag(ref)
    ENV['BUCKET_URL'] = "s3://#{bucket}"
  end

  task :build_site => [:setup_vars] do
    WebsiteVersions.build_ref(ENV['REF'])
  end

  task :set_edge_ref do
    ENV['REF'] = 'edge'
  end

  task :deploy_version => [:build_site, 's3:setup']
  task :deploy_edge => [:build,:set_edge_ref, :setup_vars,'s3:setup']
end

def bucket_policy
  res = <<-EOS
  {
    "Version": "2008-10-17",
    "Id": "Policy1337995845252",
    "Statement": [
      {
        "Sid": "Stmt1337995842373",
        "Effect": "Allow",
        "Principal": {
          "AWS": "*"
        },
        "Action": "s3:GetObject",
        "Resource": "arn:aws:s3:::#{ENV['BUCKET_URL'].sub(%r{^s3:\/\/}, '')}/*"
      }
    ]
  }
EOS
  res.strip
end