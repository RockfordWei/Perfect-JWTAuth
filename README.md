# Perfect Single Sign-On Authentication Module


<p align="center">
    <a href="http://perfect.org/get-involved.html" target="_blank">
        <img src="http://perfect.org/assets/github/perfect_github_2_0_0.jpg" alt="Get Involed with Perfect!" width="854" />
    </a>
</p>

<p align="center">
    <a href="https://github.com/PerfectlySoft/Perfect" target="_blank">
        <img src="http://www.perfect.org/github/Perfect_GH_button_1_Star.jpg" alt="Star Perfect On Github" />
    </a>  
    <a href="http://stackoverflow.com/questions/tagged/perfect" target="_blank">
        <img src="http://www.perfect.org/github/perfect_gh_button_2_SO.jpg" alt="Stack Overflow" />
    </a>  
    <a href="https://twitter.com/perfectlysoft" target="_blank">
        <img src="http://www.perfect.org/github/Perfect_GH_button_3_twit.jpg" alt="Follow Perfect on Twitter" />
    </a>  
    <a href="http://perfect.ly" target="_blank">
        <img src="http://www.perfect.org/github/Perfect_GH_button_4_slack.jpg" alt="Join the Perfect Slack" />
    </a>
</p>

<p align="center">
    <a href="https://developer.apple.com/swift/" target="_blank">
        <img src="https://img.shields.io/badge/Swift-4.0-orange.svg?style=flat" alt="Swift 4.0">
    </a>
    <a href="https://developer.apple.com/swift/" target="_blank">
        <img src="https://img.shields.io/badge/Platforms-OS%20X%20%7C%20Linux%20-lightgray.svg?style=flat" alt="Platforms OS X | Linux">
    </a>
    <a href="http://perfect.org/licensing.html" target="_blank">
        <img src="https://img.shields.io/badge/License-Apache-lightgrey.svg?style=flat" alt="License Apache">
    </a>
    <a href="http://twitter.com/PerfectlySoft" target="_blank">
        <img src="https://img.shields.io/badge/Twitter-@PerfectlySoft-blue.svg?style=flat" alt="PerfectlySoft Twitter">
    </a>
    <a href="http://perfect.ly" target="_blank">
        <img src="http://perfect.ly/badge.svg" alt="Slack Status">
    </a>
</p>



This project is a new candidate feature of Perfect Server since version 3.

This package builds with Swift Package Manager and is part of the [Perfect](https://github.com/PerfectlySoft/Perfect) project but can also be used as an independent module.

## Objectives

- independently work without ORMs (although it includes a mini ORM actually) or even databases, while it will supports all Perfect database drivers soon.
- extremely fast, scalable and thread-safe
- Session free: a full application of JWT for the single sign-on authentication to any virtual private clouds.

## SPM Configuration Note

This library is configurable by environmental variables when building with Swift Package Manager. See description below for the settings.

### Database Driver Specification

use `DATABASE_DRIVER` for database driver specifications. If null, the library will build with all compatible databases.

For example,  `export DATABASE_DRIVER=SQLite` will apply a `PerfectSQLite` driver if `swift build`

Currently configurable database drivers are:

Driver Name| Description
------------|--------------
JSONFile|a native JSON file based user database
SQLite|Perfect SQLite
MySQL|Perfect MySQL
MariaDB|Perfect MariaDB
PostgreSQL| Coming Soon
MongoDB| Coming Soon
Redis| Coming Soon

### Local Mirror

This library is using `URL_PERFECT` to work with [Perfect Local Mirror](https://github.com/PerfectlySoft/Perfect-LocalMirror) to speed up building process.

For example, `export URL_PERFECT=/private/var/perfect` will help build if install the Perfect Local Mirror by default.


## Quick Start

### Package.Swift

``` swift
.Package(url: "https://github.com/RockfordWei/Perfect-SSO.git", 
majorVersion: the_latest_release)
```

### Import

The first library to import should be `PerfectSSOAuth`, then import the user database driver as need:

Import| Description
------------|--------------
import UDBJSONFile|User database driven by a native JSON file system
import UDBSQLite|User database driven by SQLite
import UDBMySQL|User database driven by MySQL
import UDBMariaDB|User database driven by MariaDB

### Customizable Profile

Perfect-SSO is a using generic template class to deal with database and user authentications, which means you **MUST** write your own user profile structure.

To do this, design a `Profile: Codable` structure first, for example:

``` swift 
struct Profile: Codable {
  public var firstName = ""
  public var lastName = ""
  public var age = 0
  public var email = ""
}
```

You can put as many properties as possible to this `Profile` design, with **NOTES** here:
- DO **NOT** use `id`, `salt` and `shadow` as property names, they are reserved for the user authentication system.
- The whole structure should be **FLAT** and **FINAL**, because it would map to a certain database table, so recursive or cascaded definition is invalid.

### Open Database

Once got the Profile design, you can start database connections when it is ready. Please **NOTE** it is required to pass a sample `Profile` instance to help the database perform table creation.

Database|Example
--------|---------
JSONFile|`let udb = try UDBJSONFile<Profile>(directory: "/path/to/users")`
SQLite|` let udb = try UDBSQLite<Profile>(path: "/path/to/db", table: "users", sample: profile)`
MySQL|`let udb = try UDBMySQL<Profile>(host: "127.0.0.1", user: "root",password: "secret", database: "test", table: "users", sample: profile)`
MariaDB|`let udb = try UDBMariaDB<Profile>(host: "127.0.0.1", user: "root",password: "secret", database: "test", table: "users", sample: profile)`

### Access Manager

Now you can use the `AccessManager` class to register, login, load or drop users:

#### Register & Login

``` swift
let acm = AccessManager<Profile>(udb: udb)

// register a user by its id
try acm.register(id: "someone", password: "secret", profile: profile)

// generate a JWT token to perform single sign on
let token = try acm.login(id: "someone", password: "secret")
```

The token generated by `AccessManager.login()` is a JWT for HTTP web servers. It is supposed to send to the client (browser) as a proof of authentication. Every once the client sent it back to your server, `AccessManager.verify()` should be applied to verify the token:

``` swift
try acm.verify(id: "someone", token: token_from_client)
```

#### Load User Profile 

You can retrieve the user profile by its id:

``` swift 
 let profile = try acm.load(id: username)
```
#### Update Password

``` swift
try acm.update(id: username, password: new_password)
```

#### Update Profile

``` swift
try acm.update(id: username, profile: new_profile)
```

#### Drop A User

`try acm.drop(id: username)`

## Notes

More examples can be found in the test script.

## Issues

We are transitioning to using JIRA for all bugs and support related issues, therefore the GitHub issues has been disabled.

If you find a mistake, bug, or any other helpful suggestion you'd like to make on the docs please head over to [http://jira.perfect.org:8080/servicedesk/customer/portal/1](http://jira.perfect.org:8080/servicedesk/customer/portal/1) and raise it.

A comprehensive list of open issues can be found at [http://jira.perfect.org:8080/projects/ISS/issues](http://jira.perfect.org:8080/projects/ISS/issues)

## Further Information
For more information on the Perfect project, please visit [perfect.org](http://perfect.org).
