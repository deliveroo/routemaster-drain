# routemaster_client

A Ruby API for the [Routemaster](https://github.com/HouseTrip/routemaster) event
bus.

![Version](https://badge.fury.io/rb/routemaster-client.svg) 
![Build](https://travis-ci.org/HouseTrip/routemaster_client.svg?branch=master)

- [Installation](#installation)
- [Usage](#usage)
- [Sending events](#sending-events)
- [Setting up a subscription](#setting-up-a-subscription)
- [Receiving events](#receiving-events)
- [Filtering receiver](#filtering-receiver)
- [Monitoring Routemaster](#monitoring-routemaster)
- [Internals](#internals)
- [Contributing](#contributing)


## Installation

Add this line to your application's Gemfile:

    gem 'routemaster-client'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install routemaster-client

## Usage

**Configure** your client:

```ruby
require 'routemaster/client'
client = RoutemasterClient.new(url: 'https://bus.example.com', uuid: 'john-doe')
```

You can also specify a timeout value in seconds if you like with the ```timeout``` option.

```ruby
RoutemasterClient.new(url: 'https://bus.example.com', uuid: 'john-doe', timeout: 2)
```


## Sending events


**Push** an event about an entity in the topic `widgets` with a callback URL:

```ruby
client.created('widgets', 'https://app.example.com/widgets/1')
client.updated('widgets', 'https://app.example.com/widgets/2')
client.noop('widgets', 'https://app.example.com/widgets/3')
```

There are methods for the four canonical event types: `created`, `updated`,
`deleted`, and `noop`.

`noop` is typically used when a subscriber is first connected (or reset), and
the publisher floods with `noop`s for all existing entities so subscribers can
refresh their view of the domain.


## Setting up a subscription

**Register** to be notified about `widgets` and `kitten` at most 60 seconds after
events, in batches of at most 500 events, to a given callback URL:

```ruby
client.subscribe(
  topics:   ['widgets', 'kitten'],
  callback: 'https://app.example.com/events',
  uuid:     'john-doe',
  timeout:  60_000,
  max:      500)
```

## Receiving events


**Receive** events at path `/events` using a Rack middleware:

```ruby
require 'routemaster/receiver/basic'

class Listener
  def on_events_received(batch)
    batch.each do |event|
      puts event['url']
    end
  end
end

Wisper.add_listener(Listener.new, prefix: true)

use Routemaster::Receiver::Basic, {
  path:    '/events',
  uuid:    'demo'
}
```

This relies on the excellent event bus from the [wisper
gem](https://github.com/krisleech/wisper#wisper).


## Filtering receiver

The filtering receiver, `Receiver::Filter`, 
- reorders events by ignoring events older than the most recent one received);
- avoids duplicate events, i.e. it doesn't notify you again about a given entity
  before you've told it that you've processed it;
- noop events are ignored.

This is particularly convenient as a means to react to certain entities changing
very frequently (or rather, faster than you can process them), without causing
too much buffering in the bus.

It can be used synchronously or asynchronously.


### Synchronous filtered reception

Simply provide `Receiver::Filter` with a dirty map (details below) and a Redis
instance (used to memoize the latest known state of an entity).

The receiver broadcasts `:sweep_needed` to tell you that an entity needs to be
processed, and you provide a sweeping listener.

Caveats:
- you're not told _what_ is to be swept; entities won't be swept in the order of
  events received (much like Routemaster does not guarantee ordering).
- If your sweeper fails, the dirty map will not be cleaned, so you can have
  leftovers. It's good practice to regularly run `MAP.sweep { ... }` and perform
  cleanup.

```ruby
require 'routemaster/receiver/filter'

REDIS = Redis.new
MAP   = Routemaster::Dirty::Map.new(REDIS)

class Listener
  def on_sweep_needed
    MAP.sweep_one do |url|
      puts url
    end
  end
end

Wisper.add_listener(Listener.new, prefix: true)

use Routemaster::Receiver::Filter, {
  path:      '/events',
  uuid:      'demo',
  dirty_map: MAP,
  redis:     REDIS
}
```

### Asynchronous filtered reception

The example assuming you're using Resque, although other job processing lbraries
can be used.

The setup is the same, with the exceptiong that the response to the
`:sweep_needed` message will consist in enqueing a job.

```ruby
require 'resque'
require 'routemaster/dirty/map'
require 'routemaster/receiver/filter'

REDIS = Redis.new
MAP   = Routemaster::Dirty::Map.new(REDIS)

class SweepJob
  def self.perform
    MAP.sweep_one do |url|
      puts url
    end
  end
end

class Listener
  def on_sweep_needed
    Resque.enqueue(SweepJob)
  end
end

Wisper.add_listener(Listener.new, prefix: true)

use Routemaster::Receiver::Filter, {
  path:      '/events',
  uuid:      'demo',
  dirty_map: MAP,
  redis:     REDIS
}
```


## Monitoring Routemaster

**Monitor** the status of topics and subscriptions:

```ruby
client.monitor_topics
#=> [ { name: 'widgets', publisher: 'john-doe', events: 12589 }, ...]

client.monitor_subscriptions
#=> [ {
#     subscriber: 'bob',
#     callback:   'https://app.example.com/events',
#     topics:     ['widgets', 'kitten'],
#     events:     { sent: 21_450, queued: 498, oldest: 59_603 }
#  } ... ]
```


## Internals

The asynchronous receiver (`Receiver::Filter`) is built with two components
which can also be used independently, `Dirty::Map` and `Dirty::Filter`

### Dirty map

A dirty map collects entities that have been created, updated, or deleted (or
rather, their URLs).
It can be used to delay your service's reaction to events, for instance combined
with Resque.

A dirty map map gets _marked_ when an event about en entity gets processed that
indicates a state change, and _swept_ to process those changes.

Practically, instances of `Routemaster::Dirty::Map` will emit a `:dirty_entity`
event when a URL is marked as dirty, and can be swept when an entity is
"cleaned".
If a URL is marked multiple times before being swept (e.g. for very volatile
entities), the event will only by broadcast once.

Here's an example of parallel deferred event processing.


```ruby
# Our dirty map. Just hook it to Redis.
MAP = Routemaster::Dirty::Map.new(Redis.new)

# The work to do — sweep the map, send an email
class EmailOrderUpdatedJob
  def self.perform
    MAP.sweep_one do |url|
      # download receipt from URL
      # send email
      true # otherwise it'll be swept again
    end
  end
end

# Listens to the receiver, marks the map for any event
class ReceiverListener
  def on_events_received(payload)
    payload.each do |event|
      next unless event['type'] == 'create'
      MAP.mark(event['url'])
    end
  end
end

# Schedules a job whenever the map says something's dirty
class MapListener
  def on_dirty_entity(url)
    Resque.enqueue(EmailOrderUpdatedJob)
  end
end

# Bind everything together using Wisper
MAP.subscribe(
  MapListener.new,
  prefix: true
)
Wisper.add_listener(
  ReceiverListener.new,
  scope:  Routemaster::Receiver::Basic,
  prefix: true
)
```

If you're not in a hurry and would rather run through batches (careful, as
you'll have at most one worker sweeping the map):

```ruby
class EmailOrdersUpdatedJob
  extend Resque::Plugins::Lock

  def self.perform
    MAP.sweep do |url|
      # download receipt from URL
      # send email
      true
    end
  end
end

class ReceiverListener ...
class MapListener ...
MAP.subscribe ...
Wisper.add_listener ...
```

### Filter

`Routemaster::Dirty::Filter` is a simple event listener for `Receiver::Basic`
that performs reordering. It ignores events older than the latest know
information on an entity.

It stores transient state in Redis and will emit `:entity_changed` events
whenever an entity has changed. This event can usefully be fed into a dirty map,
as in `Receiver::Filter` for instance.


## Contributing

1. Fork it ( http://github.com/<my-github-username>/routemaster_client/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
