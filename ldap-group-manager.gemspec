require_relative('lib/version')
include AdGear::Infrastructure::GroupManager::Version

Gem::Specification.new do |s|
  s.name = 'ldap-group-manager'
  s.authors = [
    'Alexis Vanier'
  ]
  s.version = GEM_VERSION
  s.date = '2018-08-07'
  s.summary = 'Manage ldap group membership as flat files'
  s.files = Dir.glob('{bin,lib}/**/*') + %w[LICENSE README.md Gemfile]
  s.require_paths = ['lib']
  s.executables = ['ldap-group-manager']
  s.licenses = ['MIT']
  s.homepage = 'https://www.github.com/adgear/ldap-group-manager'
  s.required_ruby_version = '~> 3.0'
  s.add_dependency('net-ldap', '~> 0.16.1')
  s.add_dependency('ougai', '~> 1.7')
  s.add_dependency('thor', '~> 0.20.0')
  s.add_dependency('amazing_print')
end
