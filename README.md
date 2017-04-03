# routemaster-drain [![Version](https://badge.fury.io/rb/routemaster-drain.svg)](https://rubygems.org/gems/routemaster-drain) [![Build](https://travis-ci.org/deliveroo/routemaster-drain.svg?branch=master)](https://travis-ci.org/deliveroo/routemaster-drain) [![Code Climate](https://codeclimate.com/github/deliveroo/routemaster-drain/badges/gpa.svg)](https://codeclimate.com/github/deliveroo/routemaster-drain) [![codecov](https://codecov.io/gh/deliveroo/routemaster-drain/branch/master/graph/badge.svg)](https://codecov.io/gh/deliveroo/routemaster-drain) [![Docs](http://img.shields.io/badge/API%20docs-rubydoc.info-blue.svg)](http://rubydoc.info/github/deliveroo/routemaster-drain)

A Rack-based event receiver for the
[Routemaster](https://github.com/deliveroo/routemaster) event bus.


`routemaster-drain` is a collection of Rack middleware to receive and
parse Routemaster events, filter them, and preemptively cache the corresponding
resources.

It provides prebuilt middleware stacks (`Basic`, `Mapping`, and `Caching`) for
typical use cases, illustrated below, or you can easily roll your own by
combining middleware.


<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

  - [Installation](#installation)
  - [Illustrated use cases](#illustrated-use-cases)
    - [Simply receive events from Routemaster](#simply-receive-events-from-routemaster)
    - [Receive change notifications without duplicates](#receive-change-notifications-without-duplicates)
    - [Cache data for all notified resources](#cache-data-for-all-notified-resources)
  - [HTTP Client](#http-client)
  - [Internals](#internals)
    - [Dirty map](#dirty-map)
    - [Filter](#filter)
  - [Contributing](#contributing)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->


## Installation

Add this line to your application's Gemfile:

    gem 'routemaster-drain'

**Configuration**

This gem is configured through the environment, making 12factor compliance
easier.

Required:

- `ROUTEMASTER_DRAIN_TOKENS`: a comma-separated list of valid authentication
  tokens, used by Routemaster to send you events.

Optional:

- `ROUTEMASTER_DRAIN_REDIS`: the URL of the Redis instance used for filtering
  and dirty mapping. Required if you use either feature, ignored otherwise.
  A namespace can be specified.
  Example: `redis://user:s3cr3t@myhost:1234/12/ns`.
- `ROUTEMASTER_CACHE_REDIS`: the URL of the Redis instance used for caching.
  Required if you use the feature, ignored otherwise. Formatted like
  `ROUTEMASTER_DRAIN_REDIS`.
- `ROUTEMASTER_CACHE_EXPIRY`: if using the cache, for how long to cache
  entries, in seconds. Default 1 year (31,536,000).
- `ROUTEMASTER_CACHE_AUTH`: if using the cache, specifies what username/password
  pairs to use to fetch resources. The format is a comma-separated list of
  colon-separate lists of regexp, username, password values. Example:
  `server1:user:p4ss,server2:user:p4ass`.
- `ROUTEMASTER_QUEUE_NAME`: if using the cache, on which Resque queue the cache
  population jobs should be enqueued.
- `ROUTEMASTER_CACHE_TIMEOUT`: if using the cache, how long before Faraday will timeout fetching the resource. Defaults to 1 second.
- `ROUTEMASTER_CACHE_VERIFY_SSL`: if using the cache, whether to verify SSL when fetching the resource. Defaults to false.

## Illustrated use cases


### Simply receive events from Routemaster

Provide a listener for events:

```ruby
class Listener
  def on_events_received(batch)
    batch.each do |event|
      puts event.url
    end
  end
end
```

Each event is a `Hashie::Mash` and responds to `type` (one of `create`,
`update`, `delete`, or `noop`), `url` (the resource), and `t` (the event
timestamp, in milliseconds since the Epoch).

Create the app that will process events:

```ruby
require 'routemaster/drain/basic'
$app = Routemaster::Drain::Basic.new
```

Bind the app to your listener:

```ruby
$app.subscribe(Listener.new, prefix: true)
```

And finally, mount your app to your subscription path:

```ruby
# typically in config.ru
map '/events' do
  run $app
end
```

This relies on the excellent event bus from the [wisper
gem](https://github.com/krisleech/wisper#wisper).


### Receive change notifications without duplicates

When reacting to changes of some resource, it's common to want to avoid
receiving further change notifications until you've actually processed that
resource.

Possibly you'll want to process changes in batches at regular time intervals.

For this purpose, use `Routemaster::Drain::Mapping`:

```ruby
require 'routemaster/drain/mapping'
$app = Routemaster::Drain::Mapping.new
```

And mount it as usual:

```ruby
# in config.ru
map('/events') { run $app }
```

Instead of processing events, you'll check for changes in the dirty map:

```ruby
require 'routemaster/dirty/map'
$map = Routemaster::Dirty::Map.new

every_5_minutes do
  $map.sweep do |url|
    # do something about this changed resource
    true
  end
end
```

Until you've called `#sweep` and your block has returned `true`, you won't be
bugged again — the dirty map acts as a buffer of changes (see below for
internals).

Notes:
- You can limit the number of resources to be swept (`$map.sweep(123) { ... }`).
- You can count the number of resources to be swept with `$map.count`.
- You're not told _what_ is to be swept; entities won't be swept in the order of
  events received (much like Routemaster does not guarantee ordering).
- If your sweeper fails, the dirty map will not be cleaned, so you can have
  leftovers. It's good practice to regularly run `$map.sweep { ... }` and perform
  cleanup regularly.
- The map won't tell you if the resources has been changed, created, or deleted.
  You'll have to figure it out with an API call.
- You can still attach a listener to the app to get all events.


### Cache data for all notified resources

Another common use case is that you'll actually need the representation of the
resources Routemaster tells you about.

The `Caching` prebuilt app can do that for you, using Resque to populate the
cache as events are received.

For this purpose, use `Routemaster::Drain::Caching`:

```ruby
require 'routemaster/drain/machine'
$app = Routemaster::Drain::Caching.new
```

And mount it as usual:

```ruby
# in config.ru
map('/events') { run $app }
```

You can still attach a listenenr if you want the incoming events. Typically,
what you'll want is the cache:

```ruby
require 'routemaster/cache'
$cache = Routemaster::Cache.new

response = @cache.fget('https://example.com/widgets/123')
puts response.body.id
```

In this example, is your app was notified by Routemaster about Widget #123, the
cache will be very likely to be hit; and it will be invalidated automatically
whenever the drain gets notified about a change on that widget.

Note that `Cache#fget` is a future, so you can efficiently query many resources
and have any `HTTP GET` requests (and cache queries) happen in parallel.

See
[rubydoc](http://rubydoc.info/github/deliveroo/routemaster-drain/Routemaster/Cache)
for more details on `Cache`.

## HTTP Client
The Drain is using a Faraday http client for communication between services. The client
comes with a convenient caching mechanism as a default and supports custom response materialization.
The Drain itself has the concept of "HATEOAS"(see below) response that provides a common way of addressing resources.

** **In order for the client to discover the resources that you are interested in, you need to call the `#discover(service_url)`
method first**

Example:

```ruby
require 'routemaster/fetcher'
require 'routemaster/responses/hateoas_response'

client = Routemaster::APIClient.new(response_class: Routemaster::Responses::HateoasResponse)

response = client.discover('https://identity.deliveroo.com.dev')
session_create_response = response.sessions.create(email: 'test@test.com', password: 'sup3rs3cr3t')
session_create_response.user.show(1)
```

The index method returns an Enumerable response to fetch all items in a paginated collection with the options of passing filters.

```
users = response.users
user_index_response = users.index(filters: {first_name: 'Jeff'})
total_users = user_index_response.total_users

puts "printing names of all #{total_users} users"
user_index_response.each do |user|
  puts user.full_name
end
```


### HATEOAS materialisation
The client comes with optional HATEOAS response capabilities. They are optional, because drain itself doesn't need to use the HATEOAS
response capabilities. Whenever the client is used outside of the drain it is **strongly** advised to be used with the HATEOAS response capabilities.
The HATEOAS response will materialize methods based on the keys found under the `_links` key on the payload. The semantics are the following:


```ruby
# Given the following payload
{
  "_links" : {
    "users" : { "href" : "https://identity.deliveroo.com.dev/users" },
    "user"  : { "href" : "https://identity.deliveroo.com.dev/users/{id}", "templated" : true }
  }
}

client = Routemaster::APIClient.new(response_class: Routemaster::Responses::HateoasResponse)
response = client.discover('https://identity.deliveroo.com.dev')

response.users.create(username: 'roo')
#=> HateoasResponse
response.users.index
#=> HateoasResponse
response.user.show(1)
#=> HateoasResponse
```



## Internals

The more elaborate drains are built with two components which can also be used
independently,
[`Dirty::Map`](http://rubydoc.info/github/deliveroo/routemaster-drain/Routemaster/Dirty/Map)
and
[`Dirty::Filter`](http://rubydoc.info/github/deliveroo/routemaster-drain/Routemaster/Dirty/Filter).

### Dirty map

A dirty map collects entities that have been created, updated, or deleted (or
rather, their URLs).  It can be used to delay your service's reaction to events,
for instance combined with Resque.

A dirty map map gets _marked_ when an event about en entity gets processed that
indicates a state change, and _swept_ to process those changes.

Practically, instances of
[`Routemaster::Dirty::Map`](http://rubydoc.info/github/deliveroo/routemaster-drain/Routemaster/Dirty/Map)
will emit a `:dirty_entity` event when a URL is marked as dirty, and can be
swept when an entity is "cleaned".  If a URL is marked multiple times before
being swept (e.g. for very volatile entities), the event will only by broadcast
once.

To sweep the map, you can for instance listen to this event and call
[`#sweep_one`](http://rubydoc.info/github/deliveroo/routemaster-drain/Routemaster/Dirty/Map#sweep_one-instance_method).

If you're not in a hurry and would rather run through batches you can call
[`#sweep`](http://rubydoc.info/github/deliveroo/routemaster-drain/Routemaster/Dirty/Map#sweep-instance_method)
which will yield URLs until it runs out of dirty resources.

### Filter

[`Routemaster::Dirty::Filter`](http://rubydoc.info/github/deliveroo/routemaster-drain/Routemaster/Dirty/Filter) is a simple event filter
that performs reordering. It ignores events older than the latest known
information on an entity.

It stores transient state in Redis and will emit `:entity_changed` events
whenever an entity has changed. This event can usefully be fed into a dirty map,
as in `Receiver::Filter` for instance.


## Contributing

1. Fork it ( http://github.com/deliveroo/routemaster-drain/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

Do not bump version numbers on branches (a maintainer will do this when cutting
a release); but please do describe your changes in the `CHANGELOG` (at the top,
without a version number).

If you have changed dependencies, you need to run `appraisal update` to make
sure the various version specific gemfiles are updated.
