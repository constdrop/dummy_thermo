# DummyThermo

Data generator of dummy thermo sensor.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'dummy_thermo'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install dummy_thermo

## Usage

#### Configuration

Deploy [dummy_thermo.yml](https://github.com/constdrop/dummy_thermo/blob/master/config/dummy_thermo.yml) to your application's config directory, and edit you like.

#### Sample code

    sensor = DummyThermo::Sensor.new([configuration name])
    sensor.gen  # => ex. 23.4 (temparature value based on your configuration)

    t = Time.new(2015, 10, 25, 12)
    sensor.gen(t, t - 30, 21.0)  # => ex. 21.3 (temparature value compared recent time and value(2nd, 3rd args))

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/constdrop/dummy_thermo.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
