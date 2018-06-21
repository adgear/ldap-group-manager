Gem::Specification.new do |s|
  s.name = 'ldap-group-manager'
  s.authors = [
    'Alexis Vanier'
  ]
  s.version = '0.1.0'
  s.date = '2018-08-07'
  s.summary = 'Manage ldap group membership as flat files'
  s.files = Dir.glob('{bin,lib}/**/*') + %w[LICENSE README.md Gemfile]
  s.require_paths = ['lib']
  s.executables = ['ldap-group-manager']
  s.licenses = ['MIT']
  s.homepage = 'https://www.github.com/adgear/ldap-group-manager'
end
