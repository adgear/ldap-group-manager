# ldap-group-manager

A Ruby helper to maintain LDAP group membership as flat yaml files. The goal is
to enable group membership to be managed through Github's pull requests
mechanisms by our CI systems.

## Installation

```shell
gem install ldap-group-manager
```

## Configuration

Just declare the following environment variables.

| Variable       | Usage                                              |
|----------------|----------------------------------------------------|
| AG_LDAP_HOST   | Points to the ldaps server                         |
| AG_LOCAL_STATE | Points to the yaml definitions of your groups      |
| AG_PASSWORD    | The binder's password                              |
| AG_TREEBASE    | The base of your search tree                       |
| AG_USER_DN     | The full DN of the user to use as a binder to ldap |

## Commands

### diff

Displays the actions to be executed to bring remote in sync with local.

```shell
ldap-group-manager diff ./my-directory-data --verify-users
```

### apply

Applies the changes required to bring the remote state in sync with local.

### Global flags

- `--verify-users` ensures every locally declared user exists on the
  remote server. It takes forever to do... be forewarned.

```shell
ldap-group-manager apply ./my-directory-data
```

## Contributing

1. Fork it!
2. Create your feature branch: `git checkout -b my-new-feature`
3. Commit your changes: `git commit -am 'Add some feature'`
4. Push to the branch: `git push origin my-new-feature`
5. Submit a pull request :D

## Credits

Alexis Vanier

## License

Check LICENSE file.
