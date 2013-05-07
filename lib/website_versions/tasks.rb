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

namespace :s3 do
  task :setup => [:create_bucket, :create_website, :create_policy, :deploy]

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
    run_s3cmd "sync", "--delete-removed", "tmp/website/build/", ENV['BUCKET_URL']
  end

  task :build do
    ref = ENV['REF']
    ENV['BUCKET_URL'] = ("s3://"+doc_urls[ref]) || (raise "no url for #{ref}")
    build_ref(ref)
  end

  task :full => [:build, :setup]
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