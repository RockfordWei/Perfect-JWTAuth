# Perfect JWT认证模块

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

本项目为 Perfect 服务器 版本3以上的待定新功能。
请使用 Swift 4.0.3 以上版本工具链编译。
该项目采用SPM编译，是 [Perfect](https://github.com/PerfectlySoft/Perfect) 项目的一部分。

## 致谢

本项目除了 PerfectlySoft 公司团队自身之外，多数功能和建议来自 [@cheer / @Moon1102 (橘生淮南)](https://github.com/Moon1102) 和 [@neoneye (Simon Strandgaard)](https://github.com/neoneye)。在此表示感谢

## 项目状态

 阿尔法测试

## 目标

- 尽量独立工作，甚至不需要ORM数据库对象管理（虽然其实自带了一个迷你ORM），甚至不需要数据库，同时兼容大部分Perfect数据库作为驱动。
- 快速，轻量，简单，可配置，安全，可伸缩，线程安全。
- 不使用会话功能：完全采用JWT，并在虚拟专用云中实现单点登录。

## 为什么要开发单点登录？

功能/性能特点|JWTAuth|LocalAuth|Turnstile
------|----|---------|---------
密码保存方法|AES高级加密|摘要|河豚算法
密码保存安全等级|最高|低|高
密文生成算法|快|快|非常慢
可配置安全体系|Yes|N/A|N/A
函数库形式|一体化集成|分散|分散
可配置编译|Yes|N/A|N/A
登录控制|JWT|Session|Session
单点登录|Yes|N/A|N/A
令牌续订|Yes|N/A|N/A
密码质量检查|Protocol|N/A|N/A
用量控制|Protocol|N/A|N/A
线程安全|Yes|N/A|N/A
免数据库/持久化|Yes|N/A|N/A
日志可读性|JSON 兼容|普通文本|普通文本
用户数据拓展|通用/强类型|字典|字典
数据库驱动订制|Protocol|StORM based|StORM based

## SPM 配置方法说明

该函数库可以通过环境变量来控制SPM编译行为，详见以下配置方法。

### 设置数据库类型

使用环境变量 `DATABASE_DRIVER` 控制数据库类型。默认如果不设置这个变量，则可以兼容所有已经支持的数据库。

比如，  `export DATABASE_DRIVER=SQLite` 则以为着 `swift build` 编译时使用`PerfectSQLite` 驱动。

目前可配置的数据库驱动包括：

数据库名称|说明|配置范例
------------|--------------|-----------
JSONFile|一种内置的采用json文件作为数据库的方法|export DATABASE_DRIVER=JSONFile
SQLite|Perfect SQLite|export DATABASE_DRIVER=SQLite
MySQL|Perfect MySQL|export DATABASE_DRIVER=MySQL
MariaDB|Perfect MariaDB|export DATABASE_DRIVER=MariaDB
PostgreSQL| Perfect PostgreSQL|export DATABASE_DRIVER=PostgreSQL

### 本地镜像编译加速

本函数库还可以使用本地镜像加速编译 [Perfect Local Mirror](https://github.com/PerfectlySoft/Perfect-LocalMirror)，只要设置 `URL_PERFECT` 环境变量即可。

比如，`export URL_PERFECT=/private/var/perfect`，即使用本地编译镜像的默认目录，设置后即可编译加速。


## 快速上手

### Package.Swift

``` swift
.Package(url: "https://github.com/RockfordWei/Perfect-JWTAuth.git", 
majorVersion: 3)
```

### 导入函数库

首先要导入的函数库应该是 `PerfectJWTAuth`，其次根据需要导入不同的数据库驱动：

导入语句| 说明
------------|--------------
import UDBJSONFile|一种内置的采用json文件数据库
import UDBSQLite|SQLite 数据库
import UDBMySQL|MySQL 数据库
import UDBMariaDB|MariaDB 数据库
import UDBPostgreSQL|PostgreSQL 数据库

### 运行时初始化

**注意** 如果没有其他函数库，比如 Perfect-HTTP 服务器调用，则必须手工初始化加密函数库：

``` swift
_ = PerfectCrypto.isInitialized
```

### 自定义用户档案数据

Perfect-JWTAuth 采用通用模板类的方式处理用户档案，这意味着您 **必须** 自行编写档案细节。

具体方法是，首先设计一个 `Profile: Codable` 结构，比如：

``` swift 
struct Profile: Codable {
  public var firstName = ""
  public var lastName = ""
  public var age = 0
  public var email = ""
}
```

您可以随意增加任何一个属性，但是有下列事项**必须**注意：
- **避免** 使用 `id`、 `salt` 和 `shadow` 作为属性关键词，这些属性是系统保留。
- 其他的SQL/Swift的保留关键词也要避免，比如 "from / where / order ..." 之类。
- 结构必须**扁平化**，因为要映射到数据表格，因此不能进行结构嵌套。
- 字符串 `String` 类型受限于数据库驱动。默认 ANS SQL 字符串类型映射到Swift `String` 类型是 `VARCHAR(256)`，目前使用的驱动为 UDBMariaDB、 UDBMySQL 和 UDBPostgreSQL。因此如有出入请自行调整 `DataworkUtility.ANSITypeOf()`方法。

### 连接数据库

设计好用户文件之后，随时可以启动数据库链接。**注意** 需要给数据库初始化时传递一个样本的用户档案实例，用于数据库表格创建。

数据库|创建方法示例
--------|---------
JSONFile|`let udb = try UDBJSONFile<Profile>(directory: "/path/to/users")`
SQLite|` let udb = try UDBSQLite<Profile>(path: "/path/to/db", sample: profile)`
MySQL|`let udb = try UDBMySQL<Profile>(host: "127.0.0.1", user: "root",password: "secret", database: "test", sample: profile)`
MariaDB|`let udb = try UDBMariaDB<Profile>(host: "127.0.0.1", user: "root",password: "secret", database: "test", sample: profile)`
PostgreSQL|`let udb = try UDBPostgreSQL<Profile>(connection: "postgresql://user:password@localhost/testdb", sample: profile)`

**NOTE** 对于典型的关系数据库比如 SQLite、MySQL、MariaDB和PostgreSQL来说，驱动器会自动创建两个数据表 "users" 和 "tickets" 用于认证管理。

### 日志设置

日志访问是授权和审计的重要途径。

您可以使用该模块自带的文件日志系统 `let log = FileLogger("/path/to/log/files")` 或者自行实现 `LogManager` 协议进行扩展：

``` swift
public protocol LogManager {
  func report(_ userId: String, level: LogLevel, 
  event: LoginManagementEvent, message: String?)
}

```

**注意** 该日志协议假定是线程安全的，并且自动进行时间戳管理。请参考 `FileLogger` 作为实现范例。

默认 `FileLogger` 能够创建兼容JSON格式的日志，并且按照日历自动命令，比如 "/var/log/access.2017-12-27.log"。以下是片段示范：

``` JSON

{"id":"d7123fcf-64f2-4a6d-9179-10e8b227d39b","timestamp":"2017-12-27 12:04:03",
"level":0,"userId":"rockywei","event":5,"message":"profile updated"},

{"id":"56cde3cd-d4bf-4af3-a852-8c6c6a2f3f85","timestamp":"2017-12-27 12:04:49",
"level":0,"userId":"rockywei","event":0,"message":"user logged"},

{"id":"00f72022-0b8e-422f-9de9-82dc6059e399","timestamp":"2017-12-27 12:04:49",
"level":1,"userId":"rockywei","event":0,"message":"access denied"},

```

其中，日志等级和日志事件定义如下：

``` swift
public enum LoginManagementEvent: Int {
  case login = 0
  case registration = 1
  case verification = 2
  case logoff = 3
  case unregistration = 4
  case updating = 5
  case renewal = 6
  case system = 7
}

public enum LogLevel: Int {
  case event = 0
  case warning = 1
  case critical = 2
  case fault = 3
}
```

### 登录管理器

登录管理器使用数据库驱动示例和日志对象示例来进行用户登录管理：

``` swift
let man = LoginManager<Profile>(udb: udb, log: log)
```

当然，如果不需要日志，则可以省略日志参数。此时，日志内容将输出到屏幕终端：

``` swift
let man = LoginManager<Profile>(udb: udb)
```

现在可以只用这个实例来进行注册、登录、加载用户档案、更新密码及档案或删除用户的操作：

#### 注册和登录

``` swift
// 注册新用户
try man.register(id: "someone", password: "secret", profile: profile)

// 用户登录，返回一个JWT认证令牌用于其他系统单点登录
let token = try man.login(id: "someone", password: "secret")
```

**注意**: 默认状态下用户名密码长度都是 **[5,80]** 之间的字符串。
详见 [用户名密码质量控制](#login--password-quality-control)。

**注意** 如果最终用户希望用可以自动递增的UInt64作为用户id，请自行创建本项目分支版本进行调整。

调用 `LoginManager.login()` 登录后产生的令牌是一个JWT字符串，可以用于HTTP服务器进行权鉴认证。

该令牌应该送回给客户端（浏览器）用于后续安全会话的权限凭证。

除此之外，`login()` 登录函数还可以通过一个字典进行附加数据扩展：

``` swift
let token = try man.login(id: "someone", password: "secret", header: ["foo": "bar"])
```

#### 令牌认证

每一次用户发给服务器请求时，服务器都可以使用 `LoginManager.verify()` 校验用户身份。

首先服务器会自行查看该令牌的有效性，同时也会返回其中的解密后的内容用于进一步编程校验。

如果验证时设置 `allowSSO = true`，则当前登录管理器能够接受来自与当前管理器不同的其他令牌签发者的验证请求，否则 `verify` 会拒绝其他外来令牌，即使令牌是有效的。

``` swift
let (header, content) = try man.verify(token: token_from_client, allowSSO: true)

guard let issuer = content["iss"] as? String {
  // 出错了！
}

if issuer == man.id {
  print("本地签发令牌")
} else {
  print("异地签发令牌")
}

// 返回的变量 header 和 content 都是有效的字典，可以进行进一步验证
```

#### 令牌续签

某些情况下，令牌已经临近超时，这是可以不需要用户重新登录，而调用下列方法进行令牌续签，用于维护后续安全操作。

具体方法是调用登录管理器 `renew()` 函数，调用时不但能够续签，还能够根据需要以字典形式随时增加或者替换令牌中的具体内容：

``` swift
let renewedToken = try man.renew(id: "someone", headers: ["foo":"bar", "fou": "par"])

// 续签后的新令牌内容已经发生变化，但是认证方法都是一样的
```

#### 注销

登录管理器还提供一个可选参数用于注销之前签发的令牌。

``` swift
let (header, content) = try man.verify(token: token, logout: true)

// 如果执行无误，则变量 header 和 content 内容虽然正常，
// 但是令牌会失效。
```

**注意** RFC7519 标准中 JWT 是无法注销的，但是 Perfect-JWTAuth 使用了黑名单方法来实现“注销”功能。而且只要数据库之间能够同步这个tickets表，就可以共享黑名单。

#### 获取用户档案

通过用户身份编号可以获取用户档案：

``` swift 
 let profile = try man.load(id: username)
```
#### 更新密码

``` swift
try man.update(id: username, password: new_password)
```

**注意**: 默认状态下用户名密码长度都是 **[5,80]** 之间的字符串。
详见 [用户名密码质量控制](#login--password-quality-control)。

#### 更新用户档案

``` swift
try man.update(id: username, profile: new_profile)
```

#### 删除用户

``` swift
try man.drop(id: username)
```
## HTTP 服务器集成

现在登录管理器的实例已经可以用于保护您的服务器了，参考以下实现范例：

``` swift

// 配置一下http服务器，后面会讲配置细节
let conf = HTTPAccessControl<Profile>.Configuration()

// 用这个配置方案和登录管理器启动http安全认证模块
let acs = HTTPAccessControl<Profile>(man, configuration: conf)

// 将安全认证模块以高优先级请求过滤器的形式进行配置
let requestFilters: [(HTTPRequestFilter, HTTPFilterPriority)] 
	= [(acs, HTTPFilterPriority.high)]
	
// 准备http服务器实例
let server = HTTPServer()

// 向服务器追加请求过滤器，从现在开始所有路由都必须强制登录！
server.setRequestFilters(requestFilters)
```

在这个默认配置的http安全认证模块作用下，该服务器的所有访问请求都被强制要求用户登录，用户登录后必须携带一个请求头数据`Authorization: Bear \(jwt)`，其中jwt为登录后的授信凭证，没有这个凭证则请求被直接"401 Unauthorized"拒绝访问。

登录方法是使用POST调用REST API(*以下代码范例是一个URL请求虚函数`request()`，并且是假定数据同步的。请参考测试脚本以获取具体 `urlsession` 的类似使用方法*):

``` swift
let json = try request(url: "https://某域名/api/login", 
	method: .POST,
	fields: ["id": "你的用户名", "password": "你的密码"])
// 登录成功后服务器应该返回一个json字符串，其中error内容应该是空的才对：
// {"jwt": "这里应该是返回的jwt授信凭证", "error":""}
```

### 登录之后

1. 生产服务器建议必须使用HTTPS安全认证协议，避免密码明文泄露。
2. 默认情况下 Perfect-JWTAuth 是CSRF协议敏感的，因此必须确保请求头数据包含“origin”请求来源，而且内容应该和发给服务器的主机名称“host”保持一致。
3. 单点登录配置 `config.allowSSO` 是单点登录总开关，默认为关闭，即不信任外来授信凭证。要实现单点登录，首先将该开关置真，然后将信任的凭证签发单位加入列表 `config.issuers`，比如`config.issuers.append("[a-z]+.perfect.org")` 采用了正则表达式来信任所有perfect.org主机。
4. 返回的jwt授信凭证必须在注销之前**始终**以请求头数据之中的授权持有形式进行后续操作：

``` swift
request(url: "https://your.server/somewhere",
	headers: [ "Authorization": "Bearer \(jwt)"])
```

以下是登录模块所使用的预配置路由清单：

URI|说明|是否需要授信凭证头数据|POST字段|返回JSON
---|-----------|------|-----|------
/api/reg|用户注册|否|id, password, profile(json), payload(json|`{"jwt": jwt, "error":""}`
/api/login|用户登录|否|id, password, payload(json|`{"jwt": jwt, "error":""}`
/api/renew|更新凭证|是|不需要|`{"jwt": jwt, "error":""}`
/api/logout|用户注销|是|不需要|`{"error":""}`
/api/modpass|需改密码|是|password|`{"error":""}`
/api/update|修改用户档案|是|profile(json)|`{"error":""}`
/api/drop|删除用户档案|是|N/A|`{"error":""}`
/**|其他路由|是|--|--

**POST 字段说明**
1. 字段"id"和"password"是用于登录的明文，所以必须要使用HTTPS
2. 字段"profile"是经过url编码的json表达式，所以一定要和之前定义的Profile结构保持一致
3. 字段"payload"也是一个经过url编码的json表达式，但是只在当前login会话中有效，不会保存到数据库。

### 认证保护资源

采用JWT登录认证管理的HTTP服务器可以在受保护的路由内直接读取当前登录用户 id 及其档案信息：

``` swift
routes.add(Route(method: .get, uri: "/a_valuable_uri", handler: {
      request, response in
      let ret: String
      guard let id = response.request.scratchPad["id"] as? String,
        let profile = response.request.scratchPad["profile"] as? Profile,
        let payload = response.request.scratchPad["payload"] as? [String:Any]
        else {
        // 出错了，应该立刻拒绝访问
      }
      // 变量 id 和 profile 内容为当前用户及其档案信息（来自数据库）
      // 而 payload 则来自登录时的post预制（与数据库无关）
      ...
    }))
```

### HTTP 访问控制配置说明

`HTTPAccessControl<Profile>.Configuration` 是一个兼容JSON `Codable`的结构体，主要包括三个可配置部分：

1. URIs。比如，您可以重新设定默认的登录路由`/api/login`，改为`/api/v1/login`： `config.login = "/api/v1/login"`
2. 字符串常量。本函数库通过声明字符串常量的方式保证源代码在编译阶段允许进行字符串一致性检查。虽然不建议修改这个部分的内容，但是您仍然可以参考源代码的本节详细资料。
3. CSRF 配置说明

配置条目|说明|范例|默认值
----------------|------------|-------|-------------
"whitelist"|用于覆盖CSRF的白名单<br>**注意** 尽量不要使用这个白名单，最好为空|config.whitelist.append("a.trusted.domain")|空集合
"blacklist"|用于强制拒绝的黑名单，即使CSRF有效|config.blacklist.append("hackers.playground")|空集合
"realm"|控制域名，建议自定义|config.realm = "myTerritory"|"perfect"
"noreg"|关闭用户自我注册功能|config.noreg = true|false
"timeout"|服务器返回401未授权消息之前等待的秒数<br>这个选项用于遏制黑客用穷举法爆破密码|config.timeout = 0 // 不等待直接拒绝|1

## 高级登录管理配置

`LoginManager` 完整的配置方法见以下构造函数：

``` swift
/// a generic Login Manager
public class LoginManager<Profile> where Profile: Codable {

  public init(cipher: Cipher = .aes_128_cbc, keyIterations: Int = 1024,
  digest: Digest = .md5, saltLength: Int = 16, alg: JWT.Alg = .hs256,
  udb: UserDatabase,
  log: LogManager? = nil,
  rate: RateLimiter? = nil,
  pass: LoginQualityControl? = nil,
  recycle: Int = 0, 
  issuer: String? = nil)
}
```

其中最后一个参数“issuer” 是用来识别当前登录管理器实例的id标识。如果忽略则自动用一个uuid作为实例标识。该选项对于单点登录系统来说特别有用，用于识别不同的凭证签发单位。

### 加密控制

`LoginManager` 构造函数第一部分内容是加密控制选项：

- cipher: 保存密码的加密算法，默认为 AES_128_CBC。
- keyIterations: 加密时密钥循环次数，默认为一千次（1024）。
- digest: 保存密码的摘要算法，默认为 MD5。
- saltLength: 盐长度，默认为16.
- alg: JWT 令牌创建算法，默认为 HS256。

### 登录数据库驱动

详见 [连接数据库](#open-database)。

### 日志管理器

详见[日志设定](#log-settings) 。


### 用量控制

`RateLimiter` 是一个用于监控用户非正常行为的用量控制协议，比如过度反复登录之类。

登录管理器会在执行操作前后触发这些事件，因此请根据需要自行实现该协议。

``` swift
public protocol RateLimiter {
  func onAttemptRegister(_ userId: String, password: String) throws
  func onAttemptLogin(_ userId: String, password: String) throws
  func onLogin<Profile>(_ record: UserRecord<Profile>) throws
  func onAttemptToken(token: String) throws
  func onRenewToken<Profile>(_ record: UserRecord<Profile>) throws
  func onUpdate<Profile>(_ record: UserRecord<Profile>) throws
  func onUpdate(_ userId: String, password: String) throws
  func onDeletion(_ userId: String) throws
}
```

上述事件触发过程详见下表。
**注意** 如果超出用量应该抛出错误。

触发事件|描述
-----------------|-------------
onAttemptRegister|注册前触发
onAttemptLogin|登录前触发
onLogin|成功登录后触发
onAttemptToken|令牌验证前触发
onRenewToken|令牌更新触发
onUpdate|用户更新时触发，包括更新密码或者用户档案
onDeletion|用户档案删除前触发

### 用户名密码质量控制

`LoginManager` 登录管理器还能接受自定义的用户名密码质量控制系统。
如果用户实现了该协议，则登录管理器在必要时会调用这个协议定义的函数界面。
名称验证过程不限于注册或者密码更新，同样适用于登录检查或者令牌校验。这种做法不但能够防范密码脆弱性攻击，同时也可以防止通过溢出算法爆破服务器。

``` swift
public protocol LoginQualityControl {
  func goodEnough(userId: String) throws
  func goodEnough(password: String) throws
}
```

### 令牌回收

`LoginManager` 登录管理器能够注销任何之前签发的令牌。而您可以具体设置令牌超时后从数据库内被清理的事件，默认是60秒。

**注意** 如果令牌清理间隔太小，可能会造成系统繁忙。

## 自定义数据库驱动

您还可以在本函数库基础上自行扩展不同的数据库驱动，只需要符合以下 `UserDatabase` 协议：

``` swift
/// 用户登录数据库驱动标准协议，简称UDB
public protocol UserDatabase {

  /// -------------------- 基本 CRUD 操作 --------------------
  /// 注册新用户
  func insert<Profile>(_ record: UserRecord<Profile>) throws

  /// 提取用户资料
  func select<Profile>(_ id: String) throws -> UserRecord<Profile>

  /// 更新用户资料
  func update<Profile>(_ record: UserRecord<Profile>) throws

  /// 删除用户
  func delete(_ id: String) throws
  
  /// -------------------- JWT 令牌管理 --------------------
  /// 作废当前票据，进入黑名单
  func ban(_ ticket: String, _ expiration: time_t) throws

  /// 查看凭证是否在黑名单范围内
  func isRejected(_ ticket: String) -> Bool
}

```

请自行查看现有数据库驱动UDBxxx作为范例。

## 其他

更多使用方法请参考测试脚本

## 更多信息
关于本项目更多内容，请参考[perfect.org](http://perfect.org).

## 扫一扫 Perfect 官网微信号
<p align=center><img src="https://raw.githubusercontent.com/PerfectExamples/Perfect-Cloudinary-ImageUploader-Demo/master/qr.png"></p>
