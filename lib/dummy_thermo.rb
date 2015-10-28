require "dummy_thermo/version"
require 'date'
require 'rational'
require 'yaml'
require 'random_bell'

module DummyThermo
  class Sensor
    include Math

    STDCONF = {
      max: 25.0, min: 15.0,
      maxhour: 14, minhour: 5
    }

    attr_reader :conf

    def initialize( name = "default" )
      yaml = YAML.load_file 'config/dummy_thermo.yml'

      if name == "default"
        c = yaml.key?("default") ? yaml["default"] : yaml[yaml.keys[0]]
        expand_conf(c)
      else
        raise "Named '#{name}' configuration is not found." unless yaml.key?(name)
        expand_conf(yaml[name])
      end
    end

    def gen(at_time = Time.now, recent_time = 0, recent_val = 0)
      at_time = at_time.to_time if at_time.class == DateTime
      recent_time = recent_time.to_time if recent_time.class == DateTime

      c = conf_of_day(at_time)

      lt8 = (c[:max] - c[:min]) / (100 / 8)
      max8 = c[:max] - lt8
      min8 = c[:min] + lt8

      if recent_time == 0 || recent_time - at_time > 300
        today = Time.new(at_time.year, at_time.month, at_time.day)
        r = if at_time.hour >= c[:minhour] && at_time.hour < c[:maxhour]
            -0.5 + ((at_time - today) - c[:minhour] * 3600) / ((c[:maxhour] - c[:minhour]) * 3600)
          else
            0.5 + ((at_time - today) - c[:maxhour] * 3600) / ((c[:minhour] + 24 - c[:maxhour]) * 3600)
          end

        a = ((max8 - min8) / 2) * sin(r) + (max8 + min8) / 2

        return RandomBell.new(mu: a, sigma: lt8, range: c[:min] .. c[:max]).rand
      end

      h = if recent_val > c[:max]
          { mu: -0.01, sigma: 0.03, range: -0.07 .. 0.04 }
        elsif recent_val > max8 && recent_val <= c[:max]
          { mu: -0.005, sigma: 0.02, range: -0.07 .. 0.04 }
        elsif recent_val < min8 && recent_val >= c[:min]
          { mu: 0.005, sigma: 0.02, range: -0.04 .. 0.07 }
        elsif recent_val < c[:min]
          { mu: 0.01, sigma: 0.03, range: -0.04 .. 0.07 }
        else
          adj = if at_time.hour >= c[:minhour] && at_time.hour < c[:maxhour]
              0.0005
            else
              -0.0003
            end
          { mu: adj, sigma: 0.01, range: -0.07 .. 0.07 }
        end

      bell = RandomBell.new(h)

      v = recent_val
      ((at_time - recent_time) / 3 + 1).to_i.times{ v += bell.rand }

      return v
    end

  private
    #
    # expand YAML configuration to hash array of 12 months
    #
    def expand_conf(c)
      @conf = []

      c.each do |k,v|
        k = k.to_s if k.class != String

        if k.match(/[^0-9., ]/)
          raise "Illegal key is set in sensor_data_generator.yml"
        end

        # import configurations to hases array
        k.split(",").each do |i|
          if i.include?("..")
            a = i.split("..")
            ( a[0].to_i .. a[1].to_i ).each{ |j| @conf[j] = v }
          else
            @conf[i.to_i] = v
          end
        end
      end

      # if not defined all month, set STDCONF and exit
      if @conf.size == 0
        (1 .. 12).each { |i| @conf[i] = STDCONF }
        return(@conf)
      end

      # convert all keys to symbol
      @conf.each do |h|
        next unless h
        h.replace( Hash[ h.map{ |k, v| [k.to_sym, v] } ] )
      end

      # set blank hash to the nil columns
      (1..12).each{ |i| @conf[i] ||= {} }

      # set parameters every month nil keys
      STDCONF.each_key do |k|
        # get max and min
        max = @conf[1..12].select{ |h| h[k] }.map{ |h| h[k] }.max
        min = @conf[1..12].select{ |h| h[k] }.map{ |h| h[k] }.min

        # if max == min that is meant set only one parameter,
        # set same parameter every month
        if max == min
          @conf[1..12].each{ |h| h[k] = max }
          next
        end

        # set average of previous month and next month
        @conf[1..12].each_with_index do |h, i|
          next if h[k]

          d = Date.new(2015, i + 1, 1)

          pm, pv = 0, 0
          (1..11).each do |j|
            pm = j
            if pv = @conf[d.prev_month(pm).month][k]
              break
            end
          end
          nm, nv = 0, 0
          (1..11).each do |j|
            nm = j
            if nv = @conf[d.next_month(nm).month][k]
              break
            end
          end

          h[k] = (nm / (nm + pm)) * pv + (pm / (nm + pm)) * nv

          # set value to less than 10% difference of max - min,
          # previous or next month of max or min
          if (pv == max || pv == min || nv == max || nv == min) && (pm > 1 || nm > 1)
            lt10 = (max - min) / 10
            pm1, pv1 = d.prev_month(pm - 1).month, nil
            nm1, nv1 = d.next_month(nm - 1).month, nil

            if (pv == max || pv == min) && pm > 1
              xv = ((nm + pm - 1) / (nm + pm)) * pv + (1 / (nm + pm)) * nv
              if lt10 > (pv - xv).abs
                pv1 = xv
              else
                pv1 = pv == max ? max - lt10 : min + lt10
              end
              @conf[pm1][k] = pv1
            end

            if (nv == max || nv == min) && nm > 1
              xv = (1 / (nm + pm)) * pv + ((nm + pm - 1) / (nm + pm)) * nv
              if lt10 > (nv - xv).abs
                nv1 = xv
              else
                nv1 = nv == max ? max - lt10 : min + lt10
              end
              @conf[nm1][k] = nv1
            end

            pm, pv = [pm1, pv1] if pv1
            nm, nv = [nm1, nv1] if nv1

            h[k] = (nm / (nm + pm)) * pv + (pm / (nm + pm)) * nv
          end
        end
      end
    end

    #
    # get configuration hash of the day
    #
    def conf_of_day(d)
      # type check and cast
      d = d.to_date if d.class == Time
      d = Date.strptime(d) if d.class == String
      raise TypeError if d.class != Date

      # configured by yaml date set to 15th day of the month
      p, n = d.day < 15 ? [(d << 1), d] : [d, (d >>1)]

      prev_date = Date.new(p.year, p.month, 15)
      next_date = Date.new(n.year, n.month, 15)

      # calcurate configuration of the day from prev and next month's configurations
      d_diff = next_date - prev_date
      d_past = d - prev_date
      d_come = next_date - d

      prev_conf = @conf[prev_date.month]
      next_conf = @conf[next_date.month]

      d_conf = {}
      prev_conf.keys.each do |k|
        v = (d_come/d_diff) * prev_conf[k] + (d_past/d_diff) * next_conf[k]
        d_conf[k.to_sym] = v.to_f
      end

      d_conf
    end
  end
end
