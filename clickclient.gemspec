Gem::Specification.new do |spec|
  spec.name = "clickclient"
  spec.version = "0.0.2"
  spec.summary = "CLICK Securities Web Service Client For Ruby."
  spec.author = "Masaya Yamauchi"
  spec.email = "y-masaya@red.hot.co.jp"
  spec.homepage = "http://github.com/unageanu/clickclient/tree/master"
  spec.files =  [
    "History.txt", 
    "License.txt", 
    "README.txt", 
    "lib/clickclient.rb", 
    "lib/clickclient/version.rb", 
    "lib/clickclient/common.rb", 
    "lib/clickclient/fx.rb", 
    "test/test_helper.rb", 
    "test/alltests.rb", 
    "test/connect_test_fx.rb", 
    "test/test_base.rb", 
    "example/example_use_localserver.rb"]
  spec.has_rdoc = true
  spec.rdoc_options = ["--main", "README.txt"]
  spec.extra_rdoc_files = [
    "History.txt",
    "License.txt", 
    "README.txt"
  ]
  spec.required_ruby_version = '>= 0'
  spec.add_dependency('httpclient', '>= 2.1.2')
  spec.require_paths = ["lib"]
  spec.test_files = ["test/test_base.rb", "test/test_helper.rb"]
end