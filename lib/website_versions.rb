%w(build tasks).each do |f|
  load File.join File.expand_path(File.dirname(__FILE__)),"#{f}.rb"
end